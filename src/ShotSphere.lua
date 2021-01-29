local class = require "com/class"
local ShotSphere = class:derive("ShotSphere")

local Vec2 = require("src/Essentials/Vector2")
local Image = require("src/Essentials/Image")
local Color = require("src/Essentials/Color")

local SphereEntity = require("src/SphereEntity")

function ShotSphere:new(deserializationTable, shooter, pos, color, speed)
	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.shooter = shooter
		self.pos = pos
		self.steps = 0
		self.color = color
		self.speed = speed
		self.sphereEntity = shooter.sphereEntity
	
		self.hitTime = 0
		self.hitSphere = nil
	end
	
	self.PIXELS_PER_STEP = 8
	
	self.delQueue = false
end

function ShotSphere:update(dt)
	if self.hitSphere then
		-- increment the timer
		self.hitTime = self.hitTime + dt
		-- if the timer expired, destroy the entity and add the ball to the chain
		if self.hitTime >= 0.15 then self:destroy() end
	else
		-- move
		self.steps = self.steps + self.speed * dt / self.PIXELS_PER_STEP
		while self.steps > 0 and not self.hitSphere and not self.delQueue do self:moveStep() end
	end
end

-- by default, 1 step = 1 px
-- you can do more pixels if it's not efficient (laggy), but that will decrease the accuracy
function ShotSphere:moveStep()
	self.steps = self.steps - 1
	self.pos.y = self.pos.y - self.PIXELS_PER_STEP
	-- add if there's a sphere nearby
	-- old collission detection system:
	--local nearestSphere = game.session:getNearestSphereY(self.pos)
	--if nearestSphere.dist and nearestSphere.dist.y < 32 then
	local nearestSphere = game.session:getNearestSphere(self.pos)
	if nearestSphere.dist and nearestSphere.dist < 32 then
		self.hitSphere = nearestSphere
		local sphereConfig = game.spheres[self.color]
		local hitColor = self.hitSphere.sphereGroup.spheres[self.hitSphere.sphereID].color
		local badShot = false
		if sphereConfig.hitBehavior.type == "destroySphere" then
			if game.session:colorsMatch(self.color, hitColor) then
				game.session:destroySingleSphere(self.hitSphere.sphere)
			end
			self:destroy()
			game:spawnParticle(sphereConfig.destroyParticle, self.pos)
		elseif sphereConfig.hitBehavior.type == "fireball" then
			game.session:destroyRadiusColor(self.pos, sphereConfig.hitBehavior.range, self.color)
			self:destroy()
			game:spawnParticle(sphereConfig.destroyParticle, self.pos)
		elseif sphereConfig.hitBehavior.type == "colorCloud" then
			game.session:replaceColorRadiusColor(self.pos, sphereConfig.hitBehavior.range, self.color, sphereConfig.hitBehavior.color)
			self:destroy()
			game:spawnParticle(sphereConfig.destroyParticle, self.pos)
		elseif sphereConfig.hitBehavior.type == "replaceColor" then
			self.hitSphere.sphereID = self.hitSphere.sphereGroup:addSpherePos(self.hitSphere.sphereID)
			game.session:replaceColor(hitColor, sphereConfig.hitBehavior.color, sphereConfig.hitBehavior.particle)
			self:destroy()
			game:spawnParticle(sphereConfig.destroyParticle, self.pos)
		else
			if self.hitSphere.half then self.hitSphere.sphereID = self.hitSphere.sphereID + 1 end
			self.hitSphere.sphereID = self.hitSphere.sphereGroup:addSpherePos(self.hitSphere.sphereID)
			self.hitSphere.sphereGroup:addSphere(self.pos, self.hitSphere.sphereID, self.color)
			badShot = self.hitSphere.sphereGroup:getMatchLengthInChain(self.hitSphere.sphereID) == 1 and sphereConfig.hitSoundBad
		end
		game:playSound(badShot and sphereConfig.hitSoundBad or sphereConfig.hitSound)
	end
	-- delete if outside of the board
	if self.pos.y < -16 then
		self:destroy()
		game.session.level.combo = 0
	end
end

function ShotSphere:destroy()
	if self.delQueue then return end
	self._list:destroy(self)
	self.sphereEntity:destroy(false)
	self.delQueue = true
	self.shooter.active = true
	game:playSound("shooter_fill")
end



function ShotSphere:draw()
	if not self.hitSphere then
		self.sphereEntity:setPos(self.pos)
		self.sphereEntity:draw(true)
		self.sphereEntity:draw()
		--self:drawDebug()
	end
end

function ShotSphere:drawDebug()
	love.graphics.setColor(0, 1, 1)
	for i = self.pos.y, 0, -self.PIXELS_PER_STEP do
		local p = posOnScreen(Vec2(self.pos.x, i))
		love.graphics.circle("fill", p.x, p.y, 2)
		local nearestSphere = game.session:getNearestSphere(Vec2(self.pos.x, i))
		if nearestSphere.dist and nearestSphere.dist < 32 then
			love.graphics.setLineWidth(3)
			local p = posOnScreen(nearestSphere.pos)
			love.graphics.circle("line", p.x, p.y, 16 * getResolutionScale())
			break
		end
	end
end



function ShotSphere:serialize()
	return {
		pos = {x = self.pos.x, y = self.pos.y},
		color = self.color,
		speed = self.speed,
		steps = self.steps,
		hitSphere = {
			pathID = 1,
			chainID = 2,
			groupID = 1,
			sphereID = 8
		}, -- TODO: add an indexation function in Sphere.lua to resolve this problem
		hitTime = self.hitTime
	}
end

function ShotSphere:deserialize(t)
	self.pos = Vec2(t.pos.x, t.pos.y)
	self.color = t.color
	self.speed = t.speed
	self.steps = t.steps
	
	self.shooter = game.session.level.shooter
	
	self.hitSphere = nil -- blah blah blah, see above
	self.hitTime = t.hitTime
	
	
	
	self.sphereEntity = SphereEntity(self.pos, self.color)
end

return ShotSphere