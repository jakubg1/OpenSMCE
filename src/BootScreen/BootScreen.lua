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
	_Display:setResolution(self:getNativeResolution(), false, "OpenSMCE [" .. _VERSION .. "] - Boot Menu")

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
		local success, result = pcall(function() return _Utils.loadJson("games/" .. name .. "/config.json") end)
		if success then
			-- Check the version status of the game and if it is incompatible while the "Hide Incompatible Games" option is turned on,
			-- do not add it to the list.
			local versionStatus = self.versionManager:getVersionStatus(result.engine_version or result.engineVersion)
			if versionStatus ~= 3 or not _EngineSettings:getHideIncompatibleGames() then
				table.insert(games, {name = name, config = result})
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
---@return Vector2
function BootScreen:getNativeResolution()
	return self.nativeResolution
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
