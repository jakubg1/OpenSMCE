local class = require "class"
local Options = class:derive("Options")

function Options:new()
	self.options = self:load()
	
	-- default options if not found
	if not self.options then self.options = {} end
	if not self:getMusicVolume() then self:setMusicVolume(1) end
	if not self:getSoundVolume() then self:setSoundVolume(1) end
	if self:getFullscreen() == nil then self:setFullscreen(false) end
	if self:getMute() == nil then self:setMute(false) end
	
	-- fullscreen on start
	if self:getFullscreen() then game:setFullscreen(true) end
end

function Options:save()
	local data = loadJson(parsePath("runtime.json"))
	data.options = self.options
	saveJson(parsePath("runtime.json"), data)
end

function Options:load()
	return loadJson(parsePath("runtime.json")).options
end



function Options:setMusicVolume(value)
	self.options.musicVolume = value
end

function Options:getMusicVolume()
	return self.options.musicVolume
end

function Options:setSoundVolume(value)
	self.options.soundVolume = value
end

function Options:getSoundVolume()
	return self.options.soundVolume
end

function Options:setFullscreen(value)
	self.options.fullscreen = value
	game:setFullscreen(value)
end

function Options:getFullscreen()
	return self.options.fullscreen
end

function Options:setMute(value)
	self.options.mute = value
end

function Options:getMute()
	return self.options.mute
end



function Options:getEffectiveMusicVolume()
	return self:getMute() and 0 or self:getMusicVolume()
end

function Options:getEffectiveSoundVolume()
	return self:getMute() and 0 or self:getSoundVolume()
end



return Options