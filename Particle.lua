local class = require "class"
local Particle = class:derive("Particle")

local Sprite = require("Sprite")

function Particle:new(data, pos, variables)
	self.sprite = Sprite(parseString(data.sprite, variables), variables)
	
	self.time = 0
	self.pos = pos
	self.speed = parseVec2(data.speed, variables)
	self.acceleration = parseVec2(data.acceleration, variables)
	self.lifespan = data.lifespan -- nil if it lives indefinitely
	self.bounds = data.bounds
	
	self.delQueue = false
end

function Particle:update(dt)
	self.time = self.time + dt
	self.speed = self.speed + self.acceleration * dt
	self.pos = self.pos + self.speed * dt
	if self.lifespan and self.time >= self.lifespan then self:destroy() end
	if self.bounds then for i = 1, 4 do if self:isPastBound(i) then self:useBoundBehavior(i) end end end
	
	self.sprite:update(dt)
end

function Particle:isPastBound(boundID)
	local bound = self.bounds[boundID]
	if boundID == 1 then -- left
		return self.pos.x < bound.offset
	elseif boundID == 2 then -- right
		return NATIVE_RESOLUTION.x - self.pos.x < bound.offset
	elseif boundID == 3 then -- up
		return self.pos.y < bound.offset
	elseif boundID == 4 then -- down
		return NATIVE_RESOLUTION.y - self.pos.y < bound.offset
	end
end

function Particle:useBoundBehavior(boundID)
	local bound = self.bounds[boundID]
	if boundID == 1 then -- left
		if bound.behavior == "bounce" then
			self.pos.x = bound.offset
			self.speed.x = -self.speed.x
		elseif bound.behavior == "destroy" then
			self:destroy()
		end
	elseif boundID == 2 then -- right
		if bound.behavior == "bounce" then
			self.pos.x = NATIVE_RESOLUTION.x - bound.offset
			self.speed.x = -self.speed.x
		elseif bound.behavior == "destroy" then
			self:destroy()
		end
	elseif boundID == 3 then -- up
		if bound.behavior == "bounce" then
			self.pos.y = bound.offset
			self.speed.y = -self.speed.y
		elseif bound.behavior == "destroy" then
			self:destroy()
		end
	elseif boundID == 4 then -- down
		if bound.behavior == "bounce" then
			self.pos.y = NATIVE_RESOLUTION.y - bound.offset
			self.speed.y = -self.speed.y
		elseif bound.behavior == "destroy" then
			self:destroy()
		end
	end
end

function Particle:draw(variables)
	self.sprite:draw(self.pos, variables)
end

function Particle:destroy()
	if self.delQueue then return end
	-- the particle won't disappear by itself, an object that holds it must eliminate it from the list
	self.delQueue = true
end

return Particle