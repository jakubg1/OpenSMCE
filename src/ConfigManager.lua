local class = require "com/class"
local ConfigManager = class:derive("ConfigManager")

local CollectibleGeneratorManager = require("src/CollectibleGenerator/Manager")

function ConfigManager:new()
	self.config = loadJson(parsePath("config.json"))

	self.powerups = loadJson(parsePath("config/powerups.json"))

	self.collectibleGeneratorManager = CollectibleGeneratorManager()

	self.spheres = {}
	local configSpheres = loadJson(parsePath("config/spheres.json"))
	for k, v in pairs(configSpheres) do
		self.spheres[tonumber(k)] = v
	end
end

return ConfigManager
