local class = require "com/class"
local SoundInstance = class:derive("SoundInstance")

local Vec2 = require("src/Essentials/Vector2")

function SoundInstance:new(path, looping)
  self.sound = loadSound(path, "static")
	if not self.sound then
    error("Failed to load sound: " .. path)
  end
	if looping then
    self.sound:setLooping(looping)
  end

  self.pos = NATIVE_RESOLUTION / 2
end

function SoundInstance:update(dt)
	self:setVolume(game.runtimeManager.options:getEffectiveSoundVolume())
end

function SoundInstance:play()
	self.sound:play()
end

function SoundInstance:stop()
	self.sound:stop()
end

function SoundInstance:setVolume(volume)
	self.sound:setVolume(volume)
end

function SoundInstance:setPitch(pitch)
  self.sound:setPitch(pitch)
end

function SoundInstance:setPos(pos)
  print(self.sound:getAttenuationDistances())
  if pos then
    self.pos = pos
    local p = pos - NATIVE_RESOLUTION / 2
    self.sound:setPosition(p.x, p.y, 0)
    self.sound:setAttenuationDistances(0, NATIVE_RESOLUTION.x)
  else
    self.pos = Vec2()
    self.sound:setPosition(0, 0, 0)
  end
end

function SoundInstance:isPlaying()
  return self.sound:isPlaying()
end

return SoundInstance
