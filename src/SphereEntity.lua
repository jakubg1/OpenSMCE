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

	self.config = _Game.configManager.spheres[color]

	self.shadowSprite = _Game.resourceManager:getSprite(self.config.shadowSprite or "sprites/game/ball_shadow.json")
	self.sprite = _Game.resourceManager:getSprite(self.config.sprite)
	self.particle = self.config.idleParticle and _Game:spawnParticle(self.config.idleParticle, pos)
end



function SphereEntity:setPos(pos)
	self.pos = pos
	if self.particle then
		self.particle.pos = pos
	end
end

function SphereEntity:setColor(color)
	self.color = color
	self.config = _Game.configManager.spheres[color]
	self.sprite = _Game.resourceManager:getSprite(self.config.sprite)

	-- Particle stuff
	if self.particle then
		self.particle:destroy()
		self.particle = nil
	end
	if self.config.idleParticle then
		self.particle = _Game:spawnParticle(self.config.idleParticle, self.pos)
	end
end

function SphereEntity:destroy(spawnParticle)
	if spawnParticle == nil then
		spawnParticle = true
	end
	if self.particle then
		self.particle:destroy()
		self.particle = nil
	end
	if spawnParticle and self.config.destroyParticle then
		_Game:spawnParticle(self.config.destroyParticle, self.pos)
	end
end



function SphereEntity:draw(shadow)
	if shadow then
		self.shadowSprite:draw(self.pos + Vec2(4), Vec2(0.5))
	else
		self.sprite:draw(self.pos, Vec2(0.5), nil, self.frame, self.angle, self.colorM)
	end
end



return SphereEntity
