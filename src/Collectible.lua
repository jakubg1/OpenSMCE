local class = require "com/class"

---@class Collectible
---@overload fun(deserializationTable, pos, name):Collectible
local Collectible = class:derive("Collectible")

local Vec2 = require("src/Essentials/Vector2")



---Constructs a new Collectible.
---@param deserializationTable table? If specified, data from this table will be used to load the entity state.
---@param pos Vector2 The starting position of this Collectible.
---@param name string The collectible ID.
function Collectible:new(deserializationTable, pos, name)
	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.name = name
		self.pos = pos
		local beh = _Game.configManager.gameplay.collectibleBehaviour
		self.speed = _ParseVec2(beh.speed)
		self.acceleration = _ParseVec2(beh.acceleration)
	end

	self.config = _Game.configManager.collectibles[self.name]
	assert(self.config, string.format("Unknown powerup: \"%s\"", self.name))

	_Game:playSound(self.config.spawnSound, 1, self.pos)
	self.particle = _Game:spawnParticle(self.config.particle, self.pos)
end



---Updates this Collectible.
---@param dt number The delta time in seconds.
function Collectible:update(dt)
	-- speed and position
	self.speed = self.speed + self.acceleration * dt
	self.pos = self.pos + self.speed * dt

	-- catching/bouncing/destroying
	if _Game.session.level.shooter:isPosCatchable(self.pos) or (_Game.session.level.netTime > 0 and self.pos.y >= 550) then
		self:catch()
	end
	if self.pos.x < 10 then -- left
		self.pos.x = 10
		self.speed.x = -self.speed.x
	elseif self.pos.x > _NATIVE_RESOLUTION.x - 10 then -- right
		self.pos.x = _NATIVE_RESOLUTION.x - 10
		self.speed.x = -self.speed.x
	elseif self.pos.y < 10 then -- up
		self.pos.y = 10
		self.speed.y = -self.speed.y
	elseif self.pos.y > _NATIVE_RESOLUTION.y + 20 then -- down - uncatched, falls down
		self:destroy()
		if self.config.dropEffects then
			for i, effect in ipairs(self.config.dropEffects) do
				_Game.session.level:applyEffect(effect, self.pos)
			end
		end
	end

	-- sprite
	self.particle.pos = self.pos
end



---Destroys this Collectible and activates its effects.
function Collectible:catch()
	self:destroy()

	if self.config.effects then
		for i, effect in ipairs(self.config.effects) do
			_Game.session.level:applyEffect(effect, self.pos)
		end
	end

	_Game:playSound(self.config.pickupSound, 1, self.pos)
	_Game:spawnParticle(self.config.pickupParticle, self.pos)
	if self.config.pickupName then
		_Game.session.level:spawnFloatingText(self.config.pickupName, self.pos, self.config.pickupFont)
	end
end



---Removes this Collectible from the level.
function Collectible:destroy()
	if self._delQueue then
		return
	end
	self._list:destroy(self)
	self.particle:destroy()
end



---Why did I keep this function?
---Oh and by the way, Collectibles are drawn by ParticleManagers. Quirky, huh?
function Collectible:draw()
	-- *crickets*
end



---Serializes the Collectible's internal data for saving.
---@return table
function Collectible:serialize()
	return {
		name = self.name,
		pos = {x = self.pos.x, y = self.pos.y},
		speed = {x = self.speed.x, y = self.speed.y},
		acceleration = {x = self.acceleration.x, y = self.acceleration.y}
	}
end



---Deserializes the Collectible's data, or in other words restores previously saved state.
---@param t table The data to be deserialized.
function Collectible:deserialize(t)
	self.name = t.name
	self.pos = Vec2(t.pos.x, t.pos.y)
	self.speed = Vec2(t.speed.x, t.speed.y)
	self.acceleration = Vec2(t.acceleration.x, t.acceleration.y)
end



return Collectible
