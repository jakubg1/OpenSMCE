local class = require "com/class"

---@class Shooter
---@overload fun():Shooter
local Shooter = class:derive("Shooter")

local Vec2 = require("src/Essentials/Vector2")
local Sprite = require("src/Essentials/Sprite")
local Color = require("src/Essentials/Color")

local SphereEntity = require("src/SphereEntity")
local ShotSphere = require("src/ShotSphere")



function Shooter:new()
	self.pos = Vec2(0, 526)
	self.posMouse = self.pos:clone()
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
	-- the speed of the shooter when controlled via keyboard
	self.moveKeySpeed = 500

	self.shadowSprite = _Game.resourceManager:getSprite("sprites/game/shooter_shadow.json")
	self.sprite = _Game.resourceManager:getSprite("sprites/game/shooter.json")
	self.speedShotSprite = _Game.resourceManager:getSprite("sprites/particles/speed_shot_beam.json")

	self.sphereEntity = nil

	self.config = _Game.configManager.gameplay.shooter
end





function Shooter:update(dt)
	-- movement
	-- how many pixels will the shooter move since the last frame (by mouse)?
	local shooterDelta = self:getDelta(_MousePos.x, true)
	if shooterDelta == 0 then
		-- if 0, then the keyboard can be freely used
		if self.moveKeys.left then
			self:move(self.pos.x - self.moveKeySpeed * dt, false)
		end
		if self.moveKeys.right then
			self:move(self.pos.x + self.moveKeySpeed * dt, false)
		end
	else
		-- else, the mouse takes advantage and overwrites the position
		self:move(_MousePos.x, true)
	end

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
		self.speedShotAnim = math.min(self.speedShotAnim + dt / self.config.speedShotBeamFadeTime, 1)
		if self.speedShotParticle then
			self.speedShotParticle.pos = self:spherePos()
		else
			self.speedShotParticle = _Game:spawnParticle(self.config.speedShotParticle, self:spherePos())
		end
	else
		self.speedShotAnim = math.max(self.speedShotAnim - dt / self.config.speedShotBeamFadeTime, 0)
		if self.speedShotParticle then
			self.speedShotParticle:destroy()
			self.speedShotParticle = nil
		end
	end

	-- Update the sphere entity position.
	if self.sphereEntity then
		self.sphereEntity:setPos(self:spherePos())
	end
end



function Shooter:translatePos(x)
	return math.min(math.max(x, 20), _NATIVE_RESOLUTION.x - 20)
end



function Shooter:move(x, fromMouse)
	-- Cannot move when the level is paused.
	if _Game.session.level.pause then
		return
	end
	self.pos.x = self:translatePos(x)
	if fromMouse then
		self.posMouse.x = self:translatePos(x)
	end
end



function Shooter:getDelta(x, fromMouse)
	if fromMouse then
		return self:translatePos(x) - self.posMouse.x
	else
		return self:translatePos(x) - self.pos.x
	end
end



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
			self.sphereEntity = SphereEntity(self:spherePos(), color)
		end
	end
end



function Shooter:setNextColor(color)
	self.nextColor = color
end



function Shooter:empty()
	self.active = false
	self:setColor(0)
	self:setNextColor(0)
	self.multiColorColor = nil
	self.multiColorCount = 0
	self.speedShotTime = 0
end



function Shooter:swapColors()
	-- we must be careful not to swap the spheres when they're absent
	if _Game.session.level.pause or self.color == 0 or self.nextColor == 0 or not self:getSphereConfig().interchangeable then
		return
	end
	local tmp = self.color
	self:setColor(self.nextColor)
	self:setNextColor(tmp)
	_Game:playSound("sound_events/shooter_swap.json", 1, self.pos)
end



function Shooter:getNextColor()
	if self.multiColorCount == 0 then
		return _Game.session.level:getNewShooterColor()
	else
		self.multiColorCount = self.multiColorCount - 1
		return self.multiColorColor
	end
end



function Shooter:fill()
	if self.nextColor == 0 then
		self:setNextColor(self:getNextColor())
	end
	if self.color == 0 and self.nextColor ~= 0 then
		self:setColor(self.nextColor)
		self:setNextColor(self:getNextColor())
	end
end



function Shooter:activate()
	self.active = true
	_Game:playSound("sound_events/shooter_fill.json", 1, self.pos)
end



function Shooter:shoot()
	-- if nothing to shoot, it's pointless
	if _Game.session.level.pause or not self.active or self.color == 0 then
		return
	end

	local sphereConfig = self:getSphereConfig()
	if sphereConfig.shootBehavior.type == "lightning" then
		-- lightning spheres are not shot, they're deployed instantly
		_Game:spawnParticle(sphereConfig.destroyParticle, self:spherePos())
		_Game.session:destroyVerticalColor(self.pos.x, sphereConfig.shootBehavior.range, self.color)
	else
		_Game.session.level:spawnShotSphere(self, self:spherePos(), self.color, self:getShootingSpeed())
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



function Shooter:destroy()
	if self.sphereEntity then
		self.sphereEntity:destroy(false)
	end
end



function Shooter:getSphere(color)
	if self.color ~= 0 then
		self:setColor(color)
	elseif self.nextColor ~= 0 then
		self:setNextColor(color)
	end
end



function Shooter:getMultiSphere(color, count)
	self.multiColorColor = color
	self.multiColorCount = count
	self:setColor(0)
	self:setNextColor(0)
end





function Shooter:draw()
	self.shadowSprite:draw(self.pos + Vec2(8, 8), Vec2(0.5, 0))
	self.sprite:draw(self.pos, Vec2(0.5, 0))

	-- retical
	if _EngineSettings:getAimingRetical() then
		local targetPos = self:getTargetPos()
		local color = self:getReticalColor()
		local sphereConfig = self:getSphereConfig()
		if targetPos and self.color ~= 0 and sphereConfig.shootBehavior.type == "normal" then
            if self.config.reticleSprite then
                local reticle = _Game.resourceManager:getSprite(self.config.reticleSprite)
				local location = _PosOnScreen(targetPos)
				local offset = _ParseVec2(self.config.reticleOffset or {x=0,y=0})
				location.x = location.x + offset.x
				location.y = location.y + offset.y
                reticle:draw(location, Vec2(0.5, 0), nil, nil, nil, color)
				if self.config.reticleNextBallSprite then
                    local next = _Game.resourceManager:getSprite(self.config.reticleNextBallSprite)
                    local nextColor = self:getNextReticalColor()
                    -- Have the location be relative to the shooter, default to
					-- it's top-left just like assigning shooter's nextBall
					local nextBallOffset = _ParseVec2(self.config.reticleNextBallOffset or {x=0,y=0})
                    local relativeLocation = location
                    relativeLocation.x = location.x - (reticle.size.x / 2) + nextBallOffset.x
					relativeLocation.y = location.y + nextBallOffset.y
					next:draw(relativeLocation, Vec2(0,0), nil, nil, nil, nextColor)
				end
            else
				love.graphics.setLineWidth(3 * _GetResolutionScale())
				love.graphics.setColor(color.r, color.g, color.b)
				local p1 = _PosOnScreen(targetPos + Vec2(-8, 8))
				local p2 = _PosOnScreen(targetPos)
				local p3 = _PosOnScreen(targetPos + Vec2(8, 8))
				love.graphics.line(p1.x, p1.y, p2.x, p2.y)
				love.graphics.line(p2.x, p2.y, p3.x, p3.y)
			end

			--_Game.resourceManager.

			-- TODO: Add custom reticle support ~Shambles_SM

			-- Fireball range highlight
			if sphereConfig.hitBehavior.type == "fireball" or sphereConfig.hitBehavior.type == "colorCloud" then
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

	-- this color
	if self.sphereEntity then
		self.sphereEntity.frame = self:getSphereFrame()
		self.sphereEntity:draw()
	end
	-- next color
	local sprite = _Game.resourceManager:getSprite(self:getNextSphereConfig().nextSprite)
	local frame = self:getNextSphereFrame()
	sprite:draw(self.pos + Vec2(0, 21), Vec2(0.5, 0), nil, frame)

	--local p4 = posOnScreen(self.pos)
	--love.graphics.rectangle("line", p4.x - 80, p4.y - 15, 160, 30)
end



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
	local distance = math.min(targetPos and self.pos.y - targetPos.y or self.pos.y, maxDistance)
	local distanceUnit = distance / maxDistance
	local scale = Vec2(1)
	if self.config.speedShotBeamRenderingType == "scale" then
		-- if we need to scale the beam
		scale.y = distanceUnit
	elseif self.config.speedShotBeamRenderingType == "cut" then
		-- if we need to cut the beam
		local p = _PosOnScreen(Vec2(self.pos.x - self.speedShotSprite.size.x / 2, self.pos.y - distance))
		local s = _PosOnScreen(Vec2(self.speedShotSprite.size.x, distance + 16))
		love.graphics.setScissor(p.x, p.y, s.x, s.y)
	end
	-- apply color if wanted
	local color = self.config.speedShotBeamColored and self:getReticalColor() or Color()
	-- draw the beam
	self.speedShotSprite:draw(self:spherePos() + Vec2(0, 16), Vec2(0.5, 1), nil, nil, nil, color, self.speedShotAnim, scale)
	-- reset the scissor
	if self.config.speedShotBeamRenderingType == "cut" then
		love.graphics.setScissor()
	end
end



function Shooter:spawnSphereEntity()
	if self.color == 0 or self.sphereEntity then
		return
	end
	self.sphereEntity = SphereEntity(self:spherePos(), self.color)
end



function Shooter:getReticalColor()
	local color = self:getSphereConfig().color
	if type(color) == "string" then
		return _Game.resourceManager:getColorPalette(color):getColor(_TotalTime * self:getSphereConfig().colorSpeed)
	else
		return color
	end
end


function Shooter:getNextReticalColor()
	local color = self:getNextSphereConfig().color
	if type(color) == "string" then
		return _Game.resourceManager:getColorPalette(color):getColor(_TotalTime * self:getSphereConfig().colorSpeed)
	else
		return color
	end
end

function Shooter:spherePos()
	return self.pos - Vec2(0, -5)
end



function Shooter:catchablePos(pos)
	return math.abs(self.pos.x - pos.x) < 80 and math.abs(self.pos.y - pos.y) < 15
end



function Shooter:getTargetPos()
	return _Game.session:getNearestSphereY(self.pos).targetPos
end



function Shooter:getShootingSpeed()
	local sphereSpeed = self:getSphereConfig().shootSpeed
	if sphereSpeed then
		return sphereSpeed
	elseif self.speedShotTime > 0 then
		return self.speedShotSpeed
	end
	return self.config.shotSpeed
end



-- Returns config for the current sphere.
function Shooter:getSphereConfig()
	return _Game.configManager.spheres[self.color]
end



-- Returns config for the next sphere.
function Shooter:getNextSphereConfig()
	return _Game.configManager.spheres[self.nextColor]
end



-- Returns the current sphere's animation frame.
function Shooter:getSphereFrame()
	local animationSpeed = self:getSphereConfig().spriteAnimationSpeed
	if animationSpeed then
		return Vec2(math.floor(animationSpeed * _TotalTime), 1)
	end
	return Vec2(1)
end



-- Returns the next sphere's animation frame.
function Shooter:getNextSphereFrame()
	local animationSpeed = self:getNextSphereConfig().nextSpriteAnimationSpeed
	if animationSpeed then
		return Vec2(math.floor(animationSpeed * _TotalTime), 1)
	end
	return Vec2(1)
end



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
