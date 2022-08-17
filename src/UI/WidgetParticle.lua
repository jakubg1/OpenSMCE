local class = require "com/class"

---@class UIWidgetParticle
---@overload fun(parent, path):UIWidgetParticle
local UIWidgetParticle = class:derive("UIWidgetParticle")

local Vec2 = require("src/Essentials/Vector2")
local ParticleManager = require("src/Particle/Manager")



function UIWidgetParticle:new(parent, path)
	self.type = "particle"

	self.parent = parent
	self.path = path

	self.manager = ParticleManager()
	self.packet = nil
end

function UIWidgetParticle:update(dt)
	self.manager:update(dt)
	if self.packet then
		self.packet.pos = self.parent:getPos()
		if self.packet.delQueue then
			self.packet = nil
			self.parent:executeAction("particleDespawn")
		end
	end
end

function UIWidgetParticle:spawn()
	self.packet = self.manager:spawnParticlePacket(self.path, self.parent:getPos())
end

function UIWidgetParticle:despawn()
	self.manager:clear()
end



function UIWidgetParticle:draw()
	self.manager:draw()
end

return UIWidgetParticle
