local class = require "com/class"
local ConfigManager = class:derive("ConfigManager")

function ConfigManager:new()
	self.config = loadJson(parsePath("config.json"))

	self.powerups = loadJson(parsePath("config/powerups.json"))

	self.spheres = {}
	local configSpheres = loadJson(parsePath("config/spheres.json"))
	for k, v in pairs(configSpheres) do
		self.spheres[tonumber(k)] = v
	end
end

return ConfigManager
