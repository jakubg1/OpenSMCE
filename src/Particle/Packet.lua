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
	local p = _PosOnScreen(self.pos)
	love.graphics.setColor(1, 1, 0)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", p.x, p.y, 15 + self.spawnerCount * 5)
end



function ParticlePacket:destroy()
	if self.delQueue then return end
	self.delQueue = true
	
	self.manager:destroyParticlePacket(self)
end

return ParticlePacket