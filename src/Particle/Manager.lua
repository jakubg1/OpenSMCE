local class = require "com.class"

---@class ParticleManager
---@overload fun():ParticleManager
local ParticleManager = class:derive("ParticleManager")

local ParticlePacket = require("src.Particle.Packet")
local ParticleSpawner = require("src.Particle.Spawner")
local ParticlePiece = require("src.Particle.Piece")



function ParticleManager:new()
	self.particlePackets = {}
	self.particleSpawners = {}
	self.particlePieces = {}
end

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
---@param layer string? UI layer on which the effect should be visible. If not specified, the effect will be rendered on top of everything.
---@return ParticlePacket
function ParticleManager:spawnParticlePacket(particleEffect, x, y, layer)
	local packet = ParticlePacket(self, particleEffect, x, y, layer)
	table.insert(self.particlePackets, packet)
	return packet
end

function ParticleManager:spawnParticleSpawner(packet, data)
	table.insert(self.particleSpawners, ParticleSpawner(self, packet, data))
end

function ParticleManager:spawnParticlePiece(spawner, data)
	table.insert(self.particlePieces, ParticlePiece(self, spawner, data))
end

function ParticleManager:cleanParticlePacket(particlePacket)
	for i = #self.particlePieces, 1, -1 do
		if self.particlePieces[i].packet == particlePacket then
			self.particlePieces[i]:destroy()
			table.remove(self.particlePieces, i)
		end
	end
end

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

function ParticleManager:getParticlePacketID(particlePacket)
	for i, particlePacketT in ipairs(self.particlePackets) do
		if particlePacket == particlePacketT then
			return i
		end
	end
end

function ParticleManager:getParticleSpawnerID(particleSpawner)
	for i, particleSpawnerT in ipairs(self.particleSpawners) do
		if particleSpawner == particleSpawnerT then
			return i
		end
	end
end

function ParticleManager:getParticlePieceID(particlePiece)
	for i, particlePieceT in ipairs(self.particlePieces) do
		if particlePiece == particlePieceT then
			return i
		end
	end
end

function ParticleManager:getParticlePacketCount()
	return #self.particlePackets
end

function ParticleManager:getParticleSpawnerCount()
	return #self.particleSpawners
end

function ParticleManager:getParticlePieceCount()
	return #self.particlePieces
end

function ParticleManager:clear()
	for i, particlePacket in ipairs(self.particlePackets) do
		particlePacket.delQueue = true
	end
	for i, particleSpawner in ipairs(self.particleSpawners) do
		particleSpawner.delQueue = true
	end
	self.particlePackets = {}
	self.particleSpawners = {}
end



function ParticleManager:draw(layer)
	for i, particlePiece in ipairs(self.particlePieces) do
		particlePiece:draw(layer)
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
