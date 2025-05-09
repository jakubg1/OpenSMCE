local class = require "com.class"

---@class ParticlePacket
---@overload fun(manager, data, pos, layer):ParticlePacket
local ParticlePacket = class:derive("ParticlePacket")



function ParticlePacket:new(manager, data, pos, layer)
	self.manager = manager
	
	self.pos = pos
	self.layer = layer
	self.spawnerCount = 0
	for i, spawnerData in ipairs(data.emitters) do
		manager:spawnParticleSpawner(self, spawnerData)
	end
	
	self.delQueue = false
end

function ParticlePacket:update(dt)
	-- destroy when no more spawners exist
	if self.spawnerCount == 0 then
		self:destroy()
	end
end

function ParticlePacket:draw()
	love.graphics.setColor(1, 1, 0)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", self.pos.x, self.pos.y, 15 + self.spawnerCount * 5)
end



function ParticlePacket:destroy()
	if self.delQueue then return end
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

return ParticlePacket