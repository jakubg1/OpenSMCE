local class = require "com.class"

---Manages the Game's timing. Ensures the frame length is always consistent and prevents skipping too many frames when lag occurs.
---@class Timer
---@overload fun():Timer
local Timer = class:derive("Timer")



---Constructor function.
function Timer:new()
	-- How long is one frame in seconds.
	self.FRAME_LENGTH = 1 / _Game.configManager:getTickRate()
	-- The maximum number of frames to be returned by `getFrameCount()`.
	self.MAX_FRAMES = 6
	-- Maximum deviation from the target frame length.
	-- Used to mitigate the problem of frame skipping (the internal timer rapidly overflowing and underflowing),
	-- which causes the game to alternate between performing 0 and 2 frames each real frame.
	-- This means visible stuttering.
	self.MAX_FRAME_ADJUSTMENT = 0.003
	-- The internal timer, being accumulated time to in seconds.
	self.time = 0
end



---Updates the Timer by a specified value in seconds.
---@param dt number Delta time in seconds.
function Timer:update(dt)
	self.time = self.time + dt
end



---Returns the number of frames that should be performed since the last call of this function.
---The second returned value is the frame length. It might slightly deviate from the target frame length.
---The internal counter is then decremented by the time equivalent.
---
---The maximum value which can be returned is `MAX_FRAMES`. This means the game will not process more than `MAX_FRAMES` frames at once.
---In that case, the time counter is still capped to an equivalent of one frame.
---@return number
---@return number
function Timer:getFrameCount()
	local t = 0
	while self.time >= self.FRAME_LENGTH do
		self.time = self.time - self.FRAME_LENGTH
		t = t + 1
	end
	local frames = math.min(t, self.MAX_FRAMES)
	local dt = self.FRAME_LENGTH
	-- If this is just one frame, correct the frame length if it deviates just slightly to avoid stuttering.
	if t == 1 then
		local deviation = self.time - self.FRAME_LENGTH / 2
		if deviation > -self.MAX_FRAME_ADJUSTMENT and deviation < self.MAX_FRAME_ADJUSTMENT then
			dt = dt + deviation
			self.time = self.time - deviation
		end
	end
	return frames, dt
end



return Timer
