local class = require "com.class"

---@class Options
---@overload fun(data):Options
local Options = class:derive("Options")



---Constructs an Options object.
---@param data table The data to be read.
function Options:new(data)
	self.data = data

	-- default options if not found
	if not self.data then self:reset() end

	-- fullscreen on start
	if self:getFullscreen() then _Game:setFullscreen(true) end
end



---Resets all options to default values.
function Options:reset()
	_Log:printt("Options", "Resetting Options...")

	self.data = {}
	self:setMusicVolume(0.25)
	self:setSoundVolume(0.25)
	self:setFullscreen(false)
	self:setMute(false)
end



---Sets the music volume.
---@param value number A percentage value. 0 is muted, 1 is maximum volume.
function Options:setMusicVolume(value)
	self.data.musicVolume = value
end

---Returns the current music volume setting.
---@return number
function Options:getMusicVolume()
	return self.data.musicVolume
end

---Sets the sound volume.
---@param value number A percentage value. 0 is muted, 1 is maximum volume.
function Options:setSoundVolume(value)
	self.data.soundVolume = value
end

---Returns the current sound volume setting.
---@return number
function Options:getSoundVolume()
	return self.data.soundVolume
end

---Sets the fullscreen flag.
---@param value boolean Whether the fullscreen should be active.
function Options:setFullscreen(value)
	self.data.fullscreen = value
	_Game:setFullscreen(value)
end

---Returns the current fullscreen flag status.
---@return boolean
function Options:getFullscreen()
	return self.data.fullscreen
end

---Sets the mute flag.
---@param value boolean Whether no music should come from the speakers.
function Options:setMute(value)
	self.data.mute = value
end

---Returns the current status of the mute flag.
---@return boolean
function Options:getMute()
	return self.data.mute
end



---Returns `0` if the mute flag is set, else the current music volume.
---@return number
function Options:getEffectiveMusicVolume()
	return self:getMute() and 0 or self:getMusicVolume()
end

---Returns `0` if the mute flag is set, else the current sound volume.
---@return number
function Options:getEffectiveSoundVolume()
	return self:getMute() and 0 or self:getSoundVolume()
end



return Options