local class = require "class"
local Shooter = class:derive("Shooter")

local Vec2 = require("Essentials/Vector2")
local Image = require("Essentials/Image")
local Color = require("Essentials/Color")
local Sprite = require("Sprite")

local ShotSphere = require("ShotSphere")

function Shooter:new()
	self.pos = Vec2(0, 526)
	self.posMouse = self.pos:clone()
	self.color = 0
	self.nextColor = 0
	self.active = false -- when the sphere is shot you can't shoot; same for start, win, lose
	self.speedShotTime = 0
	
	-- memorizing the pressed keys for keyboard control of the shooter
	self.moveKeys = {left = false, right = false}
	-- the speed of the shooter when controlled via keyboard
	self.moveKeySpeed = 500
	
	self.sprite = Sprite("sprites/shooter.json")
	self.speedShotImage = game.resourceBank:getImage("img/particles/speed_shot_beam.png")
	
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
		if game.session.sphereColorCounts[self.color] == 0 then self.color = 0 end
		if game.session.sphereColorCounts[self.nextColor] == 0 then self.nextColor = 0 end
		self:fill()
	end
	
	-- speed shot time counting
	if self.speedShotTime > 0 then self.speedShotTime = math.max(self.speedShotTime - dt, 0) end
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

function Shooter:shoot()
	-- if nothing to shoot, it's pointless
	if game.session.level.pause or not self.active or self.color == 0 then return end
	local sound = "normal"
	if self.color == -1 then sound = "wild" end
	if self.color == -2 then sound = "fire" end
	if self.color == -3 then sound = "lightning" end
	if self.color == -3 then
		-- lightning spheres are not shot, they're deployed instantly
		game:spawnParticle("particles/lightning_beam.json", Vec2(self.pos.x, 250))
		game.session:destroyVertical(self.pos.x, 100)
		game.session.level.combo = 0 -- cuz that's how it works
	else
		game.session.level:spawnShotSphere(self, self:spherePos(), self.color, self:getShootingSpeed())
		self.active = false
	end
	self.color = 0
	game.session.level.spheresShot = game.session.level.spheresShot + 1
	game:playSound("sphere_shoot_" .. sound)
end

function Shooter:fill()
	if self.nextColor == 0 then
		self.nextColor = game.session:newSphereColor()
	end
	if self.color == 0 and self.nextColor ~= 0 then
		self.color = self.nextColor
		self.nextColor = game.session:newSphereColor()
	end
end

function Shooter:getColor(color)
	if self.color ~= 0 then
		self.color = color
	elseif self.nextColor ~= 0 then
		self.nextColor = color
	end
end

function Shooter:swapColors()
	-- we must be careful not to swap the spheres when they're absent
	if game.session.level.pause or self.color == 0 or self.nextColor == 0 then return end
	self.color, self.nextColor = self.nextColor, self.color
	game:playSound("shooter_swap")
end



function Shooter:draw()
	self.sprite:draw(self.pos)
	-- retical
	local targetPos = self:getTargetPos()
	if targetPos and (self.color > 0 or self.color == -1 or self.color == -2) then
		love.graphics.setLineWidth(3 * getResolutionScale())
		local color = Color()
		if self.color > 0 then color = SPHERE_COLORS[self.color] end
		if self.color == -1 then color = getRainbowColor(totalTime / 3) end
		if self.color == -2 then color = Color(1, 0.7, 0) end
		love.graphics.setColor(color.r, color.g, color.b)
		local p1 = posOnScreen(targetPos + Vec2(-8, 8))
		local p2 = posOnScreen(targetPos)
		local p3 = posOnScreen(targetPos + Vec2(8, 8))
		love.graphics.line(p1.x, p1.y, p2.x, p2.y)
		love.graphics.line(p2.x, p2.y, p3.x, p3.y)
	end
	-- this color
	-- reverse animation: math.floor(self.sphereFrame + 1)
	-- forward (proper) animation: math.ceil(32 - self.sphereFrame)
	if self.color ~= 0 then game.sphereSprites[self.color]:draw(self:spherePos(), {angle = 0, color = Color(), frame = 1}) end
	-- next color
	game.nextSphereSprites[self.nextColor]:draw(self.pos + Vec2(0, 21))
	
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
		local s = posOnScreen(Vec2(self.speedShotImage.size.x, distance))
		love.graphics.setScissor(p.x, p.y, s.x, s.y)
	end
	-- draw the beam
	self.speedShotImage:draw(self:spherePos(), Vec2(0.5, 1), nil, nil, nil, self.speedShotTime * 2, scale)
	-- reset the scissor
	if self.settings.speedShotBeamRenderingType == "cut" then
		love.graphics.setScissor()
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
	return self.speedShotTime > 0 and self.settings.speedShotSpeed or self.settings.shotSpeed
end



function Shooter:serialize()
	return {
		color = self.color,
		nextColor = self.nextColor,
		speedShotTime = self.speedShotTime
	}
end

function Shooter:deserialize(t)
	self.color = t.color
	self.nextColor = t.nextColor
	self.speedShotTime = t.speedShotTime
end

return Shooter