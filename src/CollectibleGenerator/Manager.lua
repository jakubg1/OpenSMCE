local class = require "com.class"

---@class CollectibleGeneratorManager
---@overload fun():CollectibleGeneratorManager
local CollectibleGeneratorManager = class:derive("CollectibleGeneratorManager")

local CollectibleGeneratorEntry = require("src.CollectibleGenerator.Entry")



function CollectibleGeneratorManager:new()
  self.generators = {}
  local generatorList = _Utils.getDirListing(_ParsePath("config/collectible_generators"), "file", "json")
  for i, name in ipairs(generatorList) do
    self.generators[name] = CollectibleGeneratorEntry(self, name)
  end
end



function CollectibleGeneratorManager:getEntry(name)
	assert(self.generators[name], string.format("Cound not find collectible entry: %s", name))
  return self.generators[name]
end



return CollectibleGeneratorManager
