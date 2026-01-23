local class = require "com.class"

---Represents a Sound loaded from an audio file. This can be also a piece of music.
---@class Sound
---@overload fun(data, path):Sound
local Sound = class:derive("Sound")

---Constructs a new Sound.
---@param data nil Unused, but required due to standardized resource constructors.
---@param path string The path to the sound file.
function Sound:new(data, path)
	self.data = _Utils.loadSoundData(_ParsePath(path))
	assert(self.data, "Failed to load sound data: " .. path)
end

---Makes a LOVE2D Audio Source from the data of this Sound.
---@param type love.SourceType The type of this source. Use `"static"` for short audio samples (SFX) and `"stream"` for music.
---@return love.Source
function Sound:makeSource(type)
	return love.audio.newSource(self.data, type)
end

---Makes a special advanced source type for extra functionality from ASL.
---DO NOT USE UNLESS NECESSARY: Advanced sources consume extra memory and CPU power whenever you alter their state.
---@return table
function Sound:makeAdvancedSource()
	return love.audio.newAdvancedSource(self.data)
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function Sound.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a Sound by a given path.
    ---@param path string The resource path.
    ---@return Sound
    function ResourceManager:getSound(path)
        return self:getResourceAsset(path, "Sound")
    end
end

return Sound
