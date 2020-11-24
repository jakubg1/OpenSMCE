local class = require "com/class"
local Sound = class:derive("Sound")

function Sound:new(path, looping)
	print("Loading sound data from " .. path .. "...")
	self.INSTANCE_COUNT = 8
	-- Each sound has 8 instances of it so it can play up to 8 instances at the same time.
	self.instances = {}
	for i = 1, self.INSTANCE_COUNT do
		self.instances[i] = loadSound(path, "static")
		if not self.instances[i] then error("Failed to load sound: " .. path) end
		if looping then self.instances[i]:setLooping(looping) end
	end
end

function Sound:update(dt)
	self:setVolume(game.runtimeManager.options:getEffectiveSoundVolume())
end

function Sound:play(pitch)
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