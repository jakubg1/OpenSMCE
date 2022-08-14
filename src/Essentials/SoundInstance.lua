local class = require "com/class"
local SoundInstance = class:derive("SoundInstance")

local Vec2 = require("src/Essentials/Vector2")

function SoundInstance:new(path, instance)
  if path then
    self.sound = _LoadSound(path, "static")
    if not self.sound then
      error("Failed to load sound: " .. path)
    end
  elseif instance then
    self.sound = instance
  end

  self.volume = 1
  self.pos = _NATIVE_RESOLUTION / 2
end

function SoundInstance:update(dt)
	self.sound:setVolume(_Game.runtimeManager.options:getEffectiveSoundVolume() * self.volume)
end

function SoundInstance:play()
	self.sound:play()
end

function SoundInstance:stop()
	self.sound:stop()
end

function SoundInstance:setVolume(volume)
	self.volume = volume
end

function SoundInstance:setPitch(pitch)
  self.sound:setPitch(pitch)
end

function SoundInstance:setPos(pos)
  -- pos may be nilled by SoundEvent when flat flag is set
  if not pos then
    return
  end

  if _EngineSettings:get3DSound() and pos then
    self.pos = pos
    local p = pos - _NATIVE_RESOLUTION / 2
    self.sound:setPosition(p.x, p.y, 0)
    self.sound:setAttenuationDistances(0, _NATIVE_RESOLUTION.x)
  else
    self.pos = Vec2()
    self.sound:setPosition(0, 0, 0)
  end
end

function SoundInstance:setLoop(loop)
  self.sound:setLooping(loop)
end

function SoundInstance:isPlaying()
  return self.sound:isPlaying()
end

return SoundInstance
