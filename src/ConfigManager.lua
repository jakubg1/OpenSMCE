local class = require "com/class"
local ConfigManager = class:derive("ConfigManager")

local CollectibleGeneratorManager = require("src/CollectibleGenerator/Manager")

function ConfigManager:new()
	self.config = _LoadJson(_ParsePath("config.json"))

	self.loadList = _LoadJson(_ParsePath("config/loadlist.json"))
	local resourceTypes = {"images", "sprites", "sounds", "sound_events", "music", "particles", "fonts"}
	self.resourceList = {}
	for i, type in ipairs(resourceTypes) do
		print(string.format("[ConfigManager] Loading %s...", type))
		self.resourceList[type] = {}
		for j, path in ipairs(_GetDirListing(_ParsePath(type), "file", nil, true)) do
			local name = type .. "/" .. path
			local ok = true
			if self.loadList[type] then
				-- Forbid loading the same resource twice.
				for k, path2 in ipairs(self.loadList[type]) do
					if name == path2 then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(self.resourceList[type], name)
			end
		end
	end

	self.gameplay = _LoadJson(_ParsePath("config/gameplay.json"))
	self.highscores = _LoadJson(_ParsePath("config/highscores.json"))
	self.hudLayerOrder = _LoadJson(_ParsePath("config/hud_layer_order.json"))
	self.music = _LoadJson(_ParsePath("config/music.json"))
	self.powerups = _LoadJson(_ParsePath("config/powerups.json"))

	self.collectibleGeneratorManager = CollectibleGeneratorManager()

	self.spheres = {}
	local configSpheres = _LoadJson(_ParsePath("config/spheres.json"))
	for k, v in pairs(configSpheres) do
		self.spheres[tonumber(k)] = v
	end

	self.levels = {}
	self.maps = {}
	for i, levelConfig in ipairs(self.config.levels) do
		local level = _LoadJson(_ParsePath(levelConfig.path))
		self.levels[i] = level
		if not self.maps[level.map] then
			self.maps[level.map] = _LoadJson(_ParsePath("maps/" .. level.map .. "/config.json"))
		end
	end
end

return ConfigManager
