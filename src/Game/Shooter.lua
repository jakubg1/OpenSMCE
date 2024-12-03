local class = require "com.class"

---Represents a Shooter which is controlled by the player. Has a current and a next sphere slot. Can have multi-spheres and speed shot.
---@class Shooter
---@overload fun(data):Shooter
local Shooter = class:derive("Shooter")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")

local SphereEntity = require("src.Game.SphereEntity")



---Constructs a new Shooter.
---@param data? table Data for the shooter.
function Shooter:new(data)
    self.levelMovement = data and data.movement
    self:changeTo(data and data.name or "default")

    self.pos = self:getInitialPos()
    self.angle = self:getInitialAngle()

    self.color = 0
    self.nextColor = 0
    self.shotCooldown = nil
    self.shotCooldownFade = nil
    self.speedShotSpeed = 0
    self.speedShotTime = 0
    self.speedShotAnim = 0
    self.speedShotParticles = {}

    self.multiColorColor = nil
    self.multiColorCount = 0

    self.reticleColor = 0
    self.reticleOldColor = nil
    self.reticleColorFade = nil
    self.reticleNextColor = 0
    self.reticleOldNextColor = nil
    self.reticleNextColorFade = nil

    self.knockbackTime = 0 -- This field counts down
    self.knockbackAngle = 0

    -- memorizing the pressed keys for keyboard control of the shooter
    self.moveKeys = {left = false, right = false}
    self.mousePos = _MousePos
    -- the speed of the shooter when controlled via keyboard
    self.moveKeySpeed = 500
    self.rotateKeySpeed = 4

    self.sphereEntities = {}
end



---Changes this Shooter's configuration to the given one.
---TODO: Replace shooter names with resource paths.
---@param name string The new shooter config to be obeyed.
function Shooter:changeTo(name)
    self.config = _Game.resourceManager:getShooterConfig("config/shooters/" .. name .. ".json")
    self.movement = self.levelMovement or self.config.movement
end





---Updates the Shooter.
---@param dt number Delta time in seconds.
function Shooter:update(dt)
    -- movement
    if self.movement.type == "linear" then
        -- luxor shooter
        if _MousePos == self.mousePos then
            -- if the mouse position hasn't changed, then the keyboard can be freely used
            if self.moveKeys.left then
                self.pos.x = self.pos.x - self.moveKeySpeed * dt
            end
            if self.moveKeys.right then
                self.pos.x = self.pos.x + self.moveKeySpeed * dt
            end
        else
            -- else, the mouse takes advantage and overwrites the position
            self.pos.x = _MousePos.x
        end
        -- clamp to bounds defined in config
        self.pos.x = math.min(math.max(self.pos.x, self.movement.xMin), self.movement.xMax)
    elseif self.movement.type == "circular" then
        -- zuma shooter
        if _MousePos == self.mousePos then
            -- if the mouse position hasn't changed, then the keyboard can be freely used
            if self.moveKeys.left then
                self.angle = self.angle - self.rotateKeySpeed * dt
            end
            if self.moveKeys.right then
                self.angle = self.angle + self.rotateKeySpeed * dt
            end
        else
            -- else, the mouse takes advantage and overwrites the angle
            self.angle = (_MousePos - self.pos):angle() + math.pi / 2
        end
        -- make the angle be in the interval [-pi, pi)
        self.angle = (self.angle + math.pi) % (math.pi * 2) - math.pi
    end
    self.mousePos = _MousePos

    -- shot cooldown
    if self.shotCooldown and (not _Game.level:hasShotSpheres() or self.config.multishot) then
        self.shotCooldown = self.shotCooldown - dt
        if self.shotCooldown <= 0 then
            self.shotCooldown = nil
            self.shotCooldownFade = self.config.shotCooldownFade
        end
    end
    -- shot cooldown fade
    if self.shotCooldownFade then
        self.shotCooldownFade = self.shotCooldownFade - dt
        if self.shotCooldownFade <= 0 then
            self.shotCooldownFade = nil
        end
    end

    -- filling
    if self:isActive() then
        -- remove nonexistent colors, but only if the current color generator allows removing these colors
        local remTable = _Game.level:getCurrentColorGenerator().colorsRemoveIfNonexistent
        if remTable and _Utils.isValueInTable(remTable, self.color) and not _Game.level.colorManager:isColorExistent(self.color) then
            self:setColor(0)
        end
        if remTable and _Utils.isValueInTable(remTable, self.nextColor) and not _Game.level.colorManager:isColorExistent(self.nextColor) then
            self:setNextColor(0)
        end
        self:fill()
    end

    -- speed shot time counting
    if self.speedShotTime > 0 then
        self.speedShotTime = math.max(self.speedShotTime - dt, 0)
        self.speedShotAnim = math.min(self.speedShotAnim + dt / self.config.speedShotBeam.fadeTime, 1)
        for i = 1, self:getSphereCount() do
            if self.speedShotParticles[i] then
                self.speedShotParticles[i].pos = self:getSpherePos(i)
            else
                self.speedShotParticles[i] = _Game:spawnParticle(self.config.speedShotParticle, self:getSpherePos(i))
            end
        end
    else
        self.speedShotAnim = math.max(self.speedShotAnim - dt / self.config.speedShotBeam.fadeTime, 0)
        self:destroySpeedShotParticles()
    end

    -- Update the reticle color fade animation.
    if self.reticleColorFade then
        self.reticleColorFade = self.reticleColorFade + dt
        if self.reticleColorFade >= self.config.reticle.colorFadeTime then
            self.reticleOldColor = nil
            self.reticleColorFade = nil
        end
    end
    if self.reticleNextColorFade then
        self.reticleNextColorFade = self.reticleNextColorFade + dt
        if self.reticleNextColorFade >= self.config.reticle.nextColorFadeTime then
            self.reticleOldNextColor = nil
            self.reticleNextColorFade = nil
        end
    end

    -- Update the knockback animation.
    if self.knockbackTime > 0 then
        self.knockbackTime = self.knockbackTime - dt
        if self.knockbackTime < 0 then
            self.knockbackTime = 0
        end
    end

    -- Update the sphere entity position.
    for i = 1, self:getSphereCount() do
        if self.sphereEntities[i] then
            self.sphereEntities[i]:setPos(self:getSpherePos(i))
        end
    end
end



---Sets the primary sphere color to a given sphere color ID.
---@param color integer The ID of a sphere color to be changed to. `0` will empty this slot.
function Shooter:setColor(color)
    self.color = color

    if color == 0 then
        self:destroySphereEntities()
    end
    if color ~= 0 then
        self:spawnSphereEntities()

        if self.config.reticle.colorFadeTime then
            self.reticleOldColor = self.reticleColor
            self.reticleColorFade = 0
        end
        self.reticleColor = color
    end
end



---Sets the secondary sphere color to a given sphere color ID.
---@param color integer The ID of a sphere color to be changed to. `0` will empty this slot.
function Shooter:setNextColor(color)
    self.nextColor = color

    if color ~= 0 then
        if self.config.reticle.nextColorFadeTime then
            self.reticleOldNextColor = self.reticleNextColor
            self.reticleNextColorFade = 0
        end
        self.reticleNextColor = color
    end
end



---Empties this shooter. This includes removing all effects, such as speed shot or multi-color spheres.
function Shooter:empty()
    self:destroySphereEntities()
    self:setColor(0)
    self:setNextColor(0)
    self.multiColorColor = nil
    self.multiColorCount = 0
    self.speedShotTime = 0
end



---Swaps this and next sphere colors with each other, if possible.
function Shooter:swapColors()
    -- we must be careful not to swap the spheres when they're absent
    if _Game.level.pause or self.color == 0 or self.nextColor == 0 or self.shotCooldownFade or not self:getSphereConfig().interchangeable then
        return
    end
    local tmp = self.color
    self:setColor(self.nextColor)
    self:setNextColor(tmp)
    _Game:playSound(self.config.sounds.sphereSwap, self.pos)
end



---Generates a new sphere color ID for this shooter.
---@return integer
function Shooter:getNextColor()
    if self.multiColorCount == 0 then
        return _Game.level:getNewShooterColor()
    else
        self.multiColorCount = self.multiColorCount - 1
        return self.multiColorColor
    end
end



---Fills any empty spaces in the shooter.
function Shooter:fill()
    if self.nextColor == 0 or self.color == 0 then
        _Game:playSound(self.config.sounds.sphereFill, self.pos)
    end
    if self.nextColor == 0 then
        self:setNextColor(self:getNextColor())
    end
    if self.color == 0 and self.nextColor ~= 0 then
        self:setColor(self.nextColor)
        self:setNextColor(self:getNextColor())
    end
end

---Fills only the reserve space in the shooter.
function Shooter:fillReserve()
    if self.nextColor == 0 then
        self:setNextColor(self:getNextColor())
    end
end



---Returns whether the Shooter is active.
---When the shooter is deactivated, new balls won't be added and existing can't be shot or removed.
function Shooter:isActive()
    -- Eliminate all cases where we're not in the main level gameplay loop.
    if _Game.level:getCurrentSequenceStepType() ~= "gameplay" or _Game.level.levelSequenceVars.warmupTime or _Game.level:hasNoMoreSpheres() then
        return false
    end
    -- When there's already a shot sphere and the config does not permit more, disallow.
    if _Game.level:hasShotSpheres() and not self.config.multishot then
        return false
    end
    -- Same for shooting delay.
    if self.shotCooldown then
        return false
    end
    -- Otherwise, allow.
    return true
end



---Launches the current sphere, if possible.
function Shooter:shoot()
    -- if nothing to shoot, it's pointless
    if _Game.level.pause or not self:isActive() or self.shotCooldownFade or self.color == 0 then
        return
    end

    -- Spawn the Shot Sphere or deploy the sphere, depending on its config.
    local sphereConfig = self:getSphereConfig()
    for i = 1, self:getSphereCount() do
        if sphereConfig.shootBehavior.type == "destroySpheres" then
            -- lightning spheres are not shot, they're deployed instantly
            _Game:spawnParticle(sphereConfig.destroyParticle, self:getSpherePos(i))
            _Game.level:destroySelector(sphereConfig.shootBehavior.selector, self:getSpherePos(i), sphereConfig.shootBehavior.scoreEvent, sphereConfig.shootBehavior.scoreEventPerSphere, true)
            self:destroySphereEntities()
        else
            -- Make sure the sphere alpha is always correct, we could've shot a sphere which has JUST IN THIS FRAME grown up to be shot.
            self.sphereEntities[i]:setAlpha(self:getSphereAlpha())
            _Game.level:spawnShotSphere(self, self:getSphereShotPos(i), self.angle, self:getSphereSize(), self.color, self:getShootingSpeed(), self.sphereEntities[i])
            self.sphereEntities[i] = nil
        end
        _Game.level.spheresShot = _Game.level.spheresShot + 1
    end

    -- Apply any effects to the sphere if it has one.
    if sphereConfig.shootEffects then
        for i, effect in ipairs(sphereConfig.shootEffects) do
            _Game.level:applyEffect(effect)
        end
    end

    -- Deal the knockback.
    if self.config.knockback and self.knockbackTime == 0 then
        self.knockbackTime = self.speedShotTime > 0 and self.config.knockback.speedShotDuration or self.config.knockback.duration
        self.knockbackAngle = self.angle
    end

    -- Play the sound, etc.
    _Game:playSound(sphereConfig.shootSound, self.pos)
    self.color = 0
    self.shotCooldown = self.config.shotCooldown
end



---Deinitialization function.
function Shooter:destroy()
    self:destroySphereEntities()
    self:destroySpeedShotParticles()
end



---Replaces the first non-empty slot of the shooter with a given sphere color.
---@param color integer The sphere color ID to be changed to.
function Shooter:getSphere(color)
    if self.color ~= 0 then
        self:setColor(color)
    elseif self.nextColor ~= 0 then
        self:setNextColor(color)
    end
end



---Activates the multi-sphere mode and applies a given amount of spheres of a given color.
---@param color integer The sphere color ID to be changed to.
---@param count integer The amount of spheres of that color to be given.
function Shooter:getMultiSphere(color, count)
    if _Game.level.lost then
        return
    end
    self.multiColorColor = color
    self.multiColorCount = count
    self:setColor(0)
    self:setNextColor(0)
end



---Deactivates the multi-sphere mode and removes all already existing spheres of that type from the shooter.
function Shooter:removeMultiSphere()
    if self.color == self.multiColorColor then
        self:setColor(0)
    end
    if self.nextColor == self.multiColorColor then
        self:setNextColor(0)
    end
    self.multiColorColor = nil
    self.multiColorCount = 0
end





---Drawing callback function.
function Shooter:draw()
    local pos = self:getVisualPos()
    if self.config.shadowSprite then
        self.config.shadowSprite:draw(pos + self.config.shadowSpriteOffset:rotate(self.angle), self.config.shadowSpriteAnchor, nil, nil, self.angle)
    end
    self.config.sprite:draw(pos + self.config.spriteOffset:rotate(self.angle), self.config.spriteAnchor, nil, nil, self.angle)

    -- retical
    if _EngineSettings:getAimingRetical() then
        self:drawReticle()
    end

    -- this color
    for i = 1, self:getSphereCount() do
        local entity = self.sphereEntities[i]
        if entity then
            entity:setPos(self:getSpherePos(i))
            entity:setAngle(self.angle)
            entity:setScale(self:getSphereSize() / 32)
            entity:setFrame(self:getSphereFrame())
            entity:setAlpha(self:getSphereAlpha())
            entity:draw()
        end
    end
    -- next color
    local sprite = self.config.nextBallSprites[self.nextColor].sprite
    sprite:draw(pos + self.config.nextBallOffset:rotate(self.angle), self.config.nextBallAnchor, nil, self:getNextSphereFrame(), self.angle)

	if _Debug.sphereDebugVisible2 then
		self:drawDebug()
	end
end



---Draws the speed shot beam.
function Shooter:drawSpeedShotBeam()
    -- rendering options:
    -- "full" - the beam is always fully visible
    -- "cut" - the beam is cut on the target position
    -- "scale" - the beam is squished between the shooter and the target position
    if self.speedShotAnim == 0 then
        return
    end

    for i = 1, self:getSphereCount() do
        local startPos = self:getSpherePos(i)
        local targetPos = self:getTargetPosForSphere(i)
        local maxDistance = self.config.speedShotBeam.sprite.size.y
        local distance = math.min(targetPos and (startPos - targetPos):len() or maxDistance, maxDistance)
        local distanceUnit = distance / maxDistance
        local scale = Vec2(1)
        if self.config.speedShotBeam.renderingType == "scale" then
            -- if we need to scale the beam
            scale.y = distanceUnit
        elseif self.config.speedShotBeam.renderingType == "cut" then
            -- if we need to cut the beam
            -- make a polygon: determine all four corners first
            local p1 = _PosOnScreen(startPos + Vec2(-self.config.speedShotBeam.sprite.size.x / 2, -distance):rotate(self.angle))
            local p2 = _PosOnScreen(startPos + Vec2(self.config.speedShotBeam.sprite.size.x / 2, -distance):rotate(self.angle))
            local p3 = _PosOnScreen(startPos + Vec2(self.config.speedShotBeam.sprite.size.x / 2, 16):rotate(self.angle))
            local p4 = _PosOnScreen(startPos + Vec2(-self.config.speedShotBeam.sprite.size.x / 2, 16):rotate(self.angle))
            -- mark all pixels within the polygon with value of 1
            love.graphics.stencil(function()
                love.graphics.setColor(1, 1, 1)
                love.graphics.polygon("fill", p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, p4.x, p4.y)
            end, "replace", 1)
            -- mark only these pixels as the pixels which can be affected
            love.graphics.setStencilTest("equal", 1)
        end
        -- apply color if wanted
        local color = self.config.speedShotBeam.colored and self:getReticleColor() or Color()
        -- draw the beam
        self.config.speedShotBeam.sprite:draw(startPos + Vec2(0, 16):rotate(self.angle), Vec2(0.5, 1), nil, nil, self.angle, color, self.speedShotAnim, scale)
        -- reset the scissor
        if self.config.speedShotBeam.renderingType == "cut" then
            love.graphics.setStencilTest()
        end
    end
end



---Draws the reticle.
function Shooter:drawReticle()
    local targetPos = self:getTargetPos()
    local color = self:getReticleColor()
    local sphereConfig = self:getSphereConfig()
    if targetPos and sphereConfig.shootBehavior.type == "normal" then
        if self.config.reticle.sprite then
            local location = targetPos + (_ParseVec2(self.config.reticle.offset) or Vec2()):rotate(self.angle)
            self.config.reticle.sprite:draw(location, Vec2(0.5, 0), nil, nil, self.angle, color)
            if self.config.reticle.nextBallSprite then
                local nextColor = self:getNextReticleColor()
                local nextLocation = location + (_ParseVec2(self.config.reticle.nextBallOffset) or Vec2()):rotate(self.angle)
                self.config.reticle.nextBallSprite:draw(nextLocation, Vec2(0.5, 0), nil, nil, self.angle, nextColor)
            end
        else
            love.graphics.setLineWidth(3 * _GetResolutionScale())
            love.graphics.setColor(color.r, color.g, color.b)
            local p1 = _PosOnScreen(targetPos + Vec2(-8, 8):rotate(self.angle))
            local p2 = _PosOnScreen(targetPos)
            local p3 = _PosOnScreen(targetPos + Vec2(8, 8):rotate(self.angle))
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
            love.graphics.line(p2.x, p2.y, p3.x, p3.y)
        end

        -- Fireball range highlight
        if sphereConfig.hitBehavior.type == "fireball" or sphereConfig.hitBehavior.type == "colorCloud" then
            if self.config.reticle.radiusSprite then
                local location = targetPos + (_ParseVec2(self.config.reticle.offset) or Vec2())
                local scale = Vec2(sphereConfig.hitBehavior.range * 2) / self.config.reticle.radiusSprite.size
                self.config.reticle.radiusSprite:draw(location, Vec2(0.5), nil, nil, nil, color, nil, scale)
            else
                --love.graphics.setColor(1, 0, 0)
                local dotCount = math.ceil(sphereConfig.hitBehavior.range / 12) * 4
                for i = 1, dotCount do
                    local angle = (2 * i * math.pi / dotCount) + _TotalTime / 2
                    local p = _PosOnScreen(targetPos + Vec2(sphereConfig.hitBehavior.range, 0):rotate(angle))
                    love.graphics.circle("fill", p.x, p.y, 2 * _GetResolutionScale())
                end
                --love.graphics.setLineWidth(3 * getResolutionScale())
                --love.graphics.circle("line", p2.x, p2.y, sphereConfig.hitBehavior.range)
            end
        end
    end
end



---Draws this Shooter's hitbox.
function Shooter:drawDebug()
    local p = _PosOnScreen(self.pos + self.config.hitboxOffset - self.config.hitboxSize / 2)
    local s = self.config.hitboxSize * _GetResolutionScale()
    love.graphics.rectangle("line", p.x, p.y, s.x, s.y)
end



---Spawns sphere entities which are used to draw the primary spheres, or changes their color to the proper one.
function Shooter:spawnSphereEntities()
    if self.color == 0 then
        return
    end
    for i = 1, self:getSphereCount() do
        if self.sphereEntities[i] then
            self.sphereEntities[i]:setColor(self.color)
        else
            self.sphereEntities[i] = SphereEntity(self:getSpherePos(i), self.color)
        end
    end
end



---Destroys all Sphere Entities from this Shooter.
function Shooter:destroySphereEntities()
    for i = 1, self:getSphereCount() do
        if self.sphereEntities[i] then
            -- Show particles if the level was lost.
            self.sphereEntities[i]:destroy(_Game.level.lost and self.config.destroySphereOnFail)
            self.sphereEntities[i] = nil
        end
    end
end



---Destroys all Speed Shot particles from this Shooter.
function Shooter:destroySpeedShotParticles()
    for i = 1, self:getSphereCount() do
        if self.speedShotParticles[i] then
            self.speedShotParticles[i]:destroy()
            self.speedShotParticles[i] = nil
        end
    end
end



---Returns the primary sphere color for the reticle.
---@return Color
function Shooter:getReticleColor()
    if self.reticleColorFade then
        local t = self.reticleColorFade / self.config.reticle.colorFadeTime
        return self:getReticleColorForSphere(self.reticleColor) * t + self:getReticleColorForSphere(self.reticleOldColor) * (1 - t)
    end
    return self:getReticleColorForSphere(self.reticleColor)
end

---Returns the secondary sphere color for the reticle.
---@return Color
function Shooter:getNextReticleColor()
    if self.reticleNextColorFade then
        local t = self.reticleNextColorFade / self.config.reticle.nextColorFadeTime
        return self:getReticleColorForSphere(self.reticleNextColor) * t + self:getReticleColorForSphere(self.reticleOldNextColor) * (1 - t)
    end
    return self:getReticleColorForSphere(self.reticleNextColor)
end



---Returns a would-be reticle color for a given sphere color, handling the color palettes.
---@param color integer The sphere ID for which the color should be checked.
---@return Color
function Shooter:getReticleColorForSphere(color)
    local config = _Game.configManager.spheres[color]
    if type(config.color) == "string" then
        return _Game.resourceManager:getColorPalette(config.color):getColor(_TotalTime * config.colorSpeed)
    else
        return Color(config.color.r, config.color.g, config.color.b)
    end
end



---Returns the initial position of this Shooter, based on its config.
---@return Vector2
function Shooter:getInitialPos()
    if self.movement.type == "linear" then
        return Vec2((self.movement.xMin + self.movement.xMax) / 2, self.movement.y)
    elseif self.movement.type == "circular" then
        return Vec2(self.movement.x, self.movement.y)
    end
    return Vec2()
end

---Returns the initial angle of this Shooter in radians, based on its config.
---@return number
function Shooter:getInitialAngle()
    if self.movement.type == "linear" then
        return self.movement.angle / 180 * math.pi
    elseif self.movement.type == "circular" then
        return 0
    end
    return 0
end



---Returns the current visual position of the shooter. This can differ from its actual position if the knockback animation is being played.
---@return Vector2
function Shooter:getVisualPos()
    if not self.config.knockback or self.knockbackTime == 0 then
        return self.pos
    end

    local duration = self.speedShotTime > 0 and self.config.knockback.speedShotDuration or self.config.knockback.duration
    local strength = self.speedShotTime > 0 and self.config.knockback.speedShotStrength or self.config.knockback.strength
    local t = 0
    if self.knockbackTime > duration / 2 then
        t = (duration - self.knockbackTime) / duration * 2
    else
        t = self.knockbackTime / duration * 2
    end
    return self.pos + Vec2(0, strength * t):rotate(self.knockbackAngle)
end



---Returns the number of primary spheres in this shooter.
---@return integer
function Shooter:getSphereCount()
    return #self.config.spheres
end



---Returns the center position of the primary sphere on the given slot.
---@param n integer The main slot number for the sphere to be checked for.
---@return Vector2
function Shooter:getSpherePos(n)
    return self.pos + self.config.spheres[n].pos:rotate(self.angle)
end



---Returns the shooting center position of the primary sphere on the given slot.
---This is the position that the sphere will warp to the moment it's shot.
---Does not apply to instantly deployed powerups.
---@param n integer The main slot number for the sphere to be checked for.
---@return Vector2
function Shooter:getSphereShotPos(n)
    local shotPos = self.config.spheres[n].shotPos
    if shotPos then
        return self.pos + shotPos:rotate(self.angle)
    end
    return self:getSpherePos(n)
end



---Returns the diameter of the primary sphere.
function Shooter:getSphereSize()
    return self:getSphereConfig().size or 32
end



---Returns `true` if the given position is inside this Shooter's hitbox.
---@param pos Vector2 The position to be checked against.
---@return boolean
function Shooter:isPosCatchable(pos)
    return math.abs(self.pos.x - pos.x + self.config.hitboxOffset.x) < self.config.hitboxSize.x / 2 and math.abs(self.pos.y - pos.y + self.config.hitboxOffset.y) < self.config.hitboxSize.y / 2
end



---Returns the reticle position.
---@return Vector2
function Shooter:getTargetPos()
    return _Game.level:getNearestSphereOnLine(self.pos, self.angle).targetPos
end



---Returns the reticle position, starting from the given sphere.
---@param n integer The main slot number for the sphere to be checked for.
---@return Vector2
function Shooter:getTargetPosForSphere(n)
    return _Game.level:getNearestSphereOnLine(self:getSpherePos(n), self.angle).targetPos
end



---Returns the current effective shooting speed.
---@return number
function Shooter:getShootingSpeed()
    local sphereSpeed = self:getSphereConfig().shootSpeed
    if sphereSpeed then
        return sphereSpeed
    elseif self.speedShotTime > 0 then
        return self.speedShotSpeed
    end
    return self.config.shootSpeed
end



---Returns config for the current sphere.
---@return table
function Shooter:getSphereConfig()
    return _Game.configManager.spheres[self.color]
end



---Returns config for the next sphere.
---@return table
function Shooter:getNextSphereConfig()
    return _Game.configManager.spheres[self.nextColor]
end



---Returns the current sphere's animation frame.
---@return integer
function Shooter:getSphereFrame()
    local animationSpeed = self:getSphereConfig().spriteAnimationSpeed
    if animationSpeed then
        return math.floor(animationSpeed * _TotalTime)
    end
    return 1
end



---Returns the current sphere's transparency. Used in shot cooldown fade animation.
---@return number
function Shooter:getSphereAlpha()
    if self.shotCooldownFade then
        return 1 - (self.shotCooldownFade / self.config.shotCooldownFade)
    end
    return 1
end



---Returns the next sphere's animation frame.
---@return integer
function Shooter:getNextSphereFrame()
    local animationSpeed = self.config.nextBallSprites[self.nextColor].spriteAnimationSpeed
    if animationSpeed then
        return math.floor(animationSpeed * _TotalTime)
    end
    return 1
end



---Callback from `main.lua`.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button which was pressed.
function Shooter:mousepressed(x, y, button)
    if button == 1 then
        self:shoot()
    elseif button == 2 then
        self:swapColors()
    end
end



---Callback from `main.lua`.
---@param key string The pressed key code.
function Shooter:keypressed(key)
    if key == "left" then self.moveKeys.left = true end
    if key == "right" then self.moveKeys.right = true end
    if key == "up" then self:shoot() end
    if key == "down" then self:swapColors() end
end



---Callback from `main.lua`.
---@param key string The released key code.
function Shooter:keyreleased(key)
    if key == "left" then self.moveKeys.left = false end
    if key == "right" then self.moveKeys.right = false end
end



---Serializes this Shooter's data for saving purposes.
---@return table
function Shooter:serialize()
    return {
        color = self.color,
        nextColor = self.nextColor,
        multiColorColor = self.multiColorColor,
        multiColorCount = self.multiColorCount,
        speedShotTime = self.speedShotTime,
        speedShotSpeed = self.speedShotSpeed
    }
end



---Deserializes and loads previosly saved serialized data.
---@param t table
function Shooter:deserialize(t)
    self.color = t.color
    self.nextColor = t.nextColor
    self.multiColorColor = t.multiColorColor
    self.multiColorCount = t.multiColorCount
    self.speedShotTime = t.speedShotTime
    self.speedShotSpeed = t.speedShotSpeed

    self.reticleColor = t.color
    self.reticleNextColor = t.nextColor

    self:spawnSphereEntities()
end



return Shooter
