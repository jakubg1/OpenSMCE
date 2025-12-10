local class = require "com.class"

---Represents the Game options. Not to be mistaken with Engine Settings!
---@class Options
---@overload fun():Options
local Options = class:derive("Options")

---Constructs an Options object.
function Options:new()
	self.musicVolume = 0.25
	self.soundVolume = 0.25
	self.fullscreen = false
	self.mute = false
end

---Sets the music volume.
---@param value number A percentage value. 0 is muted, 1 is maximum volume.
function Options:setMusicVolume(value)
	self.musicVolume = value
end

---Returns the current music volume setting.
---@return number
function Options:getMusicVolume()
	return self.musicVolume
end

---Sets the sound volume.
---@param value number A percentage value. 0 is muted, 1 is maximum volume.
function Options:setSoundVolume(value)
	self.soundVolume = value
end

---Returns the current sound volume setting.
---@return number
function Options:getSoundVolume()
	return self.soundVolume
end

---Sets the fullscreen flag.
---@param value boolean Whether the fullscreen should be active.
function Options:setFullscreen(value)
	self.fullscreen = value
	_Display:setFullscreen(value)
end

---Returns the current fullscreen flag status.
---@return boolean
function Options:getFullscreen()
	return self.fullscreen
end

---Sets the mute flag.
---@param value boolean Whether no music should come from the speakers.
function Options:setMute(value)
	self.mute = value
end

---Returns the current status of the mute flag.
---@return boolean
function Options:getMute()
	return self.mute
end

---Returns `0` if the mute flag is set, else the current music volume.
---@return number
function Options:getEffectiveMusicVolume()
	return self.mute and 0 or self.musicVolume
end

---Returns `0` if the mute flag is set, else the current sound volume.
---@return number
function Options:getEffectiveSoundVolume()
	return self.mute and 0 or self.soundVolume
end

---Returns Options' data, ready to be saved in JSON format.
---@return table
function Options:serialize()
	local t = {}
	t.musicVolume = self.musicVolume
	t.soundVolume = self.soundVolume
	t.fullscreen = self.fullscreen
	t.mute = self.mute
	return t
end

---Loads previously saved data into the Options.
---@param t table Data previously saved with `:serialize()`.
function Options:deserialize(t)
	self.musicVolume = t.musicVolume
	self.soundVolume = t.soundVolume
	self.fullscreen = t.fullscreen
	self.mute = t.mute
	-- Update the fullscreen state.
	if self.fullscreen then
		_Display:setFullscreen(true)
	end
end

return Options