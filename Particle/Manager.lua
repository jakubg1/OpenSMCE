local class = require "class"
local ParticleManager = class:derive("ParticleManager")

local ParticleSpawner = require("Particle/Spawner")
local ParticlePiece = require("Particle/Piece")

function ParticleManager:new()
	self.particleSpawners = {}
	self.particlePieces = {}
end

function ParticleManager:update(dt)
	for i, particleSpawner in ipairs(self.particleSpawners) do
		particleSpawner:update(dt)
	end
	for i, particlePiece in ipairs(self.particlePieces) do
		particlePiece:update(dt)
	end
end

function ParticleManager:useSpawnerData(path, pos)
	local particleSpawnerData = game.resourceBank:getParticle(path)
	for spawnerN, spawnerData in pairs(particleSpawnerData) do
		self:spawnParticleSpawner(spawnerData, pos)
	end
end

function ParticleManager:spawnParticleSpawner(data, pos)
	table.insert(self.particleSpawners, ParticleSpawner(self, data, pos))
end

function ParticleManager:spawnParticlePiece(data, pos)
	table.insert(self.particlePieces, ParticlePiece(self, data, pos))
end

function ParticleManager:destroyParticleSpawner(particleSpawner)
	table.remove(self.particleSpawners, self:getParticleSpawnerID(particleSpawner))
end

function ParticleManager:destroyParticlePiece(particlePiece)
	table.remove(self.particlePieces, self:getParticlePieceID(particlePiece))
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

function ParticleManager:getParticleSpawnerCount()
	return #self.particleSpawners
end

function ParticleManager:getParticlePieceCount()
	return #self.particlePieces
end



function ParticleManager:draw()
	for i, particlePiece in ipairs(self.particlePieces) do
		particlePiece:draw()
	end
	if particleSpawnersVisible then
		for i, particleSpawner in ipairs(self.particleSpawners) do
			particleSpawner:draw()
		end
	end
end

return ParticleManager