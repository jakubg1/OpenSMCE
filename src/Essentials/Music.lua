local class = require "com.class"

---@class Music
---@overload fun(path):Music
local Music = class:derive("Music")



function Music:new(path)
	self.instance = _Utils.loadSound(path, "stream")
	if not self.instance then error("Failed to load sound: " .. path) end
	self.instance:setLooping(true)

	self.volume = 0
	self.volumeDes = 0
	self.volumeFadeSpeed = 1
end

function Music:update(dt)
	local volumeDes = math.max(self.volumeDes, 0)
	if self.volume ~= volumeDes then
		if self.volume > volumeDes then
			self.volume = math.max(self.volume - dt * self.volumeFadeSpeed, volumeDes)
		else
			self.volume = math.min(self.volume + dt * self.volumeFadeSpeed, volumeDes)
		end
	end
	self:updateVolume()
	self:updatePlaying()
end

function Music:updateVolume()
	self.instance:setVolume(self.volume * _Game.runtimeManager.options:getEffectiveMusicVolume())
end

function Music:updatePlaying()
	if self.instance:isPlaying() and self.volume <= 0 then if self.volumeDes == -1 then self:stop() else self:pause() end end
	if not self.instance:isPlaying() and self.volume > 0 then self:play() end
end

function Music:reset()
	self:stop()
	self:setVolume(1, true)
	self:play()
end

function Music:play()
	self.instance:play()
end

function Music:pause()
	self.instance:pause()
end

function Music:stop()
	self.instance:stop()
end

function Music:setVolume(volume, instant)
	self.volumeDes = volume
	if instant then
		self.volume = self.volumeDes
		self:updateVolume()
	end
end

return Music
