local class = require "com/class"
local Shooter = class:derive("Shooter")

local Vec2 = require("src/Essentials/Vector2")
local Image = require("src/Essentials/Image")
local Color = require("src/Essentials/Color")

local SphereEntity = require("src/SphereEntity")
local ShotSphere = require("src/ShotSphere")

function Shooter:new()
	self.pos = Vec2(0, 526)
	self.posMouse = self.pos:clone()
	self.color = 0
	self.nextColor = 0
	self.active = false -- when the sphere is shot you can't shoot; same for start, win, lose
	self.speedShotTime = 0
	self.speedShotSpeed = 0

	self.multiColorColor = nil
	self.multiColorCount = 0

	-- memorizing the pressed keys for keyboard control of the shooter
	self.moveKeys = {left = false, right = false}
	-- the speed of the shooter when controlled via keyboard
	self.moveKeySpeed = 500

	self.shadowImage = game.resourceManager:getImage("img/game/shooter_shadow.png")
	self.image = game.resourceManager:getImage("img/game/shooter.png")
	self.speedShotImage = game.resourceManager:getImage("img/particles/speed_shot_beam.png")

	self.sphereEntity = nil

	self.settings = game.config.gameplay.shooter
end



function Shooter:update(dt)
	-- movement
	-- how many pixels will the shooter move since the last frame (by mouse)?
	local shooterDelta = self:getDelta(mousePos.x, true)
	if shooterDelta == 0 then
		-- if 0, then the keyboard can be freely used
		if self.moveKeys.left then self:move(self.pos.x - self.moveKeySpeed * dt, false) end
		if self.moveKeys.right then self:move(self.pos.x + self.moveKeySpeed * dt, false) end
	else
		-- else, the mouse takes advantage and overwrites the position
		self:move(mousePos.x, true)
	end

	-- filling
	if self.active then
		-- remove inexistant colors
		if not game.session.colorManager:isColorExistent(self.color) then self:setColor(0) end
		if not game.session.colorManager:isColorExistent(self.nextColor) then self:setNextColor(0) end
		self:fill()
	end

	-- speed shot time counting
	if self.speedShotTime > 0 then self.speedShotTime = math.max(self.speedShotTime - dt, 0) end

	-- particle position update
	if self.sphereEntity then
		self.sphereEntity:setPos(self:spherePos())
	end
end



function Shooter:translatePos(x)
	return math.min(math.max(x, 20), NATIVE_RESOLUTION.x - 20)
end

function Shooter:move(x, fromMouse)
	if game.session.level.pause then return end
	self.pos.x = self:translatePos(x)
	if fromMouse then self.posMouse.x = self:translatePos(x) end
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
	if game.session.level.pause or self.color == 0 or self.nextColor == 0 or not game.spheres[self.color].interchangeable then return end
	local tmp = self.color
	self:setColor(self.nextColor)
	self:setNextColor(tmp)
	game:playSound("shooter_swap")
end

function Shooter:getNextColor()
	if self.multiColorCount == 0 then
		return game.session.colorManager:pickColor()
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

function Shooter:shoot()
	-- if nothing to shoot, it's pointless
	if game.session.level.pause or not self.active or self.color == 0 then return end

	local sphereConfig = game.spheres[self.color]
	if sphereConfig.shootBehavior.type == "lightning" then
		-- lightning spheres are not shot, they're deployed instantly
		game:spawnParticle(sphereConfig.destroyParticle, self:spherePos())
		game.session:destroyVerticalColor(self.pos.x, sphereConfig.shootBehavior.range, self.color)
		if sphereConfig.shootBehavior.resetCombo then
			game.session.level.combo = 0 -- cuz that's how it works
		end
	else
		game.session.level:spawnShotSphere(self, self:spherePos(), self.color, self:getShootingSpeed())
		self.sphereEntity = nil
		self.active = false
	end
	game:playSound(sphereConfig.shootSound)
	self.color = 0
	game.session.level.spheresShot = game.session.level.spheresShot + 1
	--game.session.level.lightningStormCount = 0
	--game.session.level.lightningStormTime = 0
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
	self.shadowImage:draw(self.pos + Vec2(8, 8), Vec2(0.5, 0))
	self.image:draw(self.pos, Vec2(0.5, 0))

	-- retical
	if engineSettings:getAimingRetical() then
		local targetPos = self:getTargetPos()
		local color = self:getReticalColor()
		local sphereConfig = game.spheres[self.color]
		if targetPos and self.color ~= 0 and sphereConfig.shootBehavior.type == "normal" then
			love.graphics.setLineWidth(3 * getResolutionScale())
			love.graphics.setColor(color.r, color.g, color.b)
			local p1 = posOnScreen(targetPos + Vec2(-8, 8))
			local p2 = posOnScreen(targetPos)
			local p3 = posOnScreen(targetPos + Vec2(8, 8))
			love.graphics.line(p1.x, p1.y, p2.x, p2.y)
			love.graphics.line(p2.x, p2.y, p3.x, p3.y)

			-- Fireball range highlight
			if sphereConfig.hitBehavior.type == "fireball" or sphereConfig.hitBehavior.type == "colorCloud" then
				--love.graphics.setColor(1, 0, 0)
				local dotCount = math.ceil(sphereConfig.hitBehavior.range / 12) * 4
				for i = 1, dotCount do
					local angle = (2 * i * math.pi / dotCount) + totalTime / 2
					local p = posOnScreen(targetPos + Vec2(sphereConfig.hitBehavior.range, 0):rotate(angle))
					love.graphics.circle("fill", p.x, p.y, 2 * getResolutionScale())
				end
				--love.graphics.setLineWidth(3 * getResolutionScale())
				--love.graphics.circle("line", p2.x, p2.y, sphereConfig.hitBehavior.range)
			end
		end
	end

	-- this color
	if self.sphereEntity then
		local frame = self.sphereEntity.config.imageAnimationSpeed and Vec2(math.floor(self.sphereEntity.config.imageAnimationSpeed * totalTime), 1) or Vec2(1)
		self.sphereEntity.frame = frame
		self.sphereEntity:draw()
	end
	-- next color
	game.resourceManager:getImage(game.spheres[self.nextColor].nextImage):draw(self.pos + Vec2(0, 21), Vec2(0.5, 0))

	--local p4 = posOnScreen(self.pos)
	--love.graphics.rectangle("line", p4.x - 80, p4.y - 15, 160, 30)
end

function Shooter:drawSpeedShotBeam()
	-- rendering options:
	-- "full" - the beam is always fully visible
	-- "cut" - the beam is cut on the target position
	-- "scale" - the beam is squished between the shooter and the target position
	if self.speedShotTime == 0 then return end

	local targetPos = self:getTargetPos()
	local maxDistance = self.speedShotImage.size.y
	local distance = math.min(targetPos and self.pos.y - targetPos.y or self.pos.y, maxDistance)
	local distanceUnit = distance / maxDistance
	local scale = Vec2(1)
	if self.settings.speedShotBeamRenderingType == "scale" then
		-- if we need to scale the beam
		scale.y = distanceUnit
	elseif self.settings.speedShotBeamRenderingType == "cut" then
		-- if we need to cut the beam
		local p = posOnScreen(Vec2(self.pos.x - self.speedShotImage.size.x / 2, self.pos.y - distance))
		local s = posOnScreen(Vec2(self.speedShotImage.size.x, distance + 16))
		love.graphics.setScissor(p.x, p.y, s.x, s.y)
	end
	-- apply color if wanted
	local color = self.settings.speedShotBeamColored and self:getReticalColor() or Color()
	-- draw the beam
	self.speedShotImage:draw(self:spherePos() + Vec2(0, 16), Vec2(0.5, 1), nil, nil, color, self.speedShotTime * 2, scale)
	-- reset the scissor
	if self.settings.speedShotBeamRenderingType == "cut" then
		love.graphics.setScissor()
	end
end



function Shooter:spawnSphereEntity()
	if self.color == 0 or self.sphereEntity then return end
	self.sphereEntity = SphereEntity(self:spherePos(), self.color)
end



function Shooter:getReticalColor()
	local color = game.spheres[self.color].color
	if type(color) == "string" then
		return game.resourceManager:getColorPalette(color):getColor(totalTime * game.spheres[self.color].colorSpeed)
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
	return game.session:getNearestSphereY(self.pos).targetPos
end

function Shooter:getShootingSpeed()
	if game.spheres[self.color].shootSpeed then return game.spheres[self.color].shootSpeed end
	return self.speedShotTime > 0 and self.speedShotSpeed or self.settings.shotSpeed
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
