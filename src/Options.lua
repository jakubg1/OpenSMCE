local class = require "com/class"

---@class Options
---@overload fun(data):Options
local Options = class:derive("Options")



function Options:new(data)
	self.data = data
	
	-- default options if not found
	if not self.data then self:reset() end
	
	-- fullscreen on start
	if self:getFullscreen() then _Game:setFullscreen(true) end
end



function Options:reset()
	print("Resetting Options...")
	
	self.data = {}
	self:setMusicVolume(0.25)
	self:setSoundVolume(0.25)
	self:setFullscreen(false)
	self:setMute(false)
end



function Options:setMusicVolume(value)
	self.data.musicVolume = value
end

function Options:getMusicVolume()
	return self.data.musicVolume
end

function Options:setSoundVolume(value)
	self.data.soundVolume = value
end

function Options:getSoundVolume()
	return self.data.soundVolume
end

function Options:setFullscreen(value)
	self.data.fullscreen = value
	_Game:setFullscreen(value)
end

function Options:getFullscreen()
	return self.data.fullscreen
end

function Options:setMute(value)
	self.data.mute = value
end

function Options:getMute()
	return self.data.mute
end



function Options:getEffectiveMusicVolume()
	return self:getMute() and 0 or self:getMusicVolume()
end

function Options:getEffectiveSoundVolume()
	return self:getMute() and 0 or self:getSoundVolume()
end



return Options