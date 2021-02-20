local class = require "com/class"
local Settings = class:derive("Settings")

function Settings:new(path)
	self.path = path
	self:load()
end



function Settings:reset()
	print("Resetting Engine Settings...")

	self.data = {}
	self:setDiscordRPC(true)
	self:setBackToBoot(false)
end



function Settings:setDiscordRPC(value)
	self.data.discordRPC = value
end

function Settings:getDiscordRPC()
	return self.data.discordRPC
end

function Settings:setBackToBoot(value)
	self.data.backToBoot = value
end

function Settings:getBackToBoot()
	return self.data.backToBoot
end



function Settings:save()
	saveJson(self.path, self.data)
end

function Settings:load()
	local success, data = pcall(function() return loadJson(self.path) end)

	-- default options if not found
	if success then self.data = data else self:reset() end
end



return Settings
