local class = require "com/class"

---@class ConfigManager
---@overload fun():ConfigManager
local ConfigManager = class:derive("ConfigManager")

local CollectibleGeneratorManager = require("src/CollectibleGenerator/Manager")

local ShooterConfig = require("src/Configs/Shooter")



---Constructs a new ConfigManager and initializes all lists.
function ConfigManager:new()
	self.config = _LoadJson(_ParsePath("config.json"))

	-- Load all game resources.
	-- The load list is loaded to ensure that no resource will be loaded twice.
	self.loadList = _LoadJson(_ParsePath("config/loadlist.json"))
	local resourceTypes = {"images", "sprites", "sounds", "sound_events", "music", "particles", "fonts"}
	local resourcePaths = {"images", "sprites", "sounds", "sound_events", "music", "particles", "fonts"}
	self.resourceList = {}
	for i, type in ipairs(resourceTypes) do
		-- For each type...
		_Log:printt("ConfigManager", string.format("Loading %s...", type))
		self.resourceList[type] = {}
		-- ...get a list of resources to be loaded.
		for j, path in ipairs(_GetDirListing(_ParsePath(resourcePaths[i]), "file", nil, true)) do
			local name = resourcePaths[i] .. "/" .. path
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

	self.collectibles = self:loadFolder("config/collectibles", "collectible")
	self.spheres = self:loadFolder("config/spheres", "sphere", true)
	self.sphereEffects = self:loadFolder("config/sphere_effects", "sphere effect")
	self.colorGenerators = self:loadFolder("config/color_generators", "color generator")

	self.collectibleGeneratorManager = CollectibleGeneratorManager()

	-- Load level and map data.
	self.levels = {}
	self.maps = {}
	local levelList = _GetDirListing(_ParsePath("config/levels"), "file", "json")
	for i, path in ipairs(levelList) do
		local id = tonumber(string.sub(path, 7, -6))
		_Log:printt("ConfigManager", "Loading level " .. tostring(id) .. ", " .. tostring(path))
		local level = _LoadJson(_ParsePath("config/levels/" .. path))
		self.levels[id] = level
		-- Load map data only if it hasn't been loaded yet.
		if not self.maps[level.map] then
			_Log:printt("ConfigManager", "Loading map " .. level.map)
			self.maps[level.map] = _LoadJson(_ParsePath("maps/" .. level.map .. "/config.json"))
		end
	end
end



---Loads config files which are implemented the new way so that they require to be loaded after the resources.
function ConfigManager:loadStuffAfterResources()
	self.shooters = self:loadFolder("config/shooters", "shooter", false, ShooterConfig)
end



---Loads and returns multiple items from a folder.
---@param folderPath string The path to a folder where the files are stored.
---@param name string The name to be used when logging; also a file prefix if `isNumbers` is set to `true`.
---@param isNumbers boolean? If set to `true`, all IDs will be converted to numbers instead of being strings.
---@param constructor any? The config class constructor. If set, the returned table will contain instances of this class instead of raw data structures.
---@return table
function ConfigManager:loadFolder(folderPath, name, isNumbers, constructor)
	local t = {}

	local fileList = _GetDirListing(_ParsePath(folderPath), "file", "json")
	for i, path in ipairs(fileList) do
		local id = string.sub(path, 1, -6)
		if isNumbers then
			id = tonumber(string.sub(path, 2 + string.len(name), -6))
		end
		_Log:printt("ConfigManager", string.format("Loading %s %s, %s", name, id, path))
		local item = _LoadJson(_ParsePath(folderPath .. "/" .. path))
		if constructor then
			item = constructor(item)
		end
		t[id] = item
	end

	return t
end



---Returns a shooter config for a given shooter name.
---@param name string The name of the shooter.
---@return ShooterConfig
function ConfigManager:getShooter(name)
	return self.shooters[name]
end



---Returns the game name if specified, else the internal (folder) name.
---@return string
function ConfigManager:getGameName()
	return self.config.name or _Game.name
end

---Returns a title the window should have.
---@return string
function ConfigManager:getWindowTitle()
	return self.config.window_title or string.format("OpenSMCE [%s] - %s", _VERSION, self:getGameName())
end

---Returns whether the Discord Rich Presence should be on in this game.
---@return boolean
function ConfigManager:isRichPresenceEnabled()
	return self.config.rich_presence.enabled
end



---Gets the level number which the checkpoint points to.
---@param checkpoint number The checkpoint ID.
---@return integer
function ConfigManager:getCheckpointLevelN(checkpoint)
	local entryN = self.levelSet.checkpoints[checkpoint]

	return self:getLevelCountFromEntries(entryN - 1) + 1
end



---Returns how many levels the first N level set entries have in total.
---@param entries integer The total number of entries to be considered.
---@return integer
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
