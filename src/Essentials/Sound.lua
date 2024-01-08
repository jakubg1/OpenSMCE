local class = require "com.class"

---Represents a Sound loaded from an audio file. This can be also a piece of music.
---@class Sound
---@overload fun(data, path, namespace, batches):Sound
local Sound = class:derive("Sound")



---Constructs a new Sound.
---@param data nil Unused, but required due to standardized resource constructors.
---@param path string The path to the sound file.
---@param namespace string? The namespace this resource is loaded as. Pass forward to all resource getters inside.
---@param batches table? The batch names this resource is loaded as a part of. Pass forward to all resource getters inside.
function Sound:new(data, path, namespace, batches)
	self.data = _Utils.loadSoundData(_ParsePath(path))
end



---Makes a LOVE2D Audio Source from the data of this Sound.
---@param type "static"|"stream" The type of this source. Use `"static"` for short audio samples (SFX) and `"stream"` for music.
---@return love.Source
function Sound:makeSource(type)
	return love.audio.newSource(self.data, type)
end



return Sound
