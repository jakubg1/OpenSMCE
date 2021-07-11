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

  self.pos = Vec2()
end

function SoundInstance:update(dt)
	self:setVolume(game.runtimeManager.options:getEffectiveSoundVolume())
end

function SoundInstance:play(pitch)
	pitch = pitch or 1
	for i, instance in ipairs(self.instances) do
		if not instance:isPlaying() then
			instance:setPitch(pitch)
			instance:play()
			return
		end
	end
	-- might add an algorithm that will nuke one of the sounds and play it again on that instance if no free instances
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
  self.pos = pos
end

function SoundInstance:isPlaying()
  return self.sound:isPlaying()
end

return SoundInstance
