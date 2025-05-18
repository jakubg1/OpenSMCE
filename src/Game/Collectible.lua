local class = require "com.class"

---Represents an item which can be collected by the Shooter, such as coins, powerups or gems.
---@class Collectible
---@overload fun(deserializationTable, config, pos):Collectible
local Collectible = class:derive("Collectible")

local Vec2 = require("src.Essentials.Vector2")



---Constructs a new Collectible.
---@param deserializationTable table? If specified, data from this table will be used to load the entity state.
---@param config CollectibleConfig The config of this Collectible.
---@param pos Vector2 The starting position of this Collectible.
function Collectible:new(deserializationTable, config, pos)
	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.config = config
		self.pos = pos

		-- Read the speed and acceleration fields only when we're creating a brand new powerup.
		self.speed = self.config.speed:evaluate()
		self.acceleration = self.config.acceleration:evaluate()

		_Game:playSound(self.config.spawnSound, self.pos)
	end

	self.particle = _Game:spawnParticle(self.config.particle, self.pos)

	self.delQueue = false
end



---Updates this Collectible.
---@param dt number The delta time in seconds.
function Collectible:update(dt)
	-- speed and position
	self.speed = self.speed + self.acceleration * dt
	self.pos = self.pos + self.speed * dt

	-- catching/bouncing/destroying
	if _Game.level.shooter:isPosCatchable(self.pos) or (_Game.level.netTime > 0 and self.pos.y >= _Game.configManager.gameplay.net.posY) then
		self:catch()
	end
	if self.pos.x < 10 then -- left
		self.pos.x = 10
		self.speed.x = -self.speed.x
	elseif self.pos.x > _Game:getNativeResolution().x - 10 then -- right
		self.pos.x = _Game:getNativeResolution().x - 10
		self.speed.x = -self.speed.x
	elseif self.pos.y < 10 then -- up
		self.pos.y = 10
		self.speed.y = -self.speed.y
	elseif self.pos.y > _Game:getNativeResolution().y + 20 then -- down - uncatched, falls down
		self:destroy()
		if self.config.dropEffects then
			for i, effect in ipairs(self.config.dropEffects) do
				_Game.level:applyEffect(effect, self.pos)
			end
		end
	end

	-- sprite
	self.particle:setPos(self.pos.x, self.pos.y)
end



---Destroys this Collectible and activates its effects.
function Collectible:catch()
	self:destroy()

	if self.config.effects then
		for i, effect in ipairs(self.config.effects) do
			_Game.level:applyEffect(effect, self.pos)
		end
	end

	_Game:playSound(self.config.pickupSound, self.pos)
	_Game:spawnParticle(self.config.pickupParticle, self.pos)
	if self.config.pickupName then
		_Game.level:spawnFloatingText(self.config.pickupName, self.pos, self.config.pickupFont)
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
		pos = {x = self.pos.x, y = self.pos.y},
		speed = {x = self.speed.x, y = self.speed.y},
		acceleration = {x = self.acceleration.x, y = self.acceleration.y}
	}
end



---Deserializes the Collectible's data, or in other words restores previously saved state.
---@param t table The data to be deserialized.
function Collectible:deserialize(t)
	self.config = _Game.resourceManager:getCollectibleConfig(t.id)
	self.pos = Vec2(t.pos.x, t.pos.y)
	self.speed = Vec2(t.speed.x, t.speed.y)
	self.acceleration = Vec2(t.acceleration.x, t.acceleration.y)
end



return Collectible
