local class = require "com/class"
local SphereEntity = class:derive("SphereEntity")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")

function SphereEntity:new(pos, color)
	self.color = color
	self.pos = pos
	self.angle = 0
	self.frame = 0
	self.colorM = Color()
	
	self.config = game.spheres[color]
	
	self.shadowImage = game.resourceBank:getImage("img/game/ball_shadow.png")
	self.image = game.resourceBank:getImage(self.config.image)
	self.particle = self.config.idleParticle and game:spawnParticle(self.config.idleParticle, pos)
end



function SphereEntity:setPos(pos)
	self.pos = pos
	if self.particle then
		self.particle.pos = pos
	end
end

function SphereEntity:setColor(color)
	self.color = color
	self.config = game.spheres[color]
	self.image = game.resourceBank:getImage(self.config.image)
	
	-- Particle stuff
	if self.particle then
		self.particle:destroy()
		self.particle = nil
	end
	if self.config.idleParticle then
		self.particle = game:spawnParticle(self.config.idleParticle, self.pos)
	end
end

function SphereEntity:destroy(spawnParticle)
	if spawnParticle == nil then spawnParticle = true end
	if self.particle then
		self.particle:destroy()
		self.particle = nil
	end
	if spawnParticle and self.config.destroyParticle then game:spawnParticle(self.config.destroyParticle, self.pos) end
end



function SphereEntity:draw(shadow)
	if shadow then
		self.shadowImage:draw(self.pos + Vec2(4), Vec2(0.5))
	else
		self.image:draw(self.pos, Vec2(0.5), self.frame, self.angle, self.colorM)
	end
end



return SphereEntity