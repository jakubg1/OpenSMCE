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
	---@type ParticlePiece[]
	self.pieces = {} -- Stores references to all Particle Pieces spawned by this Spawner. These pieces are also stored by the Particle Manager itself and should be accessed from there!
	self.spawnDelay = data.spawnDelay
	self.particleData = data.particleData

	self.spawnNext = self.spawnDelay

	for i = 1, data.spawnCount do
		self:spawnPiece()
	end

	self.deactivated = false
	self.delQueue = false
end

---Updates this particle spawner.
---@param dt number Time delta in seconds.
function ParticleSpawner:update(dt)
	-- Sorry! You DIED!
	if self.delQueue then
		return
	end

	-- Remove all dead particles.
	_Utils.removeDeadObjects(self.pieces)

	-- Destroy itself when there are no more particles spawned by this Spawner around.
	if self.deactivated and #self.pieces == 0 then
		self:destroy()
	end

	-- Do not proceed if we're deactivated.
	if self.deactivated then
		return
	end

	-- Update speed and position.
	self.speedX, self.speedY = self.speedX + self.accelerationX * dt, self.speedY + self.accelerationY * dt
	self.x, self.y = self.x + self.speedX * dt, self.y + self.speedY * dt

	-- Update the lifespan.
	if self.lifetime then
		self.lifetime = self.lifetime - dt
		if self.lifetime <= 0 then
			self:deactivate()
		end
	end

	-- Spawn particle pieces.
	if self.spawnNext then
		self.spawnNext = self.spawnNext - dt
		while self.spawnNext <= 0 and #self.pieces < self.spawnMax do
			self:spawnPiece()
			self.spawnNext = self.spawnNext + self.spawnDelay
		end
	end

	-- Deactivate itself when this spawner's owner is gone.
	if self.packet.delQueue then
		self:deactivate()
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
	if #self.pieces >= self.spawnMax then
		return
	end
	local particle = self.manager:spawnParticlePiece(self, self.particleData)
	table.insert(self.pieces, 1, particle)
end

---Deactivates this Particle Spawner, which means it will no longer spawn any more particles.
---The Spawner will not be deleted from the Particle Manager, because Particles are tied to Spawners and use them to determine the drawing order.
function ParticleSpawner:deactivate()
	self.deactivated = true
end

---Flags this spawner as ready to be removed and destroys all Particles this Spawner has spawned.
function ParticleSpawner:destroy()
	if self.delQueue then
		return
	end
	self.delQueue = true
	self.packet.spawnerCount = self.packet.spawnerCount - 1
	for i, piece in ipairs(self.pieces) do
		piece:destroy()
	end
end

return ParticleSpawner
