local class = require "com.class"

---@class ParticlePacket
---@overload fun(manager, data, x, y, layer):ParticlePacket
local ParticlePacket = class:derive("ParticlePacket")

---Constructs a particle effect. Particle packets spawn multiple particle spawners and do not move by themselves.
---@param manager ParticleManager The owner of this particle effect.
---@param data ParticleEffectConfig The config of this particle effect.
---@param x number The X position of the packet.
---@param y number The Y position of the packet.
---@param layer string Layer this particle packet and all its children (emitters, particle pieces) will be drawn on.
function ParticlePacket:new(manager, data, x, y, layer)
	self.manager = manager

	self.x, self.y = x, y
	self.layer = layer
	self.spawnerCount = 0
	for i, spawnerData in ipairs(data.emitters) do
		manager:spawnParticleSpawner(self, spawnerData)
	end

	self.delQueue = false
end

function ParticlePacket:update(dt)
	-- destroy when no more spawners and particles exist
	if self.spawnerCount == 0 and not self:hasPieces() then
		self:destroy()
	end
end

function ParticlePacket:draw()
	love.graphics.setColor(1, 1, 0)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", self.x, self.y, 15 + self.spawnerCount * 5)
end



---Returns the current packet's position.
---@return number, number
function ParticlePacket:getPos()
	return self.x, self.y
end

---Updates the current packet's position.
---@param x number The new X position.
---@param y number The new Y position.
function ParticlePacket:setPos(x, y)
	self.x, self.y = x, y
end

---Marks this packet as ready to be destroyed.
function ParticlePacket:destroy()
	if self.delQueue then
		return
	end
	self.delQueue = true
end

function ParticlePacket:clean()
	self.manager:cleanParticlePacket(self)
end

function ParticlePacket:setLayer(layer)
	self.layer = layer
	-- HACK: Move all spawners and pieces belonging to this Packet by iterating over all of them.
	self.manager:setParticlePacketLayer(self, layer)
end

function ParticlePacket:hasPieces()
	for i, piece in ipairs(self.manager.particlePieces) do
		if piece.packet == self then
			return true
		end
	end
	return false
end

return ParticlePacket