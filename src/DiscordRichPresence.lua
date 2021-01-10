local class = require "com/class"
local DiscordRichPresence = class:derive("DiscordRichPresence")

local discordRPCMain = require("com/discordRPC")



function DiscordRichPresence:new()
	self.enabled = false
	self.connected = false
	self.username = nil
	self.UPDATE_INTERVAL = 2
	self.updateTime = 0
	
	self.line1 = "Line 1!!!"
	self.line2 = "Line 2..."
	
	
	
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
		print("a")
		self.updateTime = 0
		discordRPCMain.updatePresence({state = self.line1, details = self.line2})
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

function DiscordRichPresence:setStatus(line1, line2)
	self.line1 = line1
	self.line2 = line2
end



return DiscordRichPresence










--[[

local enabled = false
local connected = false


function love.draw()
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("Connection: ", 10, 10)
	if enabled and connected then
		love.graphics.setColor(0, 1, 0)
		love.graphics.print("ACTIVE", 90, 10)
	elseif enabled and not connected then
		love.graphics.setColor(1, 1, 0)
		love.graphics.print("PENDING", 90, 10)
	elseif not enabled and connected then
		love.graphics.setColor(1, 0.5, 0)
		love.graphics.print("DISCONNECTING", 90, 10)
	elseif not enabled and not connected then
		love.graphics.setColor(0.75, 0.75, 0.75)
		love.graphics.print("INACTIVE", 90, 10)
	end
end

]]