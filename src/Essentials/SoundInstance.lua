local class = require "com/class"
local SoundInstance = class:derive("SoundInstance")

local Vec2 = require("src/Essentials/Vector2")

function SoundInstance:new(path)
  self.sound = loadSound(path, "static")
	if not self.sound then
    error("Failed to load sound: " .. path)
  end

  self.volume = 1
  self.pos = NATIVE_RESOLUTION / 2
end

function SoundInstance:update(dt)
	self.sound:setVolume(game.runtimeManager.options:getEffectiveSoundVolume() * self.volume)
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
  if engineSettings:get3DSound() and pos then
    self.pos = pos
    local p = pos - NATIVE_RESOLUTION / 2
    self.sound:setPosition(p.x, p.y, 0)
    self.sound:setAttenuationDistances(0, NATIVE_RESOLUTION.x)
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
