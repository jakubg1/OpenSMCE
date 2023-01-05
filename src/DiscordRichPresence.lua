local class = require "com/class"

---@class DiscordRichPresence
---@overload fun():DiscordRichPresence
local DiscordRichPresence = class:derive("DiscordRichPresence")



---Constructs this class.
function DiscordRichPresence:new()
	self.rpcMain = nil

	self.enabled = false
	self.connected = false
	self.username = nil

	self.UPDATE_INTERVAL = 2
	self.updateTime = 0

	self.status = {}

	local s, egg = pcall(self.getEgg)
	if s and egg then
		self.egg = egg
	end



	local success, err = pcall(function() self:init() end)
	if not success then
		self.rpcMain = nil
		_Log:printt("DiscordRichPresence", string.format("Failed to load the Discord Rich Presence module!\nMore info:\n%s\nDiscord Rich Presence will be inactive in this session.", err))
	end
end



---Includes and initializes the actual Rich Presence code.
function DiscordRichPresence:init()
	self.rpcMain = require("com/discordRPC")

	function self.rpcMain.ready(userId, username, discriminator, avatar)
		self.connected = true
		self.username = string.format("%s#%s", username, discriminator)
		_Debug.console:print({{0, 1, 1}, "[DiscordRPC] ", {0, 1, 0}, string.format("Connected! (username: %s)", self.username)})
	end

	function self.rpcMain.disconnected(errorCode, message)
		self.connected = false
		self.username = nil
		_Log:printt("DiscordRPC", string.format("Disconnected (%d: %s)", errorCode, message))
	end

	function self.rpcMain.errored(errorCode, message)
		_Log:printt("DiscordRPC", string.format("Error (%d: %s)", errorCode, message))
	end
end



---Updates the Discord Rich Presence.
---@param dt number Delta time in seconds.
function DiscordRichPresence:update(dt)
	self:updateEnabled()
	self:updateRun(dt)
end



---Checks whether the Discord Rich Presence setting has changed and turns Rich Presence on or off accordingly.
function DiscordRichPresence:updateEnabled()
	local setting = _EngineSettings:getDiscordRPC()
	if _Game.configManager then
		setting = setting and _Game.configManager:isRichPresenceEnabled()
	end
	
	if not self.enabled and setting then
		self:connect()
	end
	if self.enabled and not setting then
		self:disconnect()
	end
end



---Actual update function for Discord Rich Presence.
---Internal function; use `:update()` instead.
---@param dt number Delta time in seconds.
function DiscordRichPresence:updateRun(dt)
	if not self.rpcMain then
		return
	end

	self.updateTime = self.updateTime + dt
	if self.updateTime >= self.UPDATE_INTERVAL then
		self.updateTime = 0
		self.rpcMain.updatePresence(self.status)
	end
	self.rpcMain.runCallbacks()
end



---Connects Discord Rich Presence.
function DiscordRichPresence:connect()
	if not self.rpcMain then
		return
	end
	
	if self.enabled then return end
	_Log:printt("DiscordRPC", "Connecting...")
	self.rpcMain.initialize(_DISCORD_APPLICATION_ID, true)
	self.enabled = true
end



---Disconnects Discord Rich Presence.
function DiscordRichPresence:disconnect()
	if not self.rpcMain then
		return
	end
	
	if not self.enabled then return end
	_Log:printt("DiscordRPC", "Disconnecting...")
    self.rpcMain.shutdown()
	self.enabled = false
	self.connected = false
	self.username = nil
end



---Updates information to be displayed in the player's Discord Rich Presence section.
---@param line1 string The first line.
---@param line2 string The second line.
---@param countTime boolean? Whether to count time. If set to `true`, the timer will start at 00:00 and will be counting up.
function DiscordRichPresence:setStatus(line1, line2, countTime)
	self.status = {details = line1, state = line2}
	if countTime then
		self.status.startTimestamp = os.time(os.date("*t"))
	else
		self.status.startTimestamp = nil
	end
	self.status.largeImageKey = "icon_rpc"
	if self.egg then
		self.status.largeImageText = self.egg
	end
end



---Returns a random witty comment to be shown... uh, somewhere.
---@return string
function DiscordRichPresence:getEgg()
	local eggs = _StrSplit(_LoadFile("assets/eggs_rpc.txt"), "\n")
	return eggs[math.random(1, #eggs)]
end



return DiscordRichPresence
