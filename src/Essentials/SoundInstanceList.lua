local class = require "com.class"

---Represents a list of Sound instances. Since Sound Events can play a few different instances at the same time, this class allows you to control all of them at once.
---@class SoundInstanceList
---@overload fun(instances):SoundInstanceList
local SoundInstanceList = class:derive("SoundInstanceList")

---Constructs a new Sound Instance List.
---@param instances SoundInstance[] A list of sound instances.
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

---Plays all Sound Instances within the list.
function SoundInstanceList:play()
    for i, sound in ipairs(self.sounds) do
        sound:play()
    end
end

---Stops all Sound Instances within the list.
function SoundInstanceList:stop()
    for i, sound in ipairs(self.sounds) do
        sound:stop()
    end
end

---Sets the volume of all Sound Instances within the list.
---@param volume number The new volume, as a percentage.
function SoundInstanceList:setVolume(volume)
    for i, sound in ipairs(self.sounds) do
        sound:setVolume(volume)
    end
end

---Sets the pitch of all Sound Instances within the list.
---@param pitch number The new pitch, as a percentage.
function SoundInstanceList:setPitch(pitch)
    for i, sound in ipairs(self.sounds) do
        sound:setPitch(pitch)
    end
end

---Sets the position of all Sound Instances within the list.
---@param x number The new X position.
---@param y number The new Y position.
function SoundInstanceList:setPos(x, y)
    for i, sound in ipairs(self.sounds) do
        sound:setPos(x, y)
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
