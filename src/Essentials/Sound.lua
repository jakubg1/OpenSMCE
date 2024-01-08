local class = require "com.class"

---Represents a Sound loaded from an audio file. This can be also a piece of music.
---@class Sound
---@overload fun(path):Sound
local Sound = class:derive("Sound")



---Constructs a new Sound.
---@param path string The path to the sound file.
function Sound:new(path)
	self.data = _Utils.loadSoundData(path)
end



---Makes a LOVE2D Audio Source from the data of this Sound.
---@param type "static"|"stream" The type of this source. Use `"static"` for short audio samples (SFX) and `"stream"` for music.
---@return love.Source
function Sound:makeSource(type)
	return love.audio.newSource(self.data, type)
end



return Sound
