local class = require "com.class"
local ParticlePacket = require("src.Particle.Packet")
local ParticleSpawner = require("src.Particle.Spawner")
local ParticlePiece = require("src.Particle.Piece")

---Particle Manager handles the particle system.
---It is the place where the particle packets (effects), spawners (emitters) and pieces (particles) are contained.
---Allows the orphaned Particles to still exist, update and draw themselves.
---@class ParticleManager
---@overload fun():ParticleManager
local ParticleManager = class:derive("ParticleManager")

---Creates a new Particle Manager.
function ParticleManager:new()
	---@type ParticlePacket[]
	self.particlePackets = {}
	---@type ParticleSpawner[]
	self.particleSpawners = {}
	---@type ParticlePiece[]
	self.particlePieces = {}
end

---Updates the Particle Manager.
---@param dt number Time delta in seconds.
function ParticleManager:update(dt)
	for i, particlePacket in ipairs(self.particlePackets) do
		particlePacket:update(dt)
	end
	for i, particleSpawner in ipairs(self.particleSpawners) do
		particleSpawner:update(dt)
	end
	for i, particlePiece in ipairs(self.particlePieces) do
		particlePiece:update(dt)
	end

	-- Clean dead particles.
	_Utils.removeDeadObjects(self.particlePackets)
	_Utils.removeDeadObjects(self.particleSpawners)
	_Utils.removeDeadObjects(self.particlePieces)
end

---Spawns a new Particle Packet (Effect) and returns a handle to it.
---@param particleEffect ParticleEffectConfig Particle Effect to be spawned.
---@param x number Initial X position of the effect.
---@param y number Initial Y position of the effect.
---@param layer string UI layer on which the effect should be visible.
---@return ParticlePacket
function ParticleManager:spawnParticlePacket(particleEffect, x, y, layer)
	local packet = ParticlePacket(self, particleEffect, x, y, layer)
	table.insert(self.particlePackets, packet)
	return packet
end

---Spawns a new Particle Emitter (Spawner) in the Particle Manager.
---@param packet ParticlePacket The Particle Effect this Particle Spawner comes from.
---@param data ParticleEmitterConfig Particle emitter data.
function ParticleManager:spawnParticleSpawner(packet, data)
	table.insert(self.particleSpawners, ParticleSpawner(self, packet, data))
end

---Spawns a new Particle in the Particle Manager.
---@param spawner ParticleSpawner The Particle Spawner this Particle comes from.
---@param data ParticleConfig Particle data.
function ParticleManager:spawnParticlePiece(spawner, data)
	table.insert(self.particlePieces, ParticlePiece(self, spawner, data))
end

---Destroys all Emitters and Particles belonging to the specified Particle Effect.
---@param particlePacket ParticlePacket The Particle Effect to destroy the Emitters and Particles for.
function ParticleManager:cleanParticlePacket(particlePacket)
	for i, spawner in ipairs(self.particleSpawners) do
		if spawner.packet == particlePacket then
			spawner:destroy()
		end
	end
	for i, piece in ipairs(self.particlePieces) do
		if piece.packet == particlePacket then
			piece:destroy()
		end
	end
end

---Changes the layer of all Emitters and Particles belonging to the specified Particle Effect.
---@param particlePacket ParticlePacket The Particle Effect to change the layer for.
---@param layer string The layer the effect should be moved to.
function ParticleManager:setParticlePacketLayer(particlePacket, layer)
	for i, particleSpawner in ipairs(self.particleSpawners) do
		if particleSpawner.packet == particlePacket then
			particleSpawner.layer = layer
		end
	end
	for i, particlePiece in ipairs(self.particlePieces) do
		if particlePiece.packet == particlePacket then
			particlePiece.layer = layer
		end
	end
end

---Returns the amount of active effects in this Particle Manager.
---@return integer
function ParticleManager:getParticlePacketCount()
	return #self.particlePackets
end

---Returns the amount of emitters in this Particle Manager.
---@return integer
function ParticleManager:getParticleSpawnerCount()
	return #self.particleSpawners
end

---Returns the amount of particles in this Particle Manager.
---@return integer
function ParticleManager:getParticlePieceCount()
	return #self.particlePieces
end

---Removes all Particle Effects, Particle Emitters and Particles from this Particle Manager.
function ParticleManager:clear()
	-- Mark all Particle Packets as destroyed to signal any users that their particle effects are now gone.
	for i, particlePacket in ipairs(self.particlePackets) do
		particlePacket:destroy()
	end
	_Utils.emptyTable(self.particlePackets)
	_Utils.emptyTable(self.particleSpawners)
	_Utils.emptyTable(self.particlePieces)
end

---Draws the Particles on the screen.
---If the debug flag is set, also draws the debug information about Particle Effects and Emitters.
function ParticleManager:draw()
	for i, particlePiece in ipairs(self.particlePieces) do
		particlePiece:draw()
	end
	if _Debug.gameDebugVisible then
		for i, particlePacket in ipairs(self.particlePackets) do
			particlePacket:draw()
		end
		for i, particleSpawner in ipairs(self.particleSpawners) do
			particleSpawner:draw()
		end
	end
end

return ParticleManager
