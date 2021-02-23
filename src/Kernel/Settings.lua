local class = require "com/class"
local Settings = class:derive("Settings")

function Settings:new(path)
	self.path = path
	self:load()
end



function Settings:reset()
	if not self.data then
		print("Resetting Engine Settings...")
		self.data = {}
	end

	if self:getDiscordRPC() == nil then self:setDiscordRPC(true) end
	if self:getBackToBoot() == nil then self:setBackToBoot(false) end
	if self:getAimingRetical() == nil then self:setAimingRetical(true) end
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

function Settings:setAimingRetical(value)
	self.data.aimingRetical = value
end

function Settings:getAimingRetical()
	return self.data.aimingRetical
end



function Settings:save()
	saveJson(self.path, self.data)
end

function Settings:load()
	local success, data = pcall(function() return loadJson(self.path) end)

	-- default options if not found
	if success then self.data = data else self.data = nil end
	self:reset()
end



return Settings