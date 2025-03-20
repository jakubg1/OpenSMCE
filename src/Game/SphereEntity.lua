local class = require "com.class"

---Represents an actual drawable form of Spheres.
---@class SphereEntity
---@overload fun(pos, color, layer):SphereEntity
local SphereEntity = class:derive("SphereEntity")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")



---Constructs a new Sphere Entity.
---@param pos Vector2 The initial position of this Sphere Entity.
---@param color integer The initial sphere color.
---@param layer string? The layer on which the sphere's idle particles should appear. If not specified, they will be drawn in the main pass of the Particle Manager, i.e. on top of everything.
function SphereEntity:new(pos, color, layer)
	self.pos = pos
	self.angle = 0
	self.scale = Vec2(1)
	self.frame = 1
	self.colorM = Color()
	self.color = color
	self.alpha = 1
	self.layer = layer

	self.config = _Game.resourceManager:getSphereConfig("spheres/sphere_" .. color .. ".json")
	self.particle = self.config.idleParticle and _Game:spawnParticle(self.config.idleParticle, pos, layer)
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



---Sets the size of the sphere entity. 1 is natural size.
---@param scale number The new scale.
function SphereEntity:setScale(scale)
	self.scale = Vec2(scale)
end



---Sets the frame of this sphere entity to be displayed.
---@param frame integer The animation frame of this Sphere Entity's sprite.
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
	self.config = _Game.resourceManager:getSphereConfig("spheres/sphere_" .. color .. ".json")

	-- Particle stuff
	if self.particle then
		self.particle:destroy()
		self.particle = nil
	end
	if self.config.idleParticle then
		self.particle = _Game:spawnParticle(self.config.idleParticle, self.pos, self.layer)
	end
end



---Sets the alpha of this sphere entity. This does not affect any particles attached to it.
---@param alpha number The transparency of this entity, from `0` (fully invisible) to `1` (fully visible).
function SphereEntity:setAlpha(alpha)
	self.alpha = alpha
end



---Moves the idle particle effect of this sphere entity to the provided layer.
---@param layer string The new layer name.
function SphereEntity:setLayer(layer)
	self.layer = layer
	if self.particle then
		self.particle:setLayer(layer)
	end
end



---Returns the config of this Sphere Entity.
---@return table
function SphereEntity:getConfig()
	return self.config
end



---Returns a new instance of itself.
---@return SphereEntity
function SphereEntity:copy()
	local entity = SphereEntity(self.pos, self.color, self.layer)
	entity.angle = self.angle
	entity.scale = self.scale
	entity.frame = self.frame
	entity.colorM = self.colorM
	entity.alpha = self.alpha
	return entity
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
		_Game:spawnParticle(self.config.destroyParticle, self.pos, self.layer)
	end
end



---Draws this Sphere Entity on the screen.
---@param shadow boolean? If set to `true`, the shadow of this entity will be drawn instead of the sphere itself.
function SphereEntity:draw(shadow)
	if shadow then
		self.config.shadowSprite:draw(self.pos + self.config.shadowOffset, Vec2(0.5), nil, nil, self.angle, nil, self.alpha, self.scale)
	else
		self.config.sprite:draw(self.pos, Vec2(0.5), nil, self.frame, self.angle, self.colorM, self.alpha, self.scale)
	end
end



return SphereEntity
