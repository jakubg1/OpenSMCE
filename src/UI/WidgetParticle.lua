local class = require "com.class"

---@class UIWidgetParticle
---@overload fun(parent, path):UIWidgetParticle
local UIWidgetParticle = class:derive("UIWidgetParticle")



function UIWidgetParticle:new(parent, path)
	self.type = "particle"

	self.parent = parent
	self.path = path

	self.packet = nil
	self.debugColor = {0.0, 1.0, 1.0}
end

function UIWidgetParticle:update(dt)
	if self.packet then
		self.packet.pos = self.parent:getPos()
		if self.packet.delQueue then
			self.packet = nil
			self.parent:executeAction("particleDespawn")
		end
	end
end

function UIWidgetParticle:spawn()
	self.packet = _Game:spawnParticle(self.path, self.parent:getPos(), self.parent.layer)
end

function UIWidgetParticle:despawn()
	if self.packet then
		self.packet:destroy()
	end
end

function UIWidgetParticle:clean()
	if self.packet then
		self.packet:clean()
	end
end



function UIWidgetParticle:draw()
end

return UIWidgetParticle
