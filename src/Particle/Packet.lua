local class = require "com/class"
local ParticlePacket = class:derive("ParticlePacket")

function ParticlePacket:new(manager, data, pos)
	self.manager = manager
	
	self.pos = pos
	self.spawnerCount = 0
	for spawnerN, spawnerData in pairs(data) do
		manager:spawnParticleSpawner(spawnerData, pos)
	end
	
	self.delQueue = false
end

function ParticlePacket:update(dt)
end

function ParticlePacket:draw()
	local p = posOnScreen(self.pos)
	love.graphics.setColor(1, 1, 0)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", p.x, p.y, 15)
end



function ParticlePacket:destroy()
	if self.delQueue then return end
	self.delQueue = true
	
	self.manager:destroyParticlePacket(self)
end

return ParticlePacket