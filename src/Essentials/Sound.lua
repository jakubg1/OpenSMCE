local class = require "com.class"

---Represents a Sound loaded from an audio file.
---@class Sound
---@overload fun(path):Sound
local Sound = class:derive("Sound")



---Constructs a new Sound.
---@param path string The path to the sound file.
function Sound:new(path)
	self.data = _Utils.loadSoundData(path)
end



return Sound
