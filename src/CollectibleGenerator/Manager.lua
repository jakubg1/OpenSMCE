local class = require "com/class"
local CollectibleGeneratorManager = class:derive("CollectibleGeneratorManager")

local CollectibleGeneratorEntry = require("src/CollectibleGenerator/Entry")

function CollectibleGeneratorManager:new()
  self.generators = {}
  local generatorList = loadJson(parsePath("config/collectible_generators.json"))
  for i, name in ipairs(generatorList) do
    self.generators[name] = CollectibleGeneratorEntry(self, name)
  end
end

function CollectibleGeneratorManager:getEntry(name)
  return self.generators[name]
end

return CollectibleGeneratorManager
