local class = require "com/class"
local ParticlePacket = class:derive("ParticlePacket")

function ParticlePacket:new(manager, data, pos)
	self.manager = manager
	
	self.pos = pos
	self.spawnerCount = 0
	for i, spawnerData in ipairs(data) do
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