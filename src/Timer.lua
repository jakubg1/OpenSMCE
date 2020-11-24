local class = require "com/class"
local Timer = class:derive("Timer")

function Timer:new()
	self.frameLength = 1 / 60
	self.time = 0
end

function Timer:update(dt)
	self.time = self.time + dt
end

function Timer:getFrameCount()
	local t = 0
	while self.time >= self.frameLength do
		self.time = self.time - self.frameLength
		t = t + 1
	end
	return math.min(t, 3) -- 3 is the maximum number of frames it can perform at once, when in serious lag
end

return Timer