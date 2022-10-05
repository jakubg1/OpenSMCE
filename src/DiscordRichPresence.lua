local class = require "com/class"

---@class DiscordRichPresence
---@overload fun():DiscordRichPresence
local DiscordRichPresence = class:derive("DiscordRichPresence")

local discordRPCMain = require("com/discordRPC")



---Constructs this class.
function DiscordRichPresence:new()
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



	function discordRPCMain.ready(userId, username, discriminator, avatar)
		self.connected = true
		self.username = string.format("%s#%s", username, discriminator)
		_Debug.console:print({{0, 1, 1}, "[DiscordRPC] ", {0, 1, 0}, string.format("Connected! (username: %s)", self.username)})
	end

	function discordRPCMain.disconnected(errorCode, message)
		self.connected = false
		self.username = nil
		print(string.format("[DiscordRPC] disconnected (%d: %s)", errorCode, message))
	end

	function discordRPCMain.errored(errorCode, message)
		print(string.format("[DiscordRPC] error (%d: %s)", errorCode, message))
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
	self.updateTime = self.updateTime + dt
	if self.updateTime >= self.UPDATE_INTERVAL then
		self.updateTime = 0
		discordRPCMain.updatePresence(self.status)
	end
	discordRPCMain.runCallbacks()
end



---Connects Discord Rich Presence.
function DiscordRichPresence:connect()
	if self.enabled then return end
	print("[DiscordRPC] Connecting...")
	discordRPCMain.initialize(_DISCORD_APPLICATION_ID, true)
	self.enabled = true
end



---Disconnects Discord Rich Presence.
function DiscordRichPresence:disconnect()
	if not self.enabled then return end
	print("[DiscordRPC] Disconnecting...")
    discordRPCMain.shutdown()
	self.enabled = false
	self.connected = false
	self.username = nil
end



---Updates information to be displayed in the player's Discord Rich Presence section.
---@param line1 string The first line.
---@param line2 string The second line.
---@param countTime boolean Whether to count time. If set to `true`, the timer will start at 00:00 and will be counting up.
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
