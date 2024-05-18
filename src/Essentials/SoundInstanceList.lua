local class = require "com.class"

---Represents a list of Sound instances. Since Sound Events can play a few different instances at the same time, this class allows you to control all of them at once.
---@class SoundInstanceList
---@overload fun(instances):SoundInstanceList
local SoundInstanceList = class:derive("SoundInstanceList")



---Constructs a new Sound Instance List.
---@param instances table A list of sound instances.
function SoundInstanceList:new(instances)
    self.sounds = instances
end

---Updates the Sound Instances, so they can adapt to the game volume.
---@param dt number Time delta in seconds.
function SoundInstanceList:update(dt)
    for i, sound in ipairs(self.sounds) do
        sound:update(dt)
    end
end

---Plays the Instances.
function SoundInstanceList:play()
    for i, sound in ipairs(self.sounds) do
        sound:play()
    end
end

---Stops the Instances.
function SoundInstanceList:stop()
    for i, sound in ipairs(self.sounds) do
        sound:stop()
    end
end

---Sets the volume of Instances.
---@param volume number The new volume, as a percentage.
function SoundInstanceList:setVolume(volume)
    for i, sound in ipairs(self.sounds) do
        sound:setVolume(volume)
    end
end

---Sets the pitch of Instances.
---@param pitch number The new pitch, as a percentage.
function SoundInstanceList:setPitch(pitch)
    for i, sound in ipairs(self.sounds) do
        sound:setPitch(pitch)
    end
end

---Sets the position of Instances.
---@param pos Vector2? The new position. Passing `nil` does nothing.
function SoundInstanceList:setPos(pos)
    for i, sound in ipairs(self.sounds) do
        sound:setPos(pos)
    end
end

---Returns whether at least one of Instances is currently being played.
---@return boolean
function SoundInstanceList:isPlaying()
    for i, sound in ipairs(self.sounds) do
        if sound:isPlaying() then
            return true
        end
    end
    return false
end



return SoundInstanceList
