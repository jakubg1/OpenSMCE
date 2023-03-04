local class = require "com.class"

---@class CollectibleGeneratorEntry
---@overload fun(manager, name):CollectibleGeneratorEntry
local CollectibleGeneratorEntry = class:derive("CollectibleGeneratorEntry")



function CollectibleGeneratorEntry:new(manager, name)
  self.manager = manager
  self.data = _LoadJson(_ParsePath(string.format("config/collectible_generators/%s", name)))
end



function CollectibleGeneratorEntry:generate()
  return self:evaluate(self.data)
end



function CollectibleGeneratorEntry:evaluate(entry)
  -- Return an empty list if the conditions don't meet.
  if not self:checkConditions(entry.conditions) then
    return {}
  end

  -- If the conditions do meet, proceed.
  if entry.type == "collectible" then
    return {entry.name}
  
  elseif entry.type == "collectibleGenerator" then
    return self.manager:getEntry(entry.name):generate()
  
  elseif entry.type == "combine" then
    local t = {}
    for i, e in ipairs(entry.entries) do
      -- Evaluate each entry from the pool and insert the results.
      local eval = self:evaluate(e)
      for j, ee in ipairs(eval) do
        table.insert(t, ee)
      end
    end
    return t
  
  elseif entry.type == "repeat" then
    local t = {}
    for i = 1, _Vars:evaluateExpression(entry.count) do
      local eval = self:evaluate(entry.entry)
      -- Append the results of each roll.
      for j, e in ipairs(eval) do
        table.insert(t, e)
      end
    end
    return t
  
  elseif entry.type == "randomPick" then
    -- Create a pool copy.
    local p = {}
    local weights = {}
    for i, e in ipairs(entry.pool) do
      -- Evaluate each entry from the pool.
      local eval = self:evaluate(e.entry)
      local w = e.weight or 1
      -- Do not pick from empty entries.
      if #eval > 0 then
        table.insert(p, eval)
        table.insert(weights, w)
      end
    end
    -- Choose a random item from the pool.
    if #p > 0 then
      return p[_MathWeightedRandom(weights)]
    else
      -- If there's nothing to pick from, return an empty list.
      return {}
    end
  end
end



function CollectibleGeneratorEntry:checkCondition(condition)
  if condition.type == "expression" then
    -- Returns true if the expression evaluates to true.
		return _Vars:evaluateExpression(condition.expression)
  elseif condition.type == "colorPresent" then
    -- Returns true if `color` is present on the board.
    return _Game.session.colorManager:isColorExistent(condition.color)
  elseif condition.type == "cmpLatestCheckpoint" then
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
