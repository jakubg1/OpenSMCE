local RootScene = require("src.RootScene")
local Vec2 = require("src.Essentials.Vector2")
local VersionManager = require("src.VersionManager")
local BootMain = require("src.BootScreen.Scene.BootMain")
local BootSettings = require("src.BootScreen.Scene.BootSettings")

---@class BootScreen : RootScene
---@overload fun(): BootScreen
local BootScreen = RootScene:derive("BootScreen")

---Creates the Boot Screen.
function BootScreen:new()
	self.nativeResolution = Vec2(800, 600)
	self.isBootScreen = true

	self.versionManager = VersionManager()

	---@type {name: string, config: table}[]
	self.games = {}

	self.scene = nil
	self.sceneConstructors = {
		main = BootMain,
		settings = BootSettings
	}
end

---Initializes the Boot Screen.
function BootScreen:init()
	-- window title and size
	local w, h = self:getNativeResolution()
	_Display:setResolution(w, h, false, "OpenSMCE [" .. _VERSION .. "] - Boot Menu")
	-- Despite the canvas not being used to draw any Boot Screen UI, its size is used to calculate the mouse position.
	_Display:setCanvas(w, h, "filtered")

	-- game list
	self.games = self:getGames()

	-- init the main screen
	self:setScene("main")

	-- discord rpc connection
	_DiscordRPC:setStatus(string.format("Boot Screen - Version: %s", _VERSION_NAME), nil, true)
end

---Sets the current scene in the Boot Screen.
---@param name string The scene name.
function BootScreen:setScene(name)
	self.scene = self.sceneConstructors[name](self)
	if self.scene.init then
		self.scene:init()
	end
end

---Updates the Boot Screen.
---@param dt number Time delta in seconds.
function BootScreen:update(dt)
	self.scene:update(dt)
end

---Draws the Boot Screen.
function BootScreen:draw()
	self.scene:draw()
end

---Scans the `games` directory next to the executable and returns a list of found games.
---A given folder in the `games` folder is considered a valid game when it contains a "config.json" file with valid JSON structure.
---TODO: This should be moved out to uhhh... somewhere else. Outside this class.
---@return {name: string, config: table}[]
function BootScreen:getGames()
	local games = {}

	for i, name in ipairs(_Utils.getDirListing("games", "dir")) do
		_Log:printt("BootScreen", "Checking folder \"" .. name .. "\"...")
		local config = _Utils.loadJson("games/" .. name .. "/config.json")
		if config then
			-- Check the version status of the game and if it is incompatible while the "Hide Incompatible Games" option is turned on,
			-- do not add it to the list.
			local versionStatus = self.versionManager:getVersionStatus(config.engine_version or config.engineVersion)
			if versionStatus ~= 3 or not _Settings:getSetting("hideIncompatibleGames") then
				table.insert(games, {name = name, config = config})
			else
				_Log:printt("BootScreen", "(Game too old, skipping!)")
			end
			_Log:printt("BootScreen", "SUCCESS!")
		else
			_Log:printt("BootScreen", "FAIL!")
		end
	end

	return games
end

---Returns whether the Discord Rich Presence should be active in this game.
---@return boolean
function BootScreen:isRichPresenceEnabled()
	return true
end

---Executed when a mouse button is released.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button.
function BootScreen:mousereleased(x, y, button)
	self.scene:mousereleased(x, y, button)
end

return BootScreen
