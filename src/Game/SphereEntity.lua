local class = require "com.class"
local Color = require("src.Essentials.Color")

---Represents an actual drawable form of Spheres.
---@class SphereEntity
---@overload fun(x: number, y: number, color: integer):SphereEntity
local SphereEntity = class:derive("SphereEntity")

---Constructs a new Sphere Entity.
---@param x number The initial X coordinate of this Sphere Entity.
---@param y number The initial Y coordinate of this Sphere Entity.
---@param color integer The initial sphere color.
function SphereEntity:new(x, y, color)
	self.x, self.y = x, y
	self.angle = 0
	self.scaleX, self.scaleY = 1, 1
	self.roll = nil
	self.state = "normal"
	self.colorM = Color()
	self.color = color
	self.alpha = 1

	self.config = _Res:getSphereConfig("spheres/sphere_" .. color .. ".json")
	self.rollOffsets = self:generateSpriteRollOffsets()
	self.particle = self.config.idleParticle and _Game:spawnParticle(self.config.idleParticle, x, y, self:getIdleParticleLayer())
end

---Moves the sphere entity to a given location.
---@param x number The new X coordinate of this Sphere Entity.
---@param y number The new Y coordinate of this Sphere Entity.
function SphereEntity:setPos(x, y)
	self.x, self.y = x, y
	if self.particle then
		self.particle:setPos(x, y)
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

---Sets the state for this Sphere Entity. If set, this Sphere Entity will be rendered on a different layer.
---@param state string The new state for this Sphere Entity.
function SphereEntity:setState(state)
	self.state = state
	if self.particle then
		self.particle:setLayer(self:getIdleParticleLayer())
	end
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
	self.config = _Res:getSphereConfig("spheres/sphere_" .. color .. ".json")
	self.rollOffsets = self:generateSpriteRollOffsets()

	-- Particle stuff
	if self.particle then
		self.particle:destroy()
		self.particle = nil
	end
	if self.config.idleParticle then
		self.particle = _Game:spawnParticle(self.config.idleParticle, self.x, self.y, self:getIdleParticleLayer())
	end
end

---Sets the alpha of this sphere entity. This does not affect any particles attached to it.
---@param alpha number The transparency of this entity, from `0` (fully invisible) to `1` (fully visible).
function SphereEntity:setAlpha(alpha)
	self.alpha = alpha
end

---Returns a new instance of itself.
---@return SphereEntity
function SphereEntity:copy()
	local entity = SphereEntity(self.x, self.y, self.color)
	entity.angle = self.angle
	entity.scaleX, entity.scaleY = self.scaleX, self.scaleY
	entity.state = self.state
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
		_Game:spawnParticle(self.config.destroyParticle, self.x, self.y, self.config.destroyParticleLayer)
	end
end

---Returns the config of this Sphere Entity.
---@return table
function SphereEntity:getConfig()
	return self.config
end

---Returns the currently displayed frame for this Sphere Entity's `i`-th sprite.
---@private
---@param i integer The sprite index.
---@return integer
function SphereEntity:getFrame(i)
	local sprite = self.config.sprites[i]
	local frame = 1
	local frameCount = sprite.sprite.states[1].frameCount
	if sprite.animationSpeed then
		frame = sprite.animationSpeed * _TotalTime
	elseif self.roll then
		if sprite.rollingSpeed then
			frame = sprite.rollingSpeed * -self.roll + self.rollOffsets[i]
		else
			frame = sprite.rollingMultiplier * -self.roll / (self.config.size * math.pi) * frameCount
		end
	end
	return math.floor(frame) % frameCount
end

---Returns the angle at which this Sphere Entity's `i`-th sprite should be currently displayed.
---@private
---@param i integer The sprite index.
---@return number
function SphereEntity:getAngle(i)
	local sprite = self.config.sprites[i]
	return sprite.rotate and self.angle or 0
end

---Returns the scale with which this Sphere Entity's `i`-th sprite should be currently displayed.
---@private
---@param i integer The sprite index.
---@return number
function SphereEntity:getScale(i)
	local sprite = self.config.sprites[i]
	return sprite.resize and self.config.size / sprite.sprite.config.frameSize.x or 1
end

---Returns the layer on which this Sphere Entity's `i`-th sprite should be currently displayed.
---@private
---@param i integer The sprite index.
---@return string
function SphereEntity:getLayer(i)
	if self.state == "hidden" then
		return self.config.sprites[i].hiddenLayer
	elseif self.state == "shooter" then
		return self.config.sprites[i].shooterLayer
	elseif self.state == "shot" then
		return self.config.sprites[i].shotLayer
	end
	return self.config.sprites[i].layer
end

---Returns the layer on which this Sphere Entity's idle particle should be rendered on.
---@private
---@return string
function SphereEntity:getIdleParticleLayer()
	if self.state == "hidden" then
		return self.config.idleParticleHiddenLayer
	elseif self.state == "shooter" then
		return self.config.idleParticleShooterLayer
	elseif self.state == "shot" then
		return self.config.idleParticleShotLayer
	end
	return self.config.idleParticleLayer
end

---Randomizes the frame offsets for the rolling animation, for each sprite separately.
---The result should be stored in the `self.rollOffsets` field.
---@private
---@return table
function SphereEntity:generateSpriteRollOffsets()
	local offsets = {}
	for i, sprite in ipairs(self.config.sprites) do
		local frameCount = sprite.sprite.states[1].frameCount
		offsets[i] = math.random() * frameCount
	end
	return offsets
end

---Draws this Sphere Entity on the screen.
function SphereEntity:draw()
	for i, sprite in ipairs(self.config.sprites) do
		if _Utils.checkExpressions(sprite.conditions) then
			_Renderer:setLayer(self:getLayer(i))
			local x, y = self.x + sprite.offset.x, self.y + sprite.offset.y
			local ox, oy = sprite.anchor.x, sprite.anchor.y
			local s = self:getScale(i)
			sprite.sprite:draw(x, y, ox, oy, nil, self:getFrame(i), self:getAngle(i), self.colorM, self.alpha, s * self.scaleX, s * self.scaleY)
		end
	end
end

return SphereEntity
