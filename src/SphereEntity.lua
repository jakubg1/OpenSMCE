local class = require "com.class"

---@class SphereEntity
---@overload fun(pos, color):SphereEntity
local SphereEntity = class:derive("SphereEntity")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")



---Constructs a new Sphere Entity.
---@param pos Vector2 The initial position of this Sphere Entity.
---@param color integer The initial sphere color.
function SphereEntity:new(pos, color)
	self.pos = pos
	self.angle = 0
	self.frame = Vec2(1)
	self.colorM = Color()
	self.color = color

	self.config = _Game.configManager.spheres[color]

	self.shadowSprite = _Game.resourceManager:getSprite(self.config.shadowSprite or "sprites/game/ball_shadow.json")
	self.sprite = _Game.resourceManager:getSprite(self.config.sprite)
	self.particle = self.config.idleParticle and _Game:spawnParticle(self.config.idleParticle, pos)
end



---Moves the sphere entity to a given location.
---@param pos Vector2 The new position of this Sphere Entity.
function SphereEntity:setPos(pos)
	self.pos = pos
	if self.particle then
		self.particle.pos = pos
	end
end



---Rotates the sphere entity to a given angle.
---@param angle number The angle in radians.
function SphereEntity:setAngle(angle)
	self.angle = angle
end



---Sets the frame of this sphere entity to be displayed.
---@param frame Vector2 The animation frame of this Sphere Entity's sprite.
function SphereEntity:setFrame(frame)
	self.frame = frame
end



---Sets the color modifier of this sphere entity. The color modifier will tint this entity with a given color.
---@param colorM Color The color modifier to be applied.
function SphereEntity:setColorM(colorM)
	self.colorM = colorM
end



---Changes the sphere color of this sphere entity.
---@param color integer The color to be changed to.
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



---Destroys this sphere entity.
---@param spawnParticle boolean? Whether to emit sphere destruction particles. Defaults to `true`.
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



---Draws this Sphere Entity on the screen.
---@param shadow boolean? If set to `true`, the shadow of this entity will be drawn instead of the sphere itself.
function SphereEntity:draw(shadow)
	if shadow then
		self.shadowSprite:draw(self.pos + Vec2(4), Vec2(0.5))
	else
		self.sprite:draw(self.pos, Vec2(0.5), nil, self.frame, self.angle, self.colorM)
	end
end



return SphereEntity
