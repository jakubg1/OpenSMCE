local class = require "com.class"

---Represents a Projectile which is moving towards its target, destroying spheres based on its Sphere Selector.
---@class Projectile
---@overload fun(data, config, targetSphere):Projectile
local Projectile = class:derive("Projectile")

---Constructs a new Projectile.
---@param data table? If specified, data from this table will be used to load the entity state.
---@param config ProjectileConfig? The configuration of this Projectile.
---@param targetSphere Sphere? The target position of this Projectile.
function Projectile:new(data, config, targetSphere)
    if data then
        self:deserialize(data)
    else
        assert(config, "data is nil, config is nil. This shouldn't happen")
        assert(targetSphere, "data is nil, targetSphere is nil. This shouldn't happen")

        self.config = config
        local targetPos = targetSphere:getPos()
        self.targetX, self.targetY = targetPos.x, targetPos.y
        if config.spawnDistance then
            local ox, oy = _V.rotate(config.spawnDistance:evaluate(), 0, math.random() * math.pi * 2)
            self.x, self.y = self.targetX + ox, self.targetY + oy
            -- If `targetSphere` is `nil`, then `targetPos` will not be updated, that's why we are only setting it if this Projectile is homing.
            self.targetSphere = config.homing and targetSphere
        else
            -- Insta-exploding projectile (for example: lightning storm strike).
            self.x, self.y = self.targetX, self.targetY
            self.targetSphere = targetSphere
        end

        if config.spawnSound then
            config.spawnSound:play()
        end
    end

    if self.config.particle then
        self.particle = _Game:spawnParticle(self.config.particle, self.x, self.y)
    end

    self.delQueue = false
end

---Updates this Projectile.
---@param dt number Time delta in seconds.
function Projectile:update(dt)
    -- If we are destined to instantly explode, do it. No ors, ifs, or buts.
    if not self.config.spawnDistance then
        self:explode()
        return
    end

    if self.targetSphere then
        if not self.targetSphere.delQueue then
            -- If we are homing towards a sphere, update the target position.
            local targetPos = self.targetSphere:getPos()
            self.targetX, self.targetY = targetPos.x, targetPos.y
        else
            -- The target sphere no longer exists; stop homing towards it.
            self.targetSphere = nil
        end
    end

    local distanceThisFrame = self.config.speed * dt
    if _V.length(self.targetX - self.x, self.targetY - self.y) <= distanceThisFrame then
        -- This frame, we will pass through the target; snap to it and explode.
        self.x, self.y = self.targetX, self.targetY
        self:explode()
    else
        -- Come closer to the target if we're not there yet.
        local targetAngle = _V.angle(self.targetX - self.x, self.targetY - self.y)
        local targetOX, targetOY = _V.rotate(distanceThisFrame, 0, targetAngle)
        self.x, self.y = self.x + targetOX, self.y + targetOY
    end

    -- Update the particle position.
    if self.particle then
    	self.particle:setPos(self.x, self.y)
    end
end

---Explodes this Projectile. This triggers the destruction particles, sphere selectors, score events, etc.
function Projectile:explode()
    self:destroy()

    if self.targetSphere then
        self.targetSphere:dumpVariables("hitSphere")
    end
    _Game.level:destroySelector(self.config.destroySphereSelector, self.x, self.y, self.config.destroyScoreEvent, self.config.destroyScoreEventPerSphere, self.config.destroyGameEvent, self.config.destroyGameEventPerSphere)
    _Vars:unset("hitSphere")

    if self.config.destroySound then
        self.config.destroySound:play(self.x, self.y)
    end
	_Game:spawnParticle(self.config.destroyParticle, self.x, self.y)
end

---Removes this Projectile from the level.
function Projectile:destroy()
	if self.delQueue then
		return
	end
	self.delQueue = true
    if self.particle then
    	self.particle:destroy()
    end
end

---Draws this Projectile on the screen.
---But wait! Projectiles are drawn by the ParticleManager, just like Collectibles, because they are particles! Fun!
function Projectile:draw()
    if _Debug.sphereDebugVisible then
        love.graphics.setColor(1, 0, 0.5)
        love.graphics.circle("fill", self.targetX, self.targetY, 15)
    end
end

---Serializes this Projectile's data for later use.
---@return table
function Projectile:serialize()
    return {
        id = _Res:getResourceReference(self.config),
        pos = {x = self.x, y = self.y},
        targetPos = {x = self.targetX, y = self.targetY},
        targetSphere = self.targetSphere and self.targetSphere:getIDs()
    }
end

---Deserializes previously saved Projectile's data and restores its state.
---@param t table The data to be deserialized.
function Projectile:deserialize(t)
    self.config = _Res:getProjectileConfig(t.id)
    self.x, self.y = t.pos.x, t.pos.y
    self.targetX, self.targetY = t.targetPos.x, t.targetPos.y
    self.targetSphere = t.targetSphere and _Game.level:getSphere(t.targetSphere)
end

return Projectile