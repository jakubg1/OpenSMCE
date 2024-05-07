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
end

function ParticleManager:spawnParticlePacket(path, pos, layer)
	-- TODO: Unmangle this code. Will the string representation be still needed after we fully move to Config Classes?
	local data
	if type(path) == "string" then
		data = _Game.resourceManager:getParticle(path)
	else
		data = path
	end
	local packet = ParticlePacket(self, data, pos, layer)
	table.insert(self.particlePackets, packet)
	return packet
end

function ParticleManager:spawnParticleSpawner(packet, data)
	table.insert(self.particleSpawners, ParticleSpawner(self, packet, data))
end

function ParticleManager:spawnParticlePiece(spawner, data)
	table.insert(self.particlePieces, ParticlePiece(self, spawner, data))
end

function ParticleManager:destroyParticlePacket(particlePacket)
	table.remove(self.particlePackets, self:getParticlePacketID(particlePacket))
end

function ParticleManager:destroyParticleSpawner(particleSpawner)
	table.remove(self.particleSpawners, self:getParticleSpawnerID(particleSpawner))
end

function ParticleManager:destroyParticlePiece(particlePiece)
	table.remove(self.particlePieces, self:getParticlePieceID(particlePiece))
end

function ParticleManager:getParticlePacketID(particlePacket)
	for i, particlePacketT in ipairs(self.particlePackets) do
		if particlePacket == particlePacketT then return i end
	end
end

function ParticleManager:getParticleSpawnerID(particleSpawner)
	for i, particleSpawnerT in ipairs(self.particleSpawners) do
		if particleSpawner == particleSpawnerT then return i end
	end
end

function ParticleManager:getParticlePieceID(particlePiece)
	for i, particlePieceT in ipairs(self.particlePieces) do
		if particlePiece == particlePieceT then return i end
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
	if _Debug.particleSpawnersVisible then
		for i, particlePacket in ipairs(self.particlePackets) do
			particlePacket:draw()
		end
		for i, particleSpawner in ipairs(self.particleSpawners) do
			particleSpawner:draw()
		end
	end
end

return ParticleManager
