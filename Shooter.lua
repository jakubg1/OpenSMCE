local class = require "class"
local Shooter = class:derive("Shooter")

local Vec2 = require("Essentials/Vector2")
local Image = require("Essentials/Image")
local Color = require("Essentials/Color")
local Sprite = require("Sprite")

local ShotSphere = require("ShotSphere")
local Particle = require("Particle")

function Shooter:new()
	self.pos = Vec2(0, 526)
	self.posMouse = self.pos:clone()
	self.color = 0
	self.nextColor = 0
	self.active = false -- when the sphere is shot you can't shoot; same for start, win, lose
	self.speedShotTime = 0
	
	self.sprite = Sprite("sprites/shooter.json")
end

function Shooter:update(dt)
	if self.active then
		if game.session.sphereColorCounts[self.color] == 0 then self.color = 0 end
		if game.session.sphereColorCounts[self.nextColor] == 0 then self.nextColor = 0 end
		self:fill()
	end
	if self.speedShotTime > 0 then self.speedShotTime = math.max(self.speedShotTime - dt, 0) end
end

function Shooter:translatePos(x)
	return math.min(math.max(x, 20), NATIVE_RESOLUTION.x - 20)
end

function Shooter:move(x, fromMouse)
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
	if game.session.pause or not self.active or self.color == 0 then return end
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
		table.insert(game.session.shotSpheres, ShotSphere(self, self:spherePos(), self.color, self.speedShotTime > 0 and 2000 or 1000))
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
	if game.session.pause or self.color == 0 or self.nextColor == 0 then return end
	self.color, self.nextColor = self.nextColor, self.color
	game:playSound("shooter_swap")
end



function Shooter:draw()
	self.sprite:draw(self.pos)
	-- this color
	-- reverse animation: math.floor(self.sphereFrame + 1)
	-- forward (proper) animation: math.ceil(32 - self.sphereFrame)
	if self.color ~= 0 then game.sphereSprites[self.color]:draw(self:spherePos(), {angle = 0, color = Color(), frame = 1}) end
	-- next color
	game.nextSphereSprites[self.nextColor]:draw(self.pos + Vec2(0, 21))
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
	
	--local p4 = posOnScreen(self.pos)
	--love.graphics.rectangle("line", p4.x - 80, p4.y - 15, 160, 30)
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

return Shooter