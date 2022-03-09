local class = require "com/class"
local ShotSphere = class:derive("ShotSphere")

local Vec2 = require("src/Essentials/Vector2")
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
		self.hitTimeMax = 0
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
		if self.hitTime >= self.hitTimeMax then self:destroy() end
	else
		-- move
		self.steps = self.steps + self.speed * dt / self.PIXELS_PER_STEP
		while self.steps > 0 and not self.hitSphere and not self.delQueue do self:moveStep() end
	end
end

-- by default, 1 step = 8 px
-- you can do more pixels if it's not efficient (laggy), but that will decrease the accuracy
function ShotSphere:moveStep()
	self.steps = self.steps - 1
	self.pos.y = self.pos.y - self.PIXELS_PER_STEP
	-- add if there's a sphere nearby
	-- old collission detection system:
	--local nearestSphere = game.session:getNearestSphereY(self.pos)
	--if nearestSphere.dist and nearestSphere.dist.y < 32 then
	local nearestSphere = _Game.session:getNearestSphere(self.pos)
	if nearestSphere.dist and nearestSphere.dist < 32 then
		self.hitSphere = nearestSphere
		local sphereConfig = _Game.configManager.spheres[self.color]
		local hitColor = self.hitSphere.sphereGroup.spheres[self.hitSphere.sphereID].color
		local badShot = false
		local shotCancelled = false
		if sphereConfig.hitBehavior.type == "destroySphere" then
			if _Game.session:colorsMatch(self.color, hitColor) then
				_Game.session:destroySingleSphere(self.hitSphere.sphere)
				self:destroy()
				_Game:spawnParticle(sphereConfig.destroyParticle, self.pos)
			else
				shotCancelled = true
			end
		elseif sphereConfig.hitBehavior.type == "fireball" then
			_Game.session:destroyRadiusColor(self.pos, sphereConfig.hitBehavior.range, self.color)
			self:destroy()
			_Game:spawnParticle(sphereConfig.destroyParticle, self.pos)
		elseif sphereConfig.hitBehavior.type == "colorCloud" then
			_Game.session:replaceColorRadiusColor(self.pos, sphereConfig.hitBehavior.range, self.color, sphereConfig.hitBehavior.color)
			self:destroy()
			_Game:spawnParticle(sphereConfig.destroyParticle, self.pos)
		elseif sphereConfig.hitBehavior.type == "replaceColor" then
			self.hitSphere.sphereID = self.hitSphere.sphereGroup:getAddSpherePos(self.hitSphere.sphereID)
			_Game.session:replaceColor(hitColor, sphereConfig.hitBehavior.color, sphereConfig.hitBehavior.particle)
			self:destroy()
			_Game:spawnParticle(sphereConfig.destroyParticle, self.pos)
		else
			if self.hitSphere.half then self.hitSphere.sphereID = self.hitSphere.sphereID + 1 end
			self.hitSphere.sphereID = self.hitSphere.sphereGroup:getAddSpherePos(self.hitSphere.sphereID)
			-- get the desired sphere position
			local p
			if self.hitSphere.sphereID <= #self.hitSphere.sphereGroup.spheres then
				-- the inserted ball is NOT at the end of the group
				p = self.hitSphere.sphereGroup:getSpherePos(self.hitSphere.sphereID)
			else
				-- the inserted ball IS at the end of the group
				local o = self.hitSphere.sphereGroup:getLastSphereOffset() + 32
				p = self.hitSphere.path:getPos(o)
			end
			-- calculate length from the current position
			local d = (self.pos - p):len()
			-- calculate time
			self.hitTimeMax = d / self.speed * 5
			self.hitSphere.sphereGroup:addSphere(self.color, self.pos, self.hitTimeMax, self.hitSphere.sphereID)
			badShot = self.hitSphere.sphereGroup:getMatchLengthInChain(self.hitSphere.sphereID) == 1 and sphereConfig.hitSoundBad
		end
		if shotCancelled then
			self.hitSphere = nil -- avoid deleting this time
		else
			_Game:playSound(badShot and sphereConfig.hitSoundBad or sphereConfig.hitSound, 1, self.pos)
		end
	end
	-- delete if outside of the board
	if self.pos.y < -16 then
		self:destroy()
		_Game.session.level.combo = 0
	end
end

function ShotSphere:getHitSphereIDs()
	if not self.hitSphere then
		return nil
	end

	local s = self.hitSphere
	local g = s.sphereGroup
	local c = g.sphereChain
	local p = c.path
	local m = p.map

	local sphereID = s.sphereID
	local groupID = c:getSphereGroupID(g)
	local chainID = p:getSphereChainID(c)
	local pathID = m:getPathID(p)

	return {
		sphereID = sphereID,
		groupID = groupID,
		chainID = chainID,
		pathID = pathID
	}
end

function ShotSphere:destroy()
	if self.delQueue then return end
	self._list:destroy(self)
	if self.sphereEntity then
		self.sphereEntity:destroy(false)
	end
	self.delQueue = true
	self.shooter:activate()
end



function ShotSphere:draw()
	if not self.hitSphere then
		self.sphereEntity:setPos(self:getDrawPos())
		self.sphereEntity:draw(true)
		self.sphereEntity:draw()
		--self:drawDebug()
	end
end

function ShotSphere:drawDebug()
	love.graphics.setColor(0, 1, 1)
	for i = self.pos.y, 0, -self.PIXELS_PER_STEP do
		local p = _PosOnScreen(Vec2(self.pos.x, i))
		love.graphics.circle("fill", p.x, p.y, 2)
		local nearestSphere = _Game.session:getNearestSphere(Vec2(self.pos.x, i))
		if nearestSphere.dist and nearestSphere.dist < 32 then
			love.graphics.setLineWidth(3)
			local p = _PosOnScreen(nearestSphere.pos)
			love.graphics.circle("line", p.x, p.y, 16 * _GetResolutionScale())
			break
		end
	end
end

function ShotSphere:getDrawPos()
	return self.pos + Vec2(0, -self.steps * self.PIXELS_PER_STEP)
end



function ShotSphere:serialize()
	return {
		pos = {x = self.pos.x, y = self.pos.y},
		color = self.color,
		speed = self.speed,
		steps = self.steps,
		hitSphere = self:getHitSphereIDs(),
		hitTime = self.hitTime,
		hitTimeMax = self.hitTimeMax
	}
end

function ShotSphere:deserialize(t)
	self.pos = Vec2(t.pos.x, t.pos.y)
	self.color = t.color
	self.speed = t.speed
	self.steps = t.steps

	self.shooter = _Game.session.level.shooter

	self.hitSphere = nil
	self.sphereEntity = nil

	if t.hitSphere then
		self.hitSphere = {
			sphereID = t.hitSphere.sphereID,
			sphereGroup = _Game.session.level.map.paths.objects[t.hitSphere.pathID].sphereChains[t.hitSphere.chainID].sphereGroups[t.hitSphere.groupID]
		}
	else
		self.sphereEntity = SphereEntity(self.pos, self.color)
		self.sphereEntity.frame = Vec2(1)
	end

	self.hitTime = t.hitTime
	self.hitTimeMax = t.hitTimeMax
end

return ShotSphere
