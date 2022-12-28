local class = require "com/class"

---@class Shooter
---@overload fun():Shooter
local Shooter = class:derive("Shooter")

local Vec2 = require("src/Essentials/Vector2")
local Sprite = require("src/Essentials/Sprite")
local Color = require("src/Essentials/Color")

local SphereEntity = require("src/SphereEntity")
local ShotSphere = require("src/ShotSphere")



---Constructs a new Shooter.
---@param data? table Data for the shooter.
function Shooter:new(data)
    self.config = _Game.configManager:getShooter(data and data.name or "default")
    self.movement = self.config.movement
    if data and data.movement then
        self.movement = data.movement
    end

    self.pos = self:getInitialPos()
    self.angle = self:getInitialAngle()

    self.color = 0
    self.nextColor = 0
    self.active = false -- when the sphere is shot you can't shoot; same for start, win, lose
    self.speedShotSpeed = 0
    self.speedShotTime = 0
    self.speedShotAnim = 0
    self.speedShotParticle = nil

    self.multiColorColor = nil
    self.multiColorCount = 0

    -- memorizing the pressed keys for keyboard control of the shooter
    self.moveKeys = {left = false, right = false}
    self.mousePos = _MousePos
    -- the speed of the shooter when controlled via keyboard
    self.moveKeySpeed = 500
    self.rotateKeySpeed = 4

    self.sprite = self.config.sprite
    self.shadowSprite = self.config.shadowSprite
    self.speedShotSprite = self.config.speedShotBeam.sprite

    self.reticleSprite = self.config.reticle.sprite
    self.reticleNextSprite = self.config.reticle.nextBallSprite
    self.radiusReticleSprite = self.config.reticle.radiusSprite

    self.sphereEntity = nil
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

    -- filling
    if self.active then
        -- remove nonexistent colors, but only if the current color generator allows removing these colors
        local remTable = _Game.session.level:getCurrentColorGenerator().colors_remove_if_nonexistent
        if _MathIsValueInTable(remTable, self.color) and not _Game.session.colorManager:isColorExistent(self.color) then
            self:setColor(0)
        end
        if _MathIsValueInTable(remTable, self.nextColor) and not _Game.session.colorManager:isColorExistent(self.nextColor) then
            self:setNextColor(0)
        end
        self:fill()
    end

    -- speed shot time counting
    if self.speedShotTime > 0 then
        self.speedShotTime = math.max(self.speedShotTime - dt, 0)
        self.speedShotAnim = math.min(self.speedShotAnim + dt / self.config.speedShotBeam.fadeTime, 1)
        if self.speedShotParticle then
            self.speedShotParticle.pos = self:getSpherePos()
        else
            self.speedShotParticle = _Game:spawnParticle(self.config.speedShotParticle, self:getSpherePos())
        end
    else
        self.speedShotAnim = math.max(self.speedShotAnim - dt / self.config.speedShotBeam.fadeTime, 0)
        if self.speedShotParticle then
            self.speedShotParticle:destroy()
            self.speedShotParticle = nil
        end
    end

    -- Update the sphere entity position.
    if self.sphereEntity then
        self.sphereEntity:setPos(self:getSpherePos())
    end
end



---Sets the primary sphere color to a given sphere color ID.
---@param color integer The ID of a sphere color to be changed to. `0` will empty this slot.
function Shooter:setColor(color)
    self.color = color

    if color == 0 and self.sphereEntity then
        self.sphereEntity:destroy(false)
        self.sphereEntity = nil
    end
    if color ~= 0 then
        if self.sphereEntity then
            self.sphereEntity:setColor(color)
        else
            self.sphereEntity = SphereEntity(self:getSpherePos(), color)
        end
    end
end



---Sets the secondary sphere color to a given sphere color ID.
---@param color integer The ID of a sphere color to be changed to. `0` will empty this slot.
function Shooter:setNextColor(color)
    self.nextColor = color
end



---Empties and deactivates this shooter. This includes removing all effects, such as speed shot or multi-color spheres.
function Shooter:empty()
    self.active = false
    self:setColor(0)
    self:setNextColor(0)
    self.multiColorColor = nil
    self.multiColorCount = 0
    self.speedShotTime = 0
end



---Swaps this and next sphere colors with each other, if possible.
function Shooter:swapColors()
    -- we must be careful not to swap the spheres when they're absent
    if _Game.session.level.pause or self.color == 0 or self.nextColor == 0 or not self:getSphereConfig().interchangeable then
        return
    end
    local tmp = self.color
    self:setColor(self.nextColor)
    self:setNextColor(tmp)
    _Game:playSound(self.config.sounds.sphereSwap, 1, self.pos)
end



---Generates a new sphere color ID for this shooter.
---@return integer
function Shooter:getNextColor()
    if self.multiColorCount == 0 then
        return _Game.session.level:getNewShooterColor()
    else
        self.multiColorCount = self.multiColorCount - 1
        return self.multiColorColor
    end
end



---Fills any empty spaces in the shooter.
function Shooter:fill()
    if self.nextColor == 0 then
        self:setNextColor(self:getNextColor())
    end
    if self.color == 0 and self.nextColor ~= 0 then
        self:setColor(self.nextColor)
        self:setNextColor(self:getNextColor())
    end
end



---Activates the shooter and plays a shooter fill sound.
function Shooter:activate()
    self.active = true
    _Game:playSound(self.config.sounds.sphereFill, 1, self.pos)
end



---Launches the current sphere, if possible.
function Shooter:shoot()
    -- if nothing to shoot, it's pointless
    if _Game.session.level.pause or not self.active or self.color == 0 then
        return
    end

    local sphereConfig = self:getSphereConfig()
    if sphereConfig.shootBehavior.type == "lightning" then
        -- lightning spheres are not shot, they're deployed instantly
        _Game:spawnParticle(sphereConfig.destroyParticle, self:getSpherePos())
        _Game.session:destroyVerticalColor(self.pos.x, sphereConfig.shootBehavior.range, self.color)
    else
        _Game.session.level:spawnShotSphere(self, self:getSpherePos(), self.angle, self.color, self:getShootingSpeed())
        self.sphereEntity = nil
        self.active = false
    end
    if sphereConfig.shootEffects then
        for i, effect in ipairs(sphereConfig.shootEffects) do
            _Game.session.level:applyEffect(effect)
        end
    end
    _Game:playSound(sphereConfig.shootSound, 1, self.pos)
    self.color = 0
    _Game.session.level.spheresShot = _Game.session.level.spheresShot + 1
end



---Deinitialization function.
function Shooter:destroy()
    if self.sphereEntity then
        self.sphereEntity:destroy(false)
    end
    if self.speedShotParticle then
        self.speedShotParticle:destroy()
    end
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
    self.multiColorColor = color
    self.multiColorCount = count
    self:setColor(0)
    self:setNextColor(0)
end





---Drawing callback function.
function Shooter:draw()
    self.shadowSprite:draw(self.pos + self.config.shadowSpriteOffset:rotate(self.angle), self.config.shadowSpriteAnchor, nil, nil, self.angle)
    self.sprite:draw(self.pos + self.config.spriteOffset:rotate(self.angle), self.config.spriteAnchor, nil, nil, self.angle)

    -- retical
    if _EngineSettings:getAimingRetical() then
        self:drawReticle()
    end

    -- this color
    if self.sphereEntity then
        self.sphereEntity:setPos(self:getSpherePos())
        self.sphereEntity:setAngle(self.angle)
        self.sphereEntity:setFrame(self:getSphereFrame())
        self.sphereEntity:draw()
    end
    -- next color
    local sprite = _Game.resourceManager:getSprite(self:getNextSphereConfig().nextSprite)
    local frame = self:getNextSphereFrame()
    sprite:draw(self.pos + self.config.nextBallOffset:rotate(self.angle), self.config.nextBallAnchor, nil, frame, self.angle)

    --local p4 = posOnScreen(self.pos)
    --love.graphics.rectangle("line", p4.x - 80, p4.y - 15, 160, 30)
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

    local targetPos = self:getTargetPos()
    local maxDistance = self.speedShotSprite.size.y
    local distance = math.min(targetPos and (self.pos - targetPos):len() or maxDistance, maxDistance)
    local distanceUnit = distance / maxDistance
    local scale = Vec2(1)
    if self.config.speedShotBeam.renderingType == "scale" then
        -- if we need to scale the beam
        scale.y = distanceUnit
    elseif self.config.speedShotBeam.renderingType == "cut" then
        -- if we need to cut the beam
        -- make a polygon: determine all four corners first
        local p1 = _PosOnScreen(self.pos + Vec2(-self.speedShotSprite.size.x / 2, -distance):rotate(self.angle))
        local p2 = _PosOnScreen(self.pos + Vec2(self.speedShotSprite.size.x / 2, -distance):rotate(self.angle))
        local p3 = _PosOnScreen(self.pos + Vec2(self.speedShotSprite.size.x / 2, 16):rotate(self.angle))
        local p4 = _PosOnScreen(self.pos + Vec2(-self.speedShotSprite.size.x / 2, 16):rotate(self.angle))
        -- mark all pixels within the polygon with value of 1
        love.graphics.stencil(function()
            love.graphics.setColor(1, 1, 1)
            love.graphics.polygon("fill", p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, p4.x, p4.y)
        end, "replace", 1)
        -- mark only these pixels as the pixels which can be affected
        love.graphics.setStencilTest("equal", 1)
    end
    -- apply color if wanted
    local color = self.config.speedShotBeam.colored and self:getReticalColor() or Color()
    -- draw the beam
    self.speedShotSprite:draw(self:getSpherePos() + Vec2(0, 16):rotate(self.angle), Vec2(0.5, 1), nil, nil, self.angle, color, self.speedShotAnim, scale)
    -- reset the scissor
    if self.config.speedShotBeam.renderingType == "cut" then
        love.graphics.setStencilTest()
    end
end



---Draws the reticle.
function Shooter:drawReticle()
    local targetPos = self:getTargetPos()
    local color = self:getReticalColor()
    local sphereConfig = self:getSphereConfig()
    if targetPos and self.color ~= 0 and sphereConfig.shootBehavior.type == "normal" then
        if self.reticleSprite then
            local location = targetPos + (_ParseVec2(self.config.reticle.offset) or Vec2()):rotate(self.angle)
            self.reticleSprite:draw(location, Vec2(0.5, 0), nil, nil, self.angle, color)
            if self.reticleNextSprite then
                local nextColor = self:getNextReticalColor()
                local nextLocation = location + (_ParseVec2(self.config.reticle.nextBallOffset) or Vec2()):rotate(self.angle)
                self.reticleNextSprite:draw(nextLocation, Vec2(0.5, 0), nil, nil, self.angle, nextColor)
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

        --_Game.resourceManager.

        -- Fireball range highlight
        if sphereConfig.hitBehavior.type == "fireball" or sphereConfig.hitBehavior.type == "colorCloud" then
            if self.radiusReticleSprite then
                local location = targetPos + (_ParseVec2(self.config.reticle.offset) or Vec2())
                local scale = Vec2(sphereConfig.hitBehavior.range * 2) / self.radiusReticleSprite.size
                self.radiusReticleSprite:draw(location, Vec2(0.5), nil, nil, nil, color, nil, scale)
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



---Spawns a sphere entity which is used to draw the primary sphere.
function Shooter:spawnSphereEntity()
    if self.color == 0 or self.sphereEntity then
        return
    end
    self.sphereEntity = SphereEntity(self:getSpherePos(), self.color)
end



---Returns the primary sphere color.
---@return table
function Shooter:getReticalColor()
    local color = self:getSphereConfig().color
    if type(color) == "string" then
        return _Game.resourceManager:getColorPalette(color):getColor(_TotalTime * self:getSphereConfig().colorSpeed)
    else
        return color
    end
end

---Returns the secondary sphere color.
---@return table
function Shooter:getNextReticalColor()
    local color = self:getNextSphereConfig().color
    if type(color) == "string" then
        return _Game.resourceManager:getColorPalette(color):getColor(_TotalTime * self:getNextSphereConfig().colorSpeed)
    else
        return color
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



---Returns the center position of the primary sphere.
---@return Vector2
function Shooter:getSpherePos()
    return self.pos - Vec2(0, -5):rotate(self.angle)
end



---Returns `true` if the given position is inside this Shooter's hitbox.
---@param pos Vector2 The position to be checked against.
---@return boolean
function Shooter:isPosCatchable(pos)
    return math.abs(self.pos.x - pos.x) < self.config.hitboxSize.x / 2 and math.abs(self.pos.y - pos.y) < self.config.hitboxSize.y / 2
end



---Returns the reticle position.
---@return Vector2
function Shooter:getTargetPos()
    return _Game.session:getNearestSphereOnLine(self.pos, self.angle).targetPos
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
---@return Vector2
function Shooter:getSphereFrame()
    local animationSpeed = self:getSphereConfig().spriteAnimationSpeed
    if animationSpeed then
        return Vec2(math.floor(animationSpeed * _TotalTime), 1)
    end
    return Vec2(1)
end



---Returns the next sphere's animation frame.
---@return Vector2
function Shooter:getNextSphereFrame()
    local animationSpeed = self:getNextSphereConfig().nextSpriteAnimationSpeed
    if animationSpeed then
        return Vec2(math.floor(animationSpeed * _TotalTime), 1)
    end
    return Vec2(1)
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
        speedShotSpeed = self.speedShotSpeed,
        active = self.active
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
    self.active = t.active



    self:spawnSphereEntity()
end



return Shooter
