local class = require "com.class"

---Represents an instance of a Sound. Each Sound comes with a specified number of instances, so a few instances of the same sound file can be played at the same time.
---@class SoundInstance
---@overload fun(instance):SoundInstance
local SoundInstance = class:derive("SoundInstance")

local Vec2 = require("src.Essentials.Vector2")



---Constructs a new Sound Instance.
---@param instance love.Source A sound instance, if preloaded.
function SoundInstance:new(instance)
  self.sound = instance

  self.volume = 1
  self.pos = _Game:getNativeResolution() / 2
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
---@param pos Vector2? The new position. Passing `nil` does nothing.
function SoundInstance:setPos(pos)
  -- pos may be nilled by SoundEvent when flat flag is set
  if not pos or self.sound:getChannelCount() > 1 then
    return
  end

  if _EngineSettings:get3DSound() then
    self.pos = pos
    local p = pos - _Game:getNativeResolution() / 2
    self.sound:setPosition(p.x, p.y, _Game:getNativeResolution().x * 2.5)
    self.sound:setAttenuationDistances(0, _Game:getNativeResolution().x)
  else
    self.pos = Vec2()
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
