local class = require "com/class"
local DiscordRichPresence = class:derive("DiscordRichPresence")

local discordRPCMain = require("com/discordRPC")



function DiscordRichPresence:new()
	self.enabled = false
	self.connected = false
	self.username = nil
	
	self.UPDATE_INTERVAL = 2
	self.updateTime = 0
	
	self.status = {}
	
	
	
	function discordRPCMain.ready(userId, username, discriminator, avatar)
		self.connected = true
		self.username = string.format("%s#%s", username, discriminator)
		print(string.format("[DiscordRPC] Connected! (username: %s)", self.username))
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

function DiscordRichPresence:update(dt)
	self.updateTime = self.updateTime + dt
	if self.updateTime >= self.UPDATE_INTERVAL then
		self.updateTime = 0
		discordRPCMain.updatePresence(self.status)
	end
	discordRPCMain.runCallbacks()
end



function DiscordRichPresence:connect()
	if self.enabled then return end
	print("[DiscordRPC] Connecting...")
	discordRPCMain.initialize(DISCORD_APPLICATION_ID, true)
	self.enabled = true
end

function DiscordRichPresence:disconnect()
	if not self.enabled then return end
	print("[DiscordRPC] Disconnecting...")
    discordRPCMain.shutdown()
	self.enabled = false
	self.connected = false
	self.username = nil
end

function DiscordRichPresence:setStatus(line1, line2, countTime)
	self.status = {details = line1, state = line2}
	if countTime then
		self.status.startTimestamp = os.time(os.date("*t"))
	else
		self.status.startTimestamp = nil
	end
end



return DiscordRichPresence