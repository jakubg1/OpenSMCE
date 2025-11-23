local class = require "com.class"

---Handles the Game's config files.
---@class ConfigManager
---@overload fun():ConfigManager
local ConfigManager = class:derive("ConfigManager")



---Constructs a new ConfigManager and initializes all lists.
function ConfigManager:new()
	self.config = _Res:getConfigConfig("config.json")

	-- Load configuration files.
	-- TODO: These should be handled by Resource Manager and Config Classes.
	self.gameplay = _Utils.loadJson(_ParsePath("config/gameplay.json"))
	self.highscores = _Utils.loadJson(_ParsePath("config/highscores.json"))
	self.hudLayerOrder = _Utils.loadJson(_ParsePath("config/hud_layer_order.json"))

	-- Add a default value for combo scope.
	-- TODO: Config Classes for gameplay.json.
	self.gameplay.sphereBehavior.cascadeScope = self.gameplay.sphereBehavior.cascadeScope or "chain"

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
	return self.config.richPresence.enabled
end

---Returns the Rich Presence Application ID for this game, if it exists.
---@return string?
function ConfigManager:getRichPresenceApplicationID()
	return self.config.richPresence.applicationID
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



---Returns the default Sound Event which will be played when a UI button is pressed.
---@return SoundEvent?
function ConfigManager:getUIClickSound()
	return self.gameplay.ui.buttonClickSound and _Res:getSoundEvent(self.gameplay.ui.buttonClickSound)
end

---Returns the default Sound Event which will be played when a UI button is released.
---@return SoundEvent?
function ConfigManager:getUIReleaseSound()
	return self.gameplay.ui.buttonReleaseSound and _Res:getSoundEvent(self.gameplay.ui.buttonReleaseSound)
end

---Returns the default Sound Event which will be played when a UI button is hovered.
---@return SoundEvent?
function ConfigManager:getUIHoverSound()
	return self.gameplay.ui.buttonHoverSound and _Res:getSoundEvent(self.gameplay.ui.buttonHoverSound)
end



return ConfigManager
