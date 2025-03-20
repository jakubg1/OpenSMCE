local class = require "com.class"

---@class Settings
---@overload fun(path):Settings
local Settings = class:derive("Settings")



function Settings:new(path)
	self.path = path
	self:load()
end



function Settings:reset()
	if not self.data then
		_Log:printt("Settings", "Resetting Engine Settings...")
		self.data = {}
	end

	if self:getDiscordRPC() == nil then self:setDiscordRPC(true) end
	if self:getBackToBoot() == nil then self:setBackToBoot(false) end
	if self:getBackToBootWithX() == nil then self:setBackToBootWithX(false) end
	if self:getMaximizeOnStart() == nil then self:setMaximizeOnStart(true) end
	if self:getAimingRetical() == nil then self:setAimingRetical(false) end
	if self:getConsoleWindow() == nil then self:setConsoleWindow(true) end
	if self:get3DSound() == nil then self:set3DSound(false) end
	if self:getHideIncompatibleGames() == nil then self:setHideIncompatibleGames(false) end
	if self:getPrintDeprecationNotices() == nil then self:setPrintDeprecationNotices(false) end
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

function Settings:setBackToBootWithX(value)
	self.data.backToBootWithX = value
end

function Settings:getBackToBootWithX()
	return self.data.backToBootWithX
end

function Settings:setMaximizeOnStart(value)
	self.data.maximizeOnStart = value
end

function Settings:getMaximizeOnStart()
	return self.data.maximizeOnStart
end

function Settings:setAimingRetical(value)
	self.data.aimingRetical = value
end

function Settings:getAimingRetical()
	return self.data.aimingRetical
end

function Settings:setConsoleWindow(value)
	self.data.consoleWindow = value
end

function Settings:getConsoleWindow()
	return self.data.consoleWindow
end

function Settings:set3DSound(value)
	self.data.threedeeSound = value
end

function Settings:get3DSound()
	return self.data.threedeeSound
end

function Settings:setHideIncompatibleGames(value)
	self.data.hideIncompatibleGames = value
end

function Settings:getHideIncompatibleGames()
	return self.data.hideIncompatibleGames
end

function Settings:setPrintDeprecationNotices(value)
	self.data.printDeprecationNotices = value
end

function Settings:getPrintDeprecationNotices()
	return self.data.printDeprecationNotices
end



function Settings:save()
	_Utils.saveJson(self.path, self.data)
end

function Settings:load()
	local success, data = pcall(function() return _Utils.loadJson(self.path) end)

	-- default options if not found
	if success then
		self.data = data
	else
		self.data = nil
	end
	self:reset()
end



return Settings
