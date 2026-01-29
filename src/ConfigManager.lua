local class = require "com.class"

---Handles the Game's config files.
---@class ConfigManager
---@overload fun():ConfigManager
local ConfigManager = class:derive("ConfigManager")



---Constructs a new ConfigManager.
function ConfigManager:new()
	self.config = _Res:getGameConfig("config.json")
end

---Loads gameplay, highscores, UI layer list and maps.
function ConfigManager:load()
	-- Load configuration files.
	self.gameplay = _Res:getGameplayConfig("config/gameplay.json")
	self.layers = _Res:getLayersConfig("config/layers.json")

	-- Load map data.
	-- TODO: This is now only used for checking the map names without loading the map (UI script -> stage map).
	-- Find out how to do it better at some point. Hint: Luxor 2 free play map selection dialog.
	self.maps = {}
	local mapList = _Utils.getDirListing(_ParsePath("maps"), "dir")
	for i, mapName in ipairs(mapList) do
		local mapConfig = _Utils.loadJson(_ParsePath("maps/" .. mapName .. "/config.json"))
		if mapConfig then
			_Log:printt("ConfigManager", "Loading map data: " .. mapName)
			self.maps[mapName] = mapConfig
		end
	end
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
---@return integer, integer
function ConfigManager:getNativeResolution()
	return self.config.nativeResolution.x, self.config.nativeResolution.y
end

---Returns whether the Discord Rich Presence should be active in this game.
---@return boolean
function ConfigManager:isRichPresenceEnabled()
	return self.config.richPresence and self.config.richPresence.enabled
end

---Returns the Rich Presence Application ID for this game, if it exists.
---@return string?
function ConfigManager:getRichPresenceApplicationID()
	return self.config.richPresence and self.config.richPresence.applicationID
end

---Returns the canvas rendering mode, `"filtered"` by default.
---@return string
function ConfigManager:getCanvasRenderingMode()
	return self.config.canvasRenderingMode
end

---Returns the game's tick rate. Defaults to `60`.
---@return integer
function ConfigManager:getTickRate()
	return self.config.tickRate
end



---Gets map data by map name from `config.json` in the respective map directory.
---If no such map exists, throws an error.
---@param name string The map directory name.
---@return table
function ConfigManager:getMapData(name)
	-- TODO/HARD: Currently, loading a map config also causes all of the related map assets to load.
	-- Find a way to load resources only partially without dependencies or find a way to load resource only when they're needed.
	--return _Res:getMapConfig("maps/" .. name .. "/config.json")
	return assert(self.maps[name], string.format("Map '%s' not found", name))
end



---Returns the default Sound Event which will be played when a UI button is pressed.
---@return SoundEvent?
function ConfigManager:getUIClickSound()
	return self.gameplay.ui.buttonClickSound
end

---Returns the default Sound Event which will be played when a UI button is released.
---@return SoundEvent?
function ConfigManager:getUIReleaseSound()
	return self.gameplay.ui.buttonReleaseSound
end

---Returns the default Sound Event which will be played when a UI button is hovered.
---@return SoundEvent?
function ConfigManager:getUIHoverSound()
	return self.gameplay.ui.buttonHoverSound
end



---Translates a locale key to its value depending on the currently active locale and optionally fills in its parameters.
---@param key string The locale key. If not found, this string will be returned back.
---@param ... any Translation parameters, such as numbers.
---@return string
function ConfigManager:translate(key, ...)
	if self.config.locale and self.config.locale.keys[key] then
		local success, result = pcall(function(...) return string.format(self.config.locale.keys[key], ...) end, ...)
		if success then
			return result
		end
		-- `string.format()` has failed, usually due to insufficient amount of parameters. Return the raw string.
		return key
	end
	return key
end



return ConfigManager
