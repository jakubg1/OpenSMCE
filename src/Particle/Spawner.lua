local class = require "com.class"

---@class ParticleSpawner
---@overload fun(manager, packet, data):ParticleSpawner
local ParticleSpawner = class:derive("ParticleSpawner")

---Constructs a new particle spawner.
---@param manager ParticleManager The owner of this spawner.
---@param packet ParticlePacket The particle packet which spawned this spawner.
---@param data ParticleEmitterConfig Particle spawner data.
function ParticleSpawner:new(manager, packet, data)
	self.manager = manager
	self.packet = packet
	self.packet.spawnerCount = self.packet.spawnerCount + 1
	self.layer = self.packet.layer

	self.x, self.y = data.pos.x, data.pos.y
	self.speedX, self.speedY = data.speed.x, data.speed.y
	self.accelerationX, self.accelerationY = data.acceleration.x, data.acceleration.y
	self.lifespan = data.lifespan -- nil if it lives indefinitely
	self.lifetime = self.lifespan
	self.spawnMax = data.spawnMax
	self.pieceCount = 0
	self.spawnDelay = data.spawnDelay
	self.particleData = data.particleData

	self.spawnNext = self.spawnDelay

	for i = 1, data.spawnCount do
		self:spawnPiece()
	end

	self.delQueue = false
end

---Updates this particle spawner.
---@param dt number Time delta in seconds.
function ParticleSpawner:update(dt)
	-- Sorry! You DIED!
	if self.delQueue then
		return
	end

	-- Update speed and position.
	self.speedX, self.speedY = self.speedX + self.accelerationX * dt, self.speedY + self.accelerationY * dt
	self.x, self.y = self.x + self.speedX * dt, self.y + self.speedY * dt

	-- Update the lifespan.
	if self.lifetime then
		self.lifetime = self.lifetime - dt
		if self.lifetime <= 0 then
			self:destroy()
		end
	end

	-- Spawn particle pieces.
	if self.spawnNext then
		self.spawnNext = self.spawnNext - dt
		while self.spawnNext <= 0 and self.pieceCount < self.spawnMax do
			self:spawnPiece()
			self.spawnNext = self.spawnNext + self.spawnDelay
		end
	end

	-- Destroy when this spawner's owner is gone.
	if self.packet.delQueue then
		self:destroy()
	end
end

---Returns the current spawner's position.
---@return number, number
function ParticleSpawner:getPos()
	return self.x + self.packet.x, self.y + self.packet.y
end

---Returns the current spawner's position relative to its packet.
---@return number, number
function ParticleSpawner:getRelativePos()
	return self.x, self.y
end

---Draws the spawner's debug widgets.
function ParticleSpawner:draw()
	local x, y = self:getPos()
	love.graphics.setColor(1, 0, 0)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x - 10, y - 10, 20, 20)
end

---Spawns a new particle piece unless there is a maximum number of particles spawned by this spawner on the screen.
function ParticleSpawner:spawnPiece()
	if self.pieceCount >= self.spawnMax then
		return
	end
	self.manager:spawnParticlePiece(self, self.particleData)
end

---Flags this spawner as ready to be removed.
function ParticleSpawner:destroy()
	if self.delQueue then
		return
	end
	self.delQueue = true
	self.packet.spawnerCount = self.packet.spawnerCount - 1
end

return ParticleSpawner
