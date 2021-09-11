local class = require "com/class"
local SoundEvent = class:derive("SoundEvent")

function SoundEvent:new(path)
	self.path = path
  local data = loadJson(path)

  self.sound = nil
  if data.path then
    self.sound = game.resourceManager:getSound(data.path)
  end
  self.volume = data.volume or 1
  self.pitch = data.volume or 1
  self.loop = data.loop or false
end

function SoundEvent:play(pitch, pos)
  if not self.sound then
    return self
  end
  pitch = pitch or 1
  local eventVolume = parseNumber(self.volume)
  local eventPitch = parseNumber(self.pitch)
  return self.sound:play(eventVolume, pitch * eventPitch, pos, self.loop)
end

function SoundEvent:stop()
  if not self.sound then
    return
  end
  self.sound:stop()
end

return SoundEvent
