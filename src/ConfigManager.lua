local class = require "com/class"
local ConfigManager = class:derive("ConfigManager")

local CollectibleGeneratorManager = require("src/CollectibleGenerator/Manager")

function ConfigManager:new()
	self.config = loadJson(parsePath("config.json"))

	self.gameplay = loadJson(parsePath("config/gameplay.json"))
	self.powerups = loadJson(parsePath("config/powerups.json"))

	self.collectibleGeneratorManager = CollectibleGeneratorManager()

	self.spheres = {}
	local configSpheres = loadJson(parsePath("config/spheres.json"))
	for k, v in pairs(configSpheres) do
		self.spheres[tonumber(k)] = v
	end

	self.levels = {}
	self.maps = {}
	for i, levelConfig in ipairs(self.config.levels) do
		local level = loadJson(parsePath(levelConfig.path))
		self.levels[i] = level
		if not self.maps[level.map] then
			self.maps[level.map] = loadJson(parsePath("maps/" .. level.map .. "/config.json"))
		end
	end
end

return ConfigManager
