local class = require "com/class"
local Sound = class:derive("Sound")

local SoundInstance = require("src/Essentials/SoundInstance")

function Sound:new(path, looping)
	print("Loading sound data from " .. path .. "...")
	self.INSTANCE_COUNT = 8
	-- Each sound has 8 instances of it so it can play up to 8 instances at the same time.
	self.instances = {}
	for i = 1, self.INSTANCE_COUNT do
		self.instances[i] = SoundInstance(path, looping)
	end
end

function Sound:update(dt)
	self:setVolume(game.runtimeManager.options:getEffectiveSoundVolume())
end

function Sound:getFreeInstance()
	for i, instance in ipairs(self.instances) do
		if not instance:isPlaying() then
			return instance
		end
	end
end

function Sound:play(pitch, pos)
	pitch = pitch or 1
	local instance = self:getFreeInstance()
	if instance then
		instance:setPitch(pitch)
		instance:setPos(pos)
		instance:play()
		return instance
	end
	-- might add an algorithm that will nuke one of the sounds and play it again on that instance if no free instances
end

function Sound:stop()
	for i, instance in ipairs(self.instances) do
		instance:stop()
	end
end

function Sound:setVolume(volume)
	for i, instance in ipairs(self.instances) do
		instance:setVolume(volume)
	end
end

return Sound
