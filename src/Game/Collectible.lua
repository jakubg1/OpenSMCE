local class = require "com.class"

---Represents an item which can be collected by the Shooter, such as coins, powerups or gems.
---@class Collectible
---@overload fun(data, config, x, y):Collectible
local Collectible = class:derive("Collectible")

---Constructs a new Collectible.
---@param data table? If specified, data from this table will be used to load the entity state.
---@param config CollectibleConfig The config of this Collectible.
---@param x number The starting X position of this Collectible.
---@param y number The starting Y position of this Collectible.
function Collectible:new(data, config, x, y)
	if data then
		self:deserialize(data)
	else
		self.config = config
		self.x, self.y = x, y

		-- Read the speed and acceleration fields only when we're creating a brand new powerup.
		local speed = self.config.speed:evaluate()
		self.speedX, self.speedY = speed.x, speed.y
		local acceleration = self.config.acceleration:evaluate()
		self.accelerationX, self.accelerationY = acceleration.x, acceleration.y

		_Game:playSound(self.config.spawnSound, self.x, self.y)
	end

	self.particle = _Game:spawnParticle(self.config.particle, self.x, self.y)

	self.delQueue = false
end

---Updates this Collectible.
---@param dt number The delta time in seconds.
function Collectible:update(dt)
	-- speed and position
	self.speedX, self.speedY = self.speedX + self.accelerationX * dt, self.speedY + self.accelerationY * dt
	self.x, self.y = self.x + self.speedX * dt, self.y + self.speedY * dt

	-- catching/bouncing/destroying
	local byShooter = _Game.level.shooter:isPosCatchable(self.x, self.y)
	local byNet = _Game.level.netTime > 0 and self.y >= _Game.configManager.gameplay.net.posY
	if byShooter or byNet then
		self:catch()
	end
	if self.x < 10 then -- left
		self.x = 10
		self.speedX = -self.speedX
	elseif self.x > _Game:getNativeResolution().x - 10 then -- right
		self.x = _Game:getNativeResolution().x - 10
		self.speedX = -self.speedX
	elseif self.y < 10 then -- up
		self.y = 10
		self.speedY = -self.speedY
	elseif self.y > _Game:getNativeResolution().y + 20 then -- down - uncatched, falls down
		self:destroy()
		if self.config.dropEffects then
			for i, effect in ipairs(self.config.dropEffects) do
				_Game.level:applyEffect(effect, self.x, self.y)
			end
		end
	end

	-- sprite
	self.particle:setPos(self.x, self.y)
end

---Destroys this Collectible and activates its effects.
function Collectible:catch()
	self:destroy()

	if self.config.effects then
		for i, effect in ipairs(self.config.effects) do
			_Game.level:applyEffect(effect, self.x, self.y)
		end
	end

	_Game:playSound(self.config.pickupSound, self.x, self.y)
	_Game:spawnParticle(self.config.pickupParticle, self.x, self.y)
	if self.config.pickupName then
		_Game.level:spawnFloatingText(self.config.pickupName, self.x, self.y, self.config.pickupFont)
	end
end

---Removes this Collectible from the level.
function Collectible:destroy()
	if self.delQueue then
		return
	end
	self.delQueue = true
	self.particle:destroy()
end

---Why did I keep this function?
---Oh and by the way, Collectibles are drawn by the ParticleManager. Quirky, huh?
function Collectible:draw()
	-- *crickets*
end

---Serializes the Collectible's internal data for saving.
---@return table
function Collectible:serialize()
	return {
		id = _Game.resourceManager:getResourceReference(self.config),
		pos = {x = self.x, y = self.y},
		speed = {x = self.speedX, y = self.speedY},
		acceleration = {x = self.accelerationX, y = self.accelerationY}
	}
end

---Deserializes the Collectible's data, or in other words restores previously saved state.
---@param t table The data to be deserialized.
function Collectible:deserialize(t)
	self.config = _Game.resourceManager:getCollectibleConfig(t.id)
	self.x, self.y = t.pos.x, t.pos.y
	self.speedX, self.speedY = t.speed.x, t.speed.y
	self.accelerationX, self.accelerationY = t.acceleration.x, t.acceleration.y
end

return Collectible
