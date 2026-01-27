local class = require "com.class"

---Represents the Game options. Not to be mistaken with Engine Settings!
---@class Options
---@overload fun():Options
local Options = class:derive("Options")

---Constructs an Options object.
function Options:new()
	self.data = {
		musicVolume = 0.25,
		soundVolume = 0.25,
		fullscreen = false,
		mute = false
	}
end

---Sets a setting based on its key.
---@param key string The setting key.
---@param value any The setting value.
function Options:setSetting(key, value)
	self.data[key] = value
end

---Gets a setting based on its key.
---@param key string The setting key.
---@return any
function Options:getSetting(key)
	return self.data[key]
end

---Returns `0` if the mute flag is set, else the current music volume.
---@return number
function Options:getEffectiveMusicVolume()
	return self.data.mute and 0 or self.data.musicVolume
end

---Returns `0` if the mute flag is set, else the current sound volume.
---@return number
function Options:getEffectiveSoundVolume()
	return self.data.mute and 0 or self.data.soundVolume
end

---Returns Options' data, ready to be saved in JSON format.
---@return table
function Options:serialize()
	return self.data
end

---Loads previously saved data into the Options.
---@param t table Data previously saved with `:serialize()`.
function Options:deserialize(t)
	self.data = t
end

return Options