local class = require "com.class"

---Handles the Game's config files.
---@class ConfigManager
---@overload fun():ConfigManager
local ConfigManager = class:derive("ConfigManager")

local ShooterConfig = require("src.Configs.Shooter")



---Constructs a new ConfigManager and initializes all lists.
function ConfigManager:new()
	self.config = _Utils.loadJson(_ParsePath("config.json"))

	-- TODO: make a game config class
	self.nativeResolution = _ParseVec2(self.config.nativeResolution)

	-- Load configuration files.
	self.gameplay = _Utils.loadJson(_ParsePath("config/gameplay.json"))
	self.highscores = _Utils.loadJson(_ParsePath("config/highscores.json"))
	self.hudLayerOrder = _Utils.loadJson(_ParsePath("config/hud_layer_order.json"))
	self.levelSet = _Utils.loadJson(_ParsePath("config/level_set.json"))

	self.spheres = self:loadFolder("config/spheres", "sphere", true)
	self.sphereEffects = self:loadFolder("config/sphere_effects", "sphere effect")
	self.colorGenerators = self:loadFolder("config/color_generators", "color generator")

	-- Load level and map data.
	self.levels = {}
	self.maps = {}
	local levelList = _Utils.getDirListing(_ParsePath("config/levels"), "file", "json")
	for i, path in ipairs(levelList) do
		local id = tonumber(string.sub(path, 7, -6))
		_Log:printt("ConfigManager", "Loading level " .. tostring(id) .. ", " .. tostring(path))
		if not id then
			_Log:printt("ConfigManager", "WARNING: Skipped - illegal name!")
		else
			local level = _Utils.loadJson(_ParsePath("config/levels/" .. path))
			self.levels[id] = level
			-- Load map data only if it hasn't been loaded yet.
			if not self.maps[level.map] then
				_Log:printt("ConfigManager", "Loading map " .. level.map)
				self.maps[level.map] = _Utils.loadJson(_ParsePath("maps/" .. level.map .. "/config.json"))
			end
		end
	end
end



---Loads and returns multiple items from a folder.
---@param folderPath string The path to a folder where the files are stored.
---@param name string The name to be used when logging; also a file prefix if `isNumbers` is set to `true`.
---@param isNumbers boolean? If set to `true`, all IDs will be converted to numbers instead of being strings.
---@param constructor any? The config class constructor. If set, the returned table will contain instances of this class instead of raw data structures.
---@return table
function ConfigManager:loadFolder(folderPath, name, isNumbers, constructor)
	local t = {}

	local fileList = _Utils.getDirListing(_ParsePath(folderPath), "file", "json")
	for i, path in ipairs(fileList) do
		local id = string.sub(path, 1, -6)
		if isNumbers then
			id = tonumber(string.sub(path, 2 + string.len(name), -6))
		end
		_Log:printt("ConfigManager", string.format("Loading %s %s, %s", name, id, path))
		local item = _Utils.loadJson(_ParsePath(folderPath .. "/" .. path))
		if constructor then
			item = constructor(item, folderPath .. "/" .. path)
		end
		t[id] = item
	end

	return t
end



---Returns the game name if specified, else the internal (folder) name.
---@return string
function ConfigManager:getGameName()
	return self.config.name or _Game.name
end

---Returns a title the window should have.
---@return string
function ConfigManager:getWindowTitle()
	return self.config.windowTitle or string.format("OpenSMCE [%s] - %s", _VERSION, self:getGameName())
end

---Returns the native resolution of this game.
---@return Vector2
function ConfigManager:getNativeResolution()
	return self.nativeResolution
end

---Returns whether the Discord Rich Presence should be active in this game.
---@return boolean
function ConfigManager:isRichPresenceEnabled()
	return self.config.richPresence.enabled
end

---Returns the Rich Presence Application ID for this game, if it exists.
---@return string?
function ConfigManager:getRichPresenceApplicationID()
	return self.config.richPresence.applicationID
end

---Returns whether the game should be rendered on a canvas.
---@return boolean
function ConfigManager:isCanvasRenderingEnabled()
	return self.config.renderOnCanvas or false
end

---Returns the canvas rendering mode, `"filtered"` by default.
---@return string
function ConfigManager:getCanvasRenderingMode()
	return self.config.canvasRenderingMode or "filtered"
end

---Returns the game's tick rate. Defaults to `120`.
---@return integer
function ConfigManager:getTickRate()
	return self.config.tickRate or 120
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
		local entry = self.levelSet.levelOrder[i]
		if entry.type == "level" then
			n = n + 1
		elseif entry.type == "randomizer" then
			n = n + entry.count
		end
	end

	return n
end



return ConfigManager
