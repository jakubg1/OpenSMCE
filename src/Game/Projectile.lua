local class = require "com.class"

---Represents a Projectile which is moving towards its target, destroying spheres based on its Sphere Selector.
---@class Projectile
---@overload fun(deserializationTable, config, targetSphere):Projectile
local Projectile = class:derive("Projectile")

local Vec2 = require("src.Essentials.Vector2")

---Constructs a new Projectile.
---@param deserializationTable table? If specified, data from this table will be used to load the entity state.
---@param config ProjectileConfig? The configuration of this Projectile.
---@param targetSphere Sphere? The target position of this Projectile.
function Projectile:new(deserializationTable, config, targetSphere)
    if deserializationTable then
        self:deserialize(deserializationTable)
    else
        assert(config, "deserializationTable is nil, config is nil. This shouldn't happen")
        assert(targetSphere, "deserializationTable is nil, targetSphere is nil. This shouldn't happen")

        self.config = config
        self.targetPos = targetSphere:getPos()
        self.pos = self.targetPos + Vec2(config.spawnDistance:evaluate(), 0):rotate(math.random() * math.pi * 2)
        -- If `targetSphere` is `nil`, then `targetPos` will not be updated, that's why we are only setting it if this Projectile is homing.
        self.targetSphere = config.homing and targetSphere

        _Game:playSound(config.spawnSound)
    end

    self.particle = _Game:spawnParticle(self.config.particle, self.pos)

    self.delQueue = false
end

---Updates this Projectile.
---@param dt number Time delta in seconds.
function Projectile:update(dt)
    if self.targetSphere then
        if not self.targetSphere.delQueue then
            -- If we are homing towards a sphere, update the target position.
            self.targetPos = self.targetSphere:getPos()
        else
            -- The target sphere no longer exists; stop homing towards it.
            self.targetSphere = nil
        end
    end

    local distanceThisFrame = self.config.speed * dt
    if (self.targetPos - self.pos):len() <= distanceThisFrame then
        -- This frame, we will pass through the target; snap to it and explode.
        self.pos = self.targetPos
        self:explode()
    else
        -- Come closer to the target if we're not there yet.
        local targetAngle = (self.targetPos - self.pos):angle()
        self.pos = self.pos + Vec2(distanceThisFrame, 0):rotate(targetAngle)
    end

    -- Update the particle position.
	self.particle.pos = self.pos
end

---Explodes this Projectile. This triggers the destruction particles, sphere selectors, score events, etc.
function Projectile:explode()
    self:destroy()

    _Game.level:destroySelector(self.config.destroySphereSelector, self.pos, self.config.destroyScoreEvent, self.config.destroyScoreEventPerSphere)

    if self.config.destroySound then
        _Game:playSound(self.config.destroySound, self.pos)
    end
	_Game:spawnParticle(self.config.destroyParticle, self.pos)
end

---Removes this Projectile from the level.
function Projectile:destroy()
	if self.delQueue then
		return
	end
	self.delQueue = true
	self.particle:destroy()
end

---Draws this Projectile on the screen.
---But wait! Projectiles are drawn by the ParticleManager, just like Collectibles, because they are particles! Fun!
function Projectile:draw()
    if _Debug.sphereDebugVisible then
        love.graphics.setColor(1, 0, 0.5)
        love.graphics.circle("fill", self.targetPos.x, self.targetPos.y, 15)
    end
end

---Serializes this Projectile's data for later use.
---@return table
function Projectile:serialize()
    return {
        id = self.config._path,
        pos = {x = self.pos.x, y = self.pos.y},
        targetPos = {x = self.targetPos.x, y = self.targetPos.y},
        targetSphere = self.targetSphere and self.targetSphere:getIDs()
    }
end

---Deserializes previously saved Projectile's data and restores its state.
---@param t table The data to be deserialized.
function Projectile:deserialize(t)
    self.config = _Game.resourceManager:getProjectileConfig(t.id)
    self.pos = Vec2(t.pos.x, t.pos.y)
    self.targetPos = Vec2(t.targetPos.x, t.targetPos.y)
    self.targetSphere = t.targetSphere and _Game.level:getSphere(t.targetSphere)
end

return Projectile