local class = require "com/class"
local CollectibleGeneratorEntry = class:derive("CollectibleGeneratorEntry")

local mathmethods = require("src/mathmethods")



function CollectibleGeneratorEntry:new(manager, name)
  self.manager = manager
  self.data = _LoadJson(_ParsePath(string.format("config/collectible_generators/%s", name)))
end



function CollectibleGeneratorEntry:generate()
  -- We iterate through pools until one of them returns a collectible.
  for i, pool in ipairs(self.data) do
    local modifiedPool = self:getModifiedPool(pool)
    if #modifiedPool > 0 then
      local weights = {}
      for j, entry in ipairs(modifiedPool) do
        table.insert(weights, entry.weight or 1)
      end
      local winner = modifiedPool[_MathWeightedRandom(weights)]
      return self:generateOutput(winner)
    end
  end
end



function CollectibleGeneratorEntry:generateOutput(entry)
  if entry.type == "collectible" then
    return entry.name
  elseif entry.type == "collectible_generator" then
    return self.manager:getEntry(entry.name):generate()
  end
end



function CollectibleGeneratorEntry:getModifiedPool(pool)
  -- Returns a pool with removed entries, for which the conditions do not meet.
  local newPool = {}

  for i, entry in ipairs(pool) do
    local ok = true
    ok = ok and self:checkConditions(entry.conditions)
    if entry.type == "collectible_generator" then
      local childEntry = self.manager:getEntry(entry.name)
      ok = ok and childEntry:canGenerate()
    end
    if ok then
      table.insert(newPool, entry)
    end
  end
  return newPool
end



function CollectibleGeneratorEntry:canGenerate()
  for i, pool in ipairs(self.data) do
    if self:canPoolGenerate(pool) then
      return true
    end
  end
  return false
end



function CollectibleGeneratorEntry:canPoolGenerate(pool)
  return #self:getModifiedPool(pool) > 0
end



function CollectibleGeneratorEntry:checkCondition(condition)
  if condition.type == "color_present" then
    -- Returns true if `color` is present on the board.
    return _Game.session.colorManager:isColorExistent(condition.color)
  elseif condition.type == "cmp_latest_checkpoint" then
    -- Returns true if the player's latest checkpoint is between `min` and `max` values (both inclusive) or is equal to `value`.
    local n = _Game:getCurrentProfile():getLatestCheckpoint()
    if condition.min and n < condition.min then
      return false
    end
    if condition.max and n > condition.max then
      return false
    end
    if condition.value and n ~= condition.value then
      return false
    end
    return true
  end
end



function CollectibleGeneratorEntry:checkConditions(conditions)
  if not conditions then
    return true
  end

  for i, condition in ipairs(conditions) do
    if not self:checkCondition(condition) then
      return false
    end
  end
  return true
end



return CollectibleGeneratorEntry
