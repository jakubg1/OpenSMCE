local class = require "class"
local ShotSphere = class:derive("ShotSphere")

local Vec2 = require("Essentials/Vector2")
local Image = require("Essentials/Image")
local Color = require("Essentials/Color")

function ShotSphere:new(shooter, pos, color, speed)
	self.shooter = shooter
	
	self.PIXELS_PER_STEP = 8
	
	self.pos = pos
	self.steps = 0
	self.color = color
	self.speed = speed
	
	self.sprite = game.sphereSprites[color]
	
	self.hitTime = 0
	self.hitSphere = nil
	
	self.delQueue = false
end

function ShotSphere:update(dt)
	if self.hitSphere then
		-- increment the timer
		self.hitTime = self.hitTime + dt
		-- if the timer expired, destroy the entity and add the ball to the chain
		if self.hitTime >= 0.15 then self.delQueue = true end
	else
		-- move
		self.steps = self.steps + self.speed * dt / self.PIXELS_PER_STEP
		while self.steps > 0 and not self.hitSphere do self:moveStep() end
	end
end

-- by default, 1 step = 1 px
-- you can do more pixels if it's not efficient (laggy), but that will decrease the accuracy
function ShotSphere:moveStep()
	self.steps = self.steps - 1
	self.pos.y = self.pos.y - self.PIXELS_PER_STEP
	-- add if there's a sphere nearby
	local nearestSphere = game.session:getNearestSphereY(self.pos)
	if nearestSphere.dist and nearestSphere.dist.y < 32 then
		if self.color == -2 then
			game.session:destroyRadius(self.pos, 125)
			self.delQueue = true
			game:playSound("sphere_hit_fire")
		else
			self.hitSphere = nearestSphere
			if self.hitSphere.half then self.hitSphere.sphereID = self.hitSphere.sphereID + 1 end
			self.hitSphere.sphereID = self.hitSphere.sphereGroup:addSpherePos(self.hitSphere.sphereID)
			self.hitSphere.sphereGroup:addSphere(self.pos, self.hitSphere.sphereID, self.color)
			game:playSound("sphere_hit_normal")
		end
	end
	-- delete if outside of the board
	if self.pos.y < -16 then
		self.delQueue = true
		game.session.level.combo = 0
	end
end



function ShotSphere:draw()
	if not self.hitSphere then
		self.sprite:draw(self.pos, {angle = 0, color = Color(), frame = 1})
	end
end

return ShotSphere