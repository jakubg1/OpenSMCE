local class = require "com.class"

---Represents a Shooter which is controlled by the player. Has a current and a next sphere slot. Can have multi-spheres and speed shot.
---@class Shooter
---@overload fun(data):Shooter
local Shooter = class:derive("Shooter")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")

local SphereEntity = require("src.Game.SphereEntity")



---Constructs a new Shooter.
---@param data {shooter: string, movement: ShooterMovementConfig?}? Data for the shooter.
function Shooter:new(data)
    self.levelMovement = data and data.movement
    self:setConfig(_Game.resourceManager:getShooterConfig(data and data.shooter or "shooters/default.json"))

    self.pos = self:getInitialPos()
    self.angle = self:getInitialAngle()

    self.color = 0
    self.nextColor = 0
    self.suppressColorRemoval = false
    self.shotCooldown = nil
    self.shotCooldownFade = nil
    self.shotCooldownSphere = nil
    self.shotPressed = false
    self.speedShotSpeed = 0
    self.speedShotTime = 0
    self.speedShotAnim = 0
    self.speedShotParticles = {}
    self.sphereHoldParticles = {}
    self.homingBugsTime = 0

    self.multiColorColor = nil
    self.multiColorCount = nil
    self.multiColorTime = nil
    self.multiColorRemoveWhenTimeOut = nil
    self.multiColorHoldTimeRate = nil

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
    self.mouseX, self.mouseY = _MouseX, _MouseY
    -- the speed of the shooter when controlled via keyboard
    self.moveKeySpeed = 500
    self.rotateKeySpeed = 4

    self.sphereEntities = {}
end



---Changes this Shooter's configuration to the given one.
---@param config ShooterConfig The new shooter config.
function Shooter:setConfig(config)
    self.config = config
    self.movement = self.levelMovement or self.config.movement
end





---Updates the Shooter.
---@param dt number Delta time in seconds.
function Shooter:update(dt)
    -- movement
    if self.movement.type == "linear" then
        -- luxor shooter
        if _MouseX == self.mouseX and _MouseY == self.mouseY then
            -- if the mouse position hasn't changed, then the keyboard can be freely used
            if self.moveKeys.left then
                self.pos.x = self.pos.x - self.moveKeySpeed * dt
            end
            if self.moveKeys.right then
                self.pos.x = self.pos.x + self.moveKeySpeed * dt
            end
        else
            -- else, the mouse takes advantage and overwrites the position
            self.pos.x = _MouseX
        end
        -- clamp to bounds defined in config
        self.pos.x = _Utils.clamp(self.pos.x, self.movement.xMin, self.movement.xMax)
    elseif self.movement.type == "circular" then
        -- zuma shooter
        if _MouseX == self.mouseX and _MouseY == self.mouseY then
            -- if the mouse position hasn't changed, then the keyboard can be freely used
            if self.moveKeys.left then
                self.angle = self.angle - self.rotateKeySpeed * dt
            end
            if self.moveKeys.right then
                self.angle = self.angle + self.rotateKeySpeed * dt
            end
        else
            -- else, the mouse takes advantage and overwrites the angle
            self.angle = _V.angle(_MouseX - self.pos.x, _MouseY - self.pos.y) + math.pi / 2
        end
        -- make the angle be in the interval [-pi, pi)
        self.angle = (self.angle + math.pi) % (math.pi * 2) - math.pi
    end
    self.mouseX, self.mouseY = _MouseX, _MouseY

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
    -- shot cooldown per-sphere (independent of shot cooldown/shot cooldown fade)
    if self.shotCooldownSphere then
        self.shotCooldownSphere = self.shotCooldownSphere - dt
        if self.shotCooldownSphere <= 0 then
            self.shotCooldownSphere = nil
        end
    end

    -- filling
    if self:isActive() then
        -- remove nonexistent colors, but only if the current color generator allows removing these colors
        if not self.suppressColorRemoval then
            local remTable = _Game.level:getCurrentColorGenerator().discardableColors
            if remTable then
                if _Utils.isValueInTable(remTable, self.color) and not _Game.level.colorManager:isColorExistent(self.color) then
                    self:setColor(0)
                end
                if _Utils.isValueInTable(remTable, self.nextColor) and not _Game.level.colorManager:isColorExistent(self.nextColor) then
                    self:setNextColor(0)
                end
            end
        end
        self:fill()
    end

    -- Autofire!
    if self.shotPressed and self:canAutofire() then
        self:shoot()
    end

    -- Sphere hold particles
    if self.shotPressed and self:getSphereConfig().holdParticle then
        for i = 1, self:getSphereCount() do
            local pos = self:getSpherePos(i)
            if self.sphereHoldParticles[i] then
                self.sphereHoldParticles[i]:setPos(pos.x, pos.y)
            else
                self.sphereHoldParticles[i] = _Game:spawnParticle(self:getSphereConfig().holdParticle, pos.x, pos.y)
            end
        end
    else
        self:destroySphereHoldParticles()
    end

    -- Speed Shot timer and particles
    if self.speedShotTime > 0 then
        self.speedShotTime = math.max(self.speedShotTime - dt, 0)
        self.speedShotAnim = math.min(self.speedShotAnim + dt / self.config.speedShotBeam.fadeTime, 1)
        for i = 1, self:getSphereCount() do
            local pos = self:getSpherePos(i)
            if self.speedShotParticles[i] then
                self.speedShotParticles[i]:setPos(pos.x, pos.y)
            else
                self.speedShotParticles[i] = _Game:spawnParticle(self.config.speedShotParticle, pos.x, pos.y)
            end
        end
    else
        self.speedShotAnim = math.max(self.speedShotAnim - dt / self.config.speedShotBeam.fadeTime, 0)
        self:destroySpeedShotParticles()
    end

    -- homing bugs time counting
    if self.homingBugsTime > 0 then
        self.homingBugsTime = math.max(self.homingBugsTime - dt, 0)
    end

    -- Count the time of the multi-sphere.
    if self.multiColorColor and self.multiColorTime then
        local rate = 1
        if self.multiColorHoldTimeRate and self.shotPressed then
            rate = self.multiColorHoldTimeRate
        end
        self.multiColorTime = math.max(self.multiColorTime - dt * rate, 0)
        if self.multiColorTime == 0 then
            self:removeMultiSphere(self.multiColorRemoveWhenTimeOut)
        end
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
            local pos = self:getSpherePos(i)
            self.sphereEntities[i]:setPos(pos.x, pos.y)
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

        local shotCooldown = self:getSphereConfig().shotCooldown
        if shotCooldown then
            self.shotCooldownSphere = shotCooldown
        end

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
    self.multiColorCount = nil
    self.multiColorTime = nil
    self.multiColorRemoveWhenTimeOut = nil
    self.multiColorHoldTimeRate = nil
    self.speedShotTime = 0
end



---Swaps this and next sphere colors with each other, if possible.
function Shooter:swapColors()
    -- we must be careful not to swap the spheres when they're absent
    if _Game.level.pause or self.color == 0 or self.nextColor == 0 or self.shotCooldownFade or not self:getSphereConfig().swappable then
        return
    end
    local tmp = self.color
    self:setColor(self.nextColor)
    self:setNextColor(tmp)
    _Game:playSound(self.config.sounds.sphereSwap, self.pos.x, self.pos.y)
end



---Generates a new sphere color ID for this shooter.
---@return integer
function Shooter:getNextColor()
    local multiColorColor = self.multiColorColor
    if not multiColorColor then
        return self:getNewShooterColor()
    else
        if self.multiColorCount then
            self.multiColorCount = self.multiColorCount - 1
            if self.multiColorCount == 0 then
                self:removeMultiSphere()
            end
        end
        return multiColorColor
    end
end



---Fills any empty spaces in the shooter.
function Shooter:fill()
    -- If anything is going to happen, play the sphere fill sound and reset the discard suppression flag.
    if self.nextColor == 0 or self.color == 0 then
        self.suppressColorRemoval = false
        _Game:playSound(self.config.sounds.sphereFill, self.pos.x, self.pos.y)
    end
    -- Fill the reserve slot with a random color.
    if self.nextColor == 0 then
        self:setNextColor(self:getNextColor())
    end
    -- If the main slot is empty and the reserve slot is not, move the reserve sphere to the main sphere and generate another sphere for the reserve slot.
    if self.color == 0 and self.nextColor ~= 0 then
        self:setColor(self.nextColor)
        -- If we are suppressing color removal, spawn two spheres of the same color.
        if self.suppressColorRemoval then
            self:setNextColor(self.color)
        else
            self:setNextColor(self:getNextColor())
        end
    end
end

---Fills only the reserve space in the shooter.
function Shooter:fillReserve()
    if self.nextColor == 0 then
        self.suppressColorRemoval = false
        self:setNextColor(self:getNextColor())
    end
end



---Generates a color based on the provided Color Generator.
---@param data ColorGeneratorConfig Shooter color generator data.
---@return integer
function Shooter:generateColor(data)
	if data.type == "random" then
		-- Make a pool with colors which are on the board.
		local pool = {}
		for i, color in ipairs(data.colors) do
			if not data.hasToExist or _Game.level.colorManager:isColorExistent(color) then
				table.insert(pool, color)
			end
		end
		-- Return a random item from the pool.
		if #pool > 0 then
			return pool[math.random(#pool)]
		end
	elseif data.type == "nearEnd" then
		-- Select a random path.
		local path = _Game.level:getRandomPath(true, data.pathsInDangerOnly)
		if not path:getEmpty() then
			-- Get a SphereChain nearest to the pyramid
			local sphereChain = path.sphereChains[1]
			-- Iterate through all groups and then spheres in each group
			local lastGoodColor = nil
			-- reverse iteration!!!
			for i, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for j = #sphereGroup.spheres, 1, -1 do
					local sphere = sphereGroup.spheres[j]
					local color = sphere.color
					-- If this color is generatable, check if we're lucky this time.
					if _Utils.isValueInTable(data.colors, color) then
						if math.random() < data.selectChance then
							return color
						end
						-- Save this color in case if no more spheres are left.
						lastGoodColor = color
					end
				end
			end
			-- no more spheres left, get the last good one if exists
			if lastGoodColor then
				return lastGoodColor
			end
		end
    elseif data.type == "giveUp" then
        -- Draw a random color and keep it no matter what. Also, trip the shooter flag so it does not get rid of it anytime soon.
        -- TODO: This is some very finicky code. How do we communicate this better? The color generator should not be in charge of doing this fallback, or should it?
        self.suppressColorRemoval = true
        local colors = data.colors
        if data.spawnableColorsOnly then
            colors = _Utils.tableMultiply(colors, _Game.level:getSpawnableColors())
        end
        return colors[math.random(#colors)]
	end

	-- Else, return a fallback value.
	if data.fallback then
		return self:generateColor(data.fallback)
	end
	return 0
end

---Generates a new color for the Shooter.
---@return integer
function Shooter:getNewShooterColor()
	return self:generateColor(_Game.level:getCurrentColorGenerator())
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
    -- `self.shotCooldownFade` is excluded, because during that timeout the sphere is already spawned.
    if self.shotCooldown or self.shotCooldownSphere then
        return false
    end
    -- Otherwise, allow.
    return true
end



---Returns whether the Shooter can autofire (shoot automatically when the left mouse button is pressed).
---@return boolean
function Shooter:canAutofire()
    return self.config.autofire or self:getSphereConfig().autofire
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
        local shotBehavior = sphereConfig.shotBehavior
        if shotBehavior.type == "normal" then
            -- Make sure the sphere alpha is always correct, we could've shot a sphere which has JUST IN THIS FRAME grown up to be shot.
            self.sphereEntities[i]:setAlpha(self:getSphereAlpha())
            local amount = shotBehavior.amount or 1
            local angleTotal = shotBehavior.spreadAngle or 0
            local angleStart = amount == 1 and 0 or -angleTotal / 2
            local angleStep = amount == 1 and 0 or angleTotal / (amount - 1)
            for j = 1, amount do
                local pos = self:getSphereShotPos(i)
                local angle = self.angle + angleStart + angleStep * (j - 1)
                local entity = j == 1 and self.sphereEntities[i] or self.sphereEntities[i]:copy()
                _Game.level:spawnShotSphere(self, pos.x, pos.y, angle, self:getSphereSize(), self.color, self:getShootingSpeed(), entity, self.homingBugsTime > 0)
                _Game.level:markSphereShot()
            end
            self.sphereEntities[i] = nil
            if shotBehavior.gameEvent then
                _Game:executeGameEvent(shotBehavior.gameEvent)
            end
        elseif shotBehavior.type == "destroySpheres" then
            -- lightning spheres are not shot, they're deployed instantly
            local pos = self:getSpherePos(i)
            if sphereConfig.destroyParticle then
                _Game:spawnParticle(sphereConfig.destroyParticle, pos.x, pos.y)
            end
            _Game.level:destroySelector(shotBehavior.selector, pos, shotBehavior.scoreEvent, shotBehavior.scoreEventPerSphere, shotBehavior.gameEvent, shotBehavior.gameEventPerSphere, true)
            _Game.level:markSphereShot()
            self:destroySphereEntities()
        end
    end

    -- Apply any effects to the sphere if it has one.
    if sphereConfig.shotEffects then
        for i, effect in ipairs(sphereConfig.shotEffects) do
            _Game.level:applyEffect(effect)
        end
    end

    -- Deal the knockback.
    if self.config.knockback and self.knockbackTime == 0 then
        self.knockbackTime = self.speedShotTime > 0 and self.config.knockback.speedShotDuration or self.config.knockback.duration
        self.knockbackAngle = self.angle
    end

    -- Play the sound, etc.
    _Game:playSound(sphereConfig.shotSound, self.pos.x, self.pos.y)
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
---@param count integer? The amount of spheres of that color to be given. If not specified, an infinite supply will be given.
---@param time number? The time for which the spheres will be able to be generated.
---@param removeWhenTimeOut boolean? If set, when the time expires, the multi-sphere spheres will be removed from the shooter.
---@param holdTimeRate number? The ratio the timer will run at when the fire button is held.
function Shooter:getMultiSphere(color, count, time, removeWhenTimeOut, holdTimeRate)
    if _Game.level.lost then
        return
    end
    self.multiColorColor = color
    self.multiColorCount = count
    self.multiColorTime = time
    self.multiColorRemoveWhenTimeOut = removeWhenTimeOut
    self.multiColorHoldTimeRate = holdTimeRate
    self:setColor(0)
    self:setNextColor(0)
end



---Deactivates the multi-sphere mode and removes all already existing spheres of that type from the shooter.
---@param removeSpheres boolean? If set, removes all instances of the multi-color from the shooter.
function Shooter:removeMultiSphere(removeSpheres)
    if removeSpheres then
        if self.color == self.multiColorColor then
            self:setColor(0)
        end
        if self.nextColor == self.multiColorColor then
            self:setNextColor(0)
        end
    end
    self.multiColorColor = nil
    self.multiColorCount = nil
    self.multiColorTime = nil
    self.multiColorRemoveWhenTimeOut = nil
    self.multiColorHoldTimeRate = nil
end





---Drawing callback function.
function Shooter:draw()
    local pos = self:getVisualPos()
    if self.config.shadowSprite then
        local x, y = _V.rotate(self.config.shadowSpriteOffset.x, self.config.shadowSpriteOffset.y, self.angle)
        self.config.shadowSprite:draw(pos.x + x, pos.y + y, self.config.shadowSpriteAnchor.x, self.config.shadowSpriteAnchor.y, nil, nil, self.angle)
    end
    local x, y = _V.rotate(self.config.spriteOffset.x, self.config.spriteOffset.y, self.angle)
    self.config.sprite:draw(pos.x + x, pos.y + y, self.config.spriteAnchor.x, self.config.spriteAnchor.y, nil, nil, self.angle)

    -- retical
    if _EngineSettings:getAimingRetical() then
        self:drawReticle()
    end

    -- this color
    for i = 1, self:getSphereCount() do
        local entity = self.sphereEntities[i]
        if entity then
            local entityPos = self:getSpherePos(i)
            entity:setPos(entityPos.x, entityPos.y)
            entity:setAngle(self.angle)
            entity:setScale(self:getSphereSize() / 32)
            entity:setAlpha(self:getSphereAlpha())
            entity:draw()
        end
    end
    -- next color
    local nextSpriteConfig = self.config.nextBallSprites[self.nextColor] or self.config.nextBallSprites[0]
    local sprite = nextSpriteConfig.sprite
    local nx, ny = _V.rotate(self.config.nextBallOffset.x, self.config.nextBallOffset.y, self.angle)
    sprite:draw(pos.x + nx, pos.y + ny, self.config.nextBallAnchor.x, self.config.nextBallAnchor.y, nil, self:getNextSphereFrame(), self.angle)

	if _Debug.gameDebugVisible then
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
        local maxDistance = self.config.speedShotBeam.sprite.imageSize.y
        local distance = math.min(targetPos and (startPos - targetPos):len() or maxDistance, maxDistance)
        local distanceUnit = distance / maxDistance
        local scale = Vec2(1)
        if self.config.speedShotBeam.renderingType == "scale" then
            -- if we need to scale the beam
            scale.y = distanceUnit
        elseif self.config.speedShotBeam.renderingType == "cut" then
            -- if we need to cut the beam
            -- make a polygon: determine all four corners first
            local p1 = startPos + Vec2(-self.config.speedShotBeam.sprite.imageSize.x / 2, -distance):rotate(self.angle)
            local p2 = startPos + Vec2(self.config.speedShotBeam.sprite.imageSize.x / 2, -distance):rotate(self.angle)
            local p3 = startPos + Vec2(self.config.speedShotBeam.sprite.imageSize.x / 2, 16):rotate(self.angle)
            local p4 = startPos + Vec2(-self.config.speedShotBeam.sprite.imageSize.x / 2, 16):rotate(self.angle)
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
        local x, y = _V.rotate(0, 16, self.angle)
        self.config.speedShotBeam.sprite:draw(startPos.x + x, startPos.y + y, 0.5, 1, nil, nil, self.angle, color, self.speedShotAnim, scale.x, scale.y)
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
    local retConfig = self.config.reticle
    if targetPos and sphereConfig.shotBehavior.type == "normal" then
        if retConfig.sprite then
            local x, y = _V.rotate(retConfig.offset.x or 0, retConfig.offset.y or 0, self.angle)
            local locationX, locationY = targetPos.x + x, targetPos.y + y
            retConfig.sprite:draw(locationX, locationY, 0.5, 0, nil, nil, self.angle, color)
            if retConfig.nextBallSprite then
                local nextColor = self:getNextReticleColor()
                local nx, ny = _V.rotate(retConfig.nextBallOffset.x or 0, retConfig.nextBallOffset.y or 0, self.angle)
                local nextLocationX, nextLocationY = locationX + nx, locationY + ny
                retConfig.nextBallSprite:draw(nextLocationX, nextLocationY, 0.5, 0, nil, nil, self.angle, nextColor)
            end
        else
            love.graphics.setLineWidth(3)
            love.graphics.setColor(color.r, color.g, color.b)
            local p1 = targetPos + Vec2(-8, 8):rotate(self.angle)
            local p2 = targetPos
            local p3 = targetPos + Vec2(8, 8):rotate(self.angle)
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
            love.graphics.line(p2.x, p2.y, p3.x, p3.y)
        end

        -- Fireball range highlight
        -- TODO: There is no `range` parameter, since we are using Sphere Selectors. Now what?
        if sphereConfig.hitBehavior.type == "fireball" or sphereConfig.hitBehavior.type == "colorCloud" then
            if retConfig.radiusSprite then
                local locationX, locationY = targetPos.x + (retConfig.offset.x or 0), targetPos.y + (retConfig.offset.y or 0)
                local scaleX, scaleY = sphereConfig.hitBehavior.range * 2 / retConfig.radiusSprite.imageSize.x, sphereConfig.hitBehavior.range * 2 / retConfig.radiusSprite.imageSize.y
                retConfig.radiusSprite:draw(locationX, locationY, 0.5, 0.5, nil, nil, nil, color, nil, scaleX, scaleY)
            else
                --love.graphics.setColor(1, 0, 0)
                local dotCount = math.ceil(sphereConfig.hitBehavior.range / 12) * 4
                for i = 1, dotCount do
                    local angle = (2 * i * math.pi / dotCount) + _TotalTime / 2
                    local p = targetPos + Vec2(sphereConfig.hitBehavior.range, 0):rotate(angle)
                    love.graphics.circle("fill", p.x, p.y, 2)
                end
                --love.graphics.setLineWidth(3)
                --love.graphics.circle("line", p2.x, p2.y, sphereConfig.hitBehavior.range)
            end
        end
    end
end



---Draws this Shooter's hitbox.
function Shooter:drawDebug()
    local p = self.pos + self.config.hitboxOffset - self.config.hitboxSize / 2
    local s = self.config.hitboxSize
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
            local pos = self:getSpherePos(i)
            self.sphereEntities[i] = SphereEntity(pos.x, pos.y, self.color)
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



---Destroys all sphere hold particles from this Shooter.
function Shooter:destroySphereHoldParticles()
    for i = 1, self:getSphereCount() do
        if self.sphereHoldParticles[i] then
            self.sphereHoldParticles[i]:destroy()
            self.sphereHoldParticles[i] = nil
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
    local config = _Game.resourceManager:getSphereConfig("spheres/sphere_" .. color .. ".json")
    if config.colorPalette then
        return config.colorPalette:getColor(_TotalTime * config.colorPaletteSpeed)
    elseif config.color then
        return Color(config.color.r, config.color.g, config.color.b)
    end
    error("Sphere error: Sphere of color " .. color .. " has neither `colorPalette` nor `color` fields set; one of them must exist")
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
    return _Game.level:getNearestSphereOnLine(self.pos.x, self.pos.y, self.angle).targetPos
end



---Returns the reticle position, starting from the given sphere.
---@param n integer The main slot number for the sphere to be checked for.
---@return Vector2
function Shooter:getTargetPosForSphere(n)
    local spherePos = self:getSpherePos(n)
    return _Game.level:getNearestSphereOnLine(spherePos.x, spherePos.y, self.angle).targetPos
end



---Returns the current effective shooting speed.
---@return number
function Shooter:getShootingSpeed()
    local sphereSpeed = self:getSphereConfig().shotSpeed
    if sphereSpeed then
        return sphereSpeed
    elseif self.speedShotTime > 0 then
        return self.speedShotSpeed
    end
    return self.config.shotSpeed
end



---Returns the config of the current sphere.
---@return SphereConfig
function Shooter:getSphereConfig()
    return _Game.resourceManager:getSphereConfig("spheres/sphere_" .. self.color .. ".json")
end



---Returns the config of the next sphere.
---@return SphereConfig
function Shooter:getNextSphereConfig()
    return _Game.resourceManager:getSphereConfig("spheres/sphere_" .. self.nextColor .. ".json")
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
        self.shotPressed = true
    elseif button == 2 then
        self:swapColors()
    end
end



---Callback from `main.lua`.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button which was released.
function Shooter:mousereleased(x, y, button)
    if button == 1 then
        self.shotPressed = false
    end
end



---Callback from `main.lua`.
---@param key string The pressed key code.
function Shooter:keypressed(key)
    if key == "left" then
        self.moveKeys.left = true
    elseif key == "right" then
        self.moveKeys.right = true
    elseif key == "up" then
        self:shoot()
        self.shotPressed = true
    elseif key == "down" then
        self:swapColors()
    end
end



---Callback from `main.lua`.
---@param key string The released key code.
function Shooter:keyreleased(key)
    if key == "left" then
        self.moveKeys.left = false
    elseif key == "right" then
        self.moveKeys.right = false
    elseif key == "up" then
        self.shotPressed = false
    end
end



---Resets the values for when the level is restarted.
function Shooter:reset()
    self.speedShotTime = 0
    self.homingBugsTime = 0
end



---Serializes this Shooter's data for saving purposes.
---@return table
function Shooter:serialize()
    return {
        color = self.color,
        nextColor = self.nextColor,
        shotCooldown = self.shotCooldown,
        shotCooldownFade = self.shotCooldownFade,
        shotCooldownSphere = self.shotCooldownSphere,
        multiColorColor = self.multiColorColor,
        multiColorCount = self.multiColorCount,
        multiColorTime = self.multiColorTime,
        multiColorRemoveWhenTimeOut = self.multiColorRemoveWhenTimeOut,
        multiColorHoldTimeRate = self.multiColorHoldTimeRate,
        speedShotTime = self.speedShotTime,
        speedShotSpeed = self.speedShotSpeed,
        homingBugsTime = self.homingBugsTime
    }
end



---Deserializes and loads previosly saved serialized data.
---@param t table
function Shooter:deserialize(t)
    self.color = t.color
    self.nextColor = t.nextColor
    self.shotCooldown = t.shotCooldown
    self.shotCooldownFade = t.shotCooldownFade
    self.shotCooldownSphere = t.shotCooldownSphere
    self.multiColorColor = t.multiColorColor
    self.multiColorCount = t.multiColorCount
    self.multiColorTime = t.multiColorTime
    self.multiColorRemoveWhenTimeOut = t.multiColorRemoveWhenTimeOut
    self.multiColorHoldTimeRate = t.multiColorHoldTimeRate
    self.speedShotTime = t.speedShotTime
    self.speedShotSpeed = t.speedShotSpeed
    self.homingBugsTime = t.homingBugsTime

    self.reticleColor = t.color
    self.reticleNextColor = t.nextColor

    self:spawnSphereEntities()
end



return Shooter
