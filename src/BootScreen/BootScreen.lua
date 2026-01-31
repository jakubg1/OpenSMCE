local class = require "com.class"

---@class BootScreen
---@overload fun():BootScreen
local BootScreen = class:derive("BootScreen")

local Vec2 = require("src.Essentials.Vector2")

local VersionManager = require("src.VersionManager")

local BootMain = require("src.BootScreen.Scene.BootMain")
local BootSettings = require("src.BootScreen.Scene.BootSettings")



function BootScreen:new()
	self.nativeResolution = Vec2(800, 600)
	self.isBootScreen = true

	self.versionManager = VersionManager()

	self.games = nil

	self.scene = nil
	self.sceneConstructors = {
		main = BootMain,
		settings = BootSettings
	}
end



function BootScreen:init()
	-- window title and size
	local w, h = self:getNativeResolution()
	_Display:setResolution(w, h, false, "OpenSMCE [" .. _VERSION .. "] - Boot Menu")
	-- Despite the canvas is not used to draw any Boot Screen UI, the size is used to calculate the mouse position.
	_Display:setCanvas(w, h, "filtered")

	-- game list
	self:fetchGameList()

	-- init the main screen
	self:setScene("main")

	-- discord rpc connection
	_DiscordRPC:setStatus(string.format("Boot Screen - Version: %s", _VERSION_NAME), nil, true)
end



function BootScreen:setScene(name)
	self.scene = self.sceneConstructors[name](self)
	if self.scene.init then
		self.scene:init()
	end
end



function BootScreen:update(dt)
	self.scene:update(dt)
end



function BootScreen:draw()
	self.scene:draw()
end



function BootScreen:getGames()
	-- A given folder in the "games" folder is considered a valid game when it contains a "config.json" file with valid JSON structure.

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



function BootScreen:fetchGameList()
	self.games = self:getGames()
end



---Returns the native resolution of the Boot Screen, which is always 800 by 600.
---@return integer, integer
function BootScreen:getNativeResolution()
	return self.nativeResolution.x, self.nativeResolution.y
end



function BootScreen:mousepressed(x, y, button)
	-- STUB
end

function BootScreen:mousereleased(x, y, button)
	self.scene:mousereleased(x, y, button)
end

function BootScreen:wheelmoved(x, y)
	-- STUB
end

function BootScreen:keypressed(key)
	-- STUB
end

function BootScreen:keyreleased(key)
	-- STUB
end

function BootScreen:textinput(t)
	-- STUB
end

return BootScreen
