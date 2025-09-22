local class = require "com.class"

---Represents an instance of a Sound. Each Sound comes with a specified number of instances, so a few instances of the same sound file can be played at the same time.
---@class SoundInstance
---@overload fun(instance):SoundInstance
local SoundInstance = class:derive("SoundInstance")

---Constructs a new Sound Instance.
---@param instance love.Source A sound instance, if preloaded.
function SoundInstance:new(instance)
    self.sound = instance

    self.volume = 1
    local w, h = _Game:getNativeResolution()
    self.x, self.y = w / 2, h / 2
end

---Updates a Sound Instance, so it can adapt to the game volume.
---@param dt number Time delta in seconds.
function SoundInstance:update(dt)
    self.sound:setVolume(_Game:getEffectiveSoundVolume() * self.volume)
end

---Plays the Instance.
function SoundInstance:play()
    self.sound:play()
end

---Stops the Instance.
function SoundInstance:stop()
    self.sound:stop()
end

---Sets the volume of this Instance.
---@param volume number The new volume, as a percentage.
function SoundInstance:setVolume(volume)
    self.volume = volume
end

---Sets the pitch of this Instance.
---@param pitch number The new pitch, as a percentage.
function SoundInstance:setPitch(pitch)
    self.sound:setPitch(pitch)
end

---Sets the position of this Instance.
---@param x number The new X position of the sound.
---@param y number The new Y position of the sound.
function SoundInstance:setPos(x, y)
    -- pos may be nilled by SoundEvent when flat flag is set
    if self.sound:getChannelCount() > 1 then
        return
    end

    if _EngineSettings:get3DSound() then
        self.x, self.y = x, y
        local w, h = _Game:getNativeResolution()
        self.sound:setPosition(x - w / 2, y - h / 2, w * 2.5)
        self.sound:setAttenuationDistances(0, w)
    else
        self.x, self.y = 0, 0
        self.sound:setPosition(0, 0, 0)
    end
end

---Sets whether this Instance should be looping.
---@param loop boolean Whether the Instance should be looping.
function SoundInstance:setLoop(loop)
    self.sound:setLooping(loop)
end

---Returns whether this Instance is currently being played.
---@return boolean
function SoundInstance:isPlaying()
    return self.sound:isPlaying()
end

return SoundInstance
