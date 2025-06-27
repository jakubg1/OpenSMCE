local class = require "com.class"

---Represents an actual drawable form of Spheres.
---@class SphereEntity
---@overload fun(posX, posY, color, layer):SphereEntity
local SphereEntity = class:derive("SphereEntity")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")



---Constructs a new Sphere Entity.
---@param posX number The initial X coordinate of this Sphere Entity.
---@param posY number The initial Y coordinate of this Sphere Entity.
---@param color integer The initial sphere color.
---@param layer string? The layer on which the sphere's idle particles should appear. If not specified, they will be drawn in the main pass of the Particle Manager, i.e. on top of everything.
function SphereEntity:new(posX, posY, color, layer)
	self.posX, self.posY = posX, posY
	self.angle = 0
	self.scaleX = 1
	self.scaleY = 1
	self.roll = nil
	self.colorM = Color()
	self.color = color
	self.alpha = 1
	self.layer = layer

	self.config = _Game.resourceManager:getSphereConfig("spheres/sphere_" .. color .. ".json")
	self.rollOffsets = self:generateSpriteRollOffsets()
	self.particle = self.config.idleParticle and _Game:spawnParticle(self.config.idleParticle, posX, posY, layer)
end



---Moves the sphere entity to a given location.
---@param posX number The new X coordinate of this Sphere Entity.
---@param posY number The new Y coordinate of this Sphere Entity.
function SphereEntity:setPos(posX, posY)
	self.posX, self.posY = posX, posY
	if self.particle then
		self.particle:setPos(posX, posY)
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
	self.scaleX, self.scaleY = scale, scale
end



---Sets the roll offset for this Sphere Entity. This affects the displayed frame for the sprites which have a rolling speed set.
---@param roll number? The roll offset of this Sphere Entity. If `nil`, the roll offset will be reset, which means that the random frame offset for the roll animation will not be applied.
function SphereEntity:setRoll(roll)
	self.roll = roll
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
	self.rollOffsets = self:generateSpriteRollOffsets()

	-- Particle stuff
	if self.particle then
		self.particle:destroy()
		self.particle = nil
	end
	if self.config.idleParticle then
		self.particle = _Game:spawnParticle(self.config.idleParticle, self.posX, self.posY, self.layer)
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



---Randomizes the frame offsets for the rolling animation, for each sprite separately.
---The result should be stored in the `self.rollOffsets` field.
---@return table
function SphereEntity:generateSpriteRollOffsets()
	local offsets = {}
	for i, sprite in ipairs(self.config.sprites) do
		local frameCount = sprite.sprite.states[1].frameCount
		offsets[i] = math.random() * frameCount
	end
	return offsets
end



---Returns the config of this Sphere Entity.
---@return table
function SphereEntity:getConfig()
	return self.config
end



---Returns a new instance of itself.
---@return SphereEntity
function SphereEntity:copy()
	local entity = SphereEntity(self.posX, self.posY, self.color, self.layer)
	entity.angle = self.angle
	entity.scaleX, entity.scaleY = self.scaleX, self.scaleY
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
		_Game:spawnParticle(self.config.destroyParticle, self.posX, self.posY, self.layer)
	end
end



---Returns the currently displayed frame for this Sphere Entity's `i`-th sprite.
---@param i integer The sprite index.
---@return integer
function SphereEntity:getFrame(i)
	local sprite = self.config.sprites[i]
	local frame = 1
	local frameCount = sprite.sprite.states[1].frameCount
	if sprite.animationSpeed then
		frame = sprite.animationSpeed * _TotalTime
	elseif self.roll then
		frame = sprite.rollingSpeed * -self.roll + self.rollOffsets[i]
	end
	return math.floor(frame) % frameCount
end



---Returns the angle at which this Sphere Entity's `i`-th sprite should be currently displayed 
---@param i integer The sprite index.
---@return number
function SphereEntity:getAngle(i)
	local sprite = self.config.sprites[i]
	return sprite.rotate and self.angle or 0
end



---Draws this Sphere Entity on the screen.
---@param shadow boolean? If set to `true`, the shadow of this entity will be drawn instead of the sphere itself.
function SphereEntity:draw(shadow)
	if shadow then
		if self.config.shadowSprite then
			self.config.shadowSprite:draw(self.posX + self.config.shadowOffset.x, self.posY + self.config.shadowOffset.y, 0.5, 0.5, nil, nil, self.angle, nil, self.alpha, self.scaleX, self.scaleY)
		end
	else
		for i, sprite in ipairs(self.config.sprites) do
			local conditionsPassed = true
			if sprite.conditions then
				for j, condition in ipairs(sprite.conditions) do
					if not condition:evaluate() then
						conditionsPassed = false
						break
					end
				end
			end
			if conditionsPassed then
				sprite.sprite:draw(self.posX, self.posY, 0.5, 0.5, nil, self:getFrame(i), self:getAngle(i), self.colorM, self.alpha, self.scaleX, self.scaleY)
			end
		end
	end
end



return SphereEntity
