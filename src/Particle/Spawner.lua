local class = require "com/class"

---@class ParticleSpawner
---@overload fun(manager, packet, data):ParticleSpawner
local ParticleSpawner = class:derive("ParticleSpawner")

local Vec2 = require("src/Essentials/Vector2")



function ParticleSpawner:new(manager, packet, data)
	self.manager = manager
	self.packet = packet
	self.packet.spawnerCount = self.packet.spawnerCount + 1
	self.layer = self.packet.layer

	self.pos = _ParseVec2(data.pos)
	self.speed = _ParseVec2(data.speed)
	self.acceleration = _ParseVec2(data.acceleration)
	self.lifespan = data.lifespan -- nil if it lives indefinitely
	self.lifetime = self.lifespan
	self.spawnMax = data.spawnMax
	self.pieceCount = 0
	self.spawnDelay = data.spawnDelay
	self.particleData = data.particleData

	self.spawnNext = self.spawnDelay

	for i = 1, data.spawnCount do self:spawnPiece() end

	self.delQueue = false
end

function ParticleSpawner:update(dt)
	-- speed and position stuff
	self.speed = self.speed + self.acceleration * dt
	self.pos = self.pos + self.speed * dt

	-- lifespan
	if self.lifetime then
		self.lifetime = self.lifetime - dt
		if self.lifetime <= 0 then self:destroy() end
	end

	-- piece spawning
	if self.spawnNext then
		self.spawnNext = self.spawnNext - dt
		while self.spawnNext <= 0 and self.pieceCount < self.spawnMax do
			self:spawnPiece()
			self.spawnNext = self.spawnNext + self.spawnDelay
		end
	end

	-- destroy when packet is gone
	if self.packet.delQueue then
		self:destroy()
	end
end



function ParticleSpawner:getPos()
	return self.pos + self.packet.pos
end

function ParticleSpawner:draw()
	local p = _PosOnScreen(self:getPos())
	love.graphics.setColor(1, 0, 0)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", p.x - 10, p.y - 10, 20, 20)
end

function ParticleSpawner:spawnPiece()
	if self.pieceCount == self.spawnMax then return end

	self.manager:spawnParticlePiece(self, self.particleData)
end



function ParticleSpawner:destroy()
	if self.delQueue then return end
	self.delQueue = true

	self.manager:destroyParticleSpawner(self)
	self.packet.spawnerCount = self.packet.spawnerCount - 1
end

return ParticleSpawner
