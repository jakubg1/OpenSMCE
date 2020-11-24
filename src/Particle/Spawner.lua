local class = require "com/class"
local ParticleSpawner = class:derive("ParticleSpawner")

function ParticleSpawner:new(manager, data, pos)
	self.manager = manager
	
	self.pos = pos
	self.speed = parseVec2(data.speed)
	self.acceleration = parseVec2(data.acceleration)
	self.lifespan = data.lifespan -- nil if it lives indefinitely
	self.lifetime = self.lifespan
	self.spawnRemain = data.spawnMax
	self.spawnDelay = data.spawnDelay
	self.particleData = data.particleData
	
	self.spawnNext = self.spawnDelay
	
	for i = 1, data.spawnCount do self:spawnPiece() end
	
	self.delQueue = false
end

function ParticleSpawner:update(dt)
	self.speed = self.speed + self.acceleration * dt
	self.pos = self.pos + self.speed * dt
	if self.lifetime then
		self.lifetime = self.lifetime - dt
		if self.lifetime <= 0 then self:destroy() end
	end
	if self.spawnNext then
		self.spawnNext = self.spawnNext - dt
		if self.spawnNext <= 0 then
			self:spawnPiece()
			self.spawnNext = self.spawnNext + self.spawnDelay
		end
	end
end

function ParticleSpawner:draw()
	local p = posOnScreen(self.pos)
	love.graphics.setColor(1, 0, 0)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", p.x - 10, p.y - 10, 20, 20)
end

function ParticleSpawner:spawnPiece()
	if self.spawnRemain == 0 then return end
	self.spawnRemain = self.spawnRemain - 1
	
	self.manager:spawnParticlePiece(self.particleData, self.pos)
end



function ParticleSpawner:destroy()
	if self.delQueue then return end
	self.delQueue = true
	
	self.manager:destroyParticleSpawner(self)
end

return ParticleSpawner