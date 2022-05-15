local class = require "com/class"
local ConfigManager = class:derive("ConfigManager")

local CollectibleGeneratorManager = require("src/CollectibleGenerator/Manager")

function ConfigManager:new()
	self.config = _LoadJson(_ParsePath("config.json"))

	-- Load all game resources.
	-- The load list is loaded to ensure that no resource will be loaded twice.
	self.loadList = _LoadJson(_ParsePath("config/loadlist.json"))
	local resourceTypes = {"images", "sprites", "sounds", "sound_events", "music", "particles", "fonts"}
	self.resourceList = {}
	for i, type in ipairs(resourceTypes) do
		-- For each type...
		print(string.format("[ConfigManager] Loading %s...", type))
		self.resourceList[type] = {}
		-- ...get a list of resources to be loaded.
		for j, path in ipairs(_GetDirListing(_ParsePath(type), "file", nil, true)) do
			local name = type .. "/" .. path
			local ok = true
			if self.loadList[type] then
				-- Forbid loading the same resource twice,
				-- that is if this resource has been already loaded during the very startup.
				for k, path2 in ipairs(self.loadList[type]) do
					if name == path2 then
						ok = false
						break
					end
				end
			end
			-- If the resource hasn't been already loaded, add it to the "shopping list".
			-- This will be later used by Resource Manager when loading assets.
			if ok then
				table.insert(self.resourceList[type], name)
			end
		end
	end

	-- Load configuration files.
	self.gameplay = _LoadJson(_ParsePath("config/gameplay.json"))
	self.highscores = _LoadJson(_ParsePath("config/highscores.json"))
	self.hudLayerOrder = _LoadJson(_ParsePath("config/hud_layer_order.json"))
	self.levelSet = _LoadJson(_ParsePath("config/level_set.json"))
	self.music = _LoadJson(_ParsePath("config/music.json"))
	self.powerups = _LoadJson(_ParsePath("config/powerups.json"))

	self.collectibleGeneratorManager = CollectibleGeneratorManager()

	-- Load sphere data.
	-- Note the sphere IDs are converted from strings to numbers.
	-- This is because JSON can't do sparse arrays.
	self.spheres = {}
	local configSpheres = _LoadJson(_ParsePath("config/spheres.json"))
	for k, v in pairs(configSpheres) do
		self.spheres[tonumber(k)] = v
	end

	-- Load level and map data.
	self.levels = {}
	self.maps = {}
	local levelList = _GetDirListing(_ParsePath("config/levels"), "file")
	for i, path in ipairs(levelList) do
		local id = tonumber(string.sub(path, 7, -5))
		print("Loading level" .. tostring(id) .. ", " .. tostring(path))
		local level = _LoadJson(_ParsePath("config/levels/" .. path))
		self.levels[id] = level
		-- Load map data only if it hasn't been loaded yet.
		if not self.maps[level.map] then
			print("Loading map " .. level.map)
			self.maps[level.map] = _LoadJson(_ParsePath("maps/" .. level.map .. "/config.json"))
		end
	end
end



-- Gets the level number which the checkpoint points to.
function ConfigManager:getCheckpointLevelN(checkpoint)
	local entryN = self.levelSet.checkpoints[checkpoint]

	return self:getLevelCountFromEntries(entryN - 1) + 1
end

-- Returns how many levels the first N level set entries have in total.
function ConfigManager:getLevelCountFromEntries(entries)
	local n = 0

	-- If it's a single level, count 1.
	-- If it's a randomizer, count that many levels as there are defined in the randomizer.
	for i = 1, entries do
		local entry = self.levelSet.level_order[i]
		if entry.type == "level" then
			n = n + 1
		elseif entry.type == "randomizer" then
			n = n + entry.count
		end
	end

	return n
end



return ConfigManager
