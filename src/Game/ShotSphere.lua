local class = require "com.class"

---Represents a Sphere which has been shot from the Shooter and is flying on the screen until it finds a Sphere Group on its way.
---@class ShotSphere
---@overload fun(deserializationTable, shooter, pos, angle, size, color, speed, sphereEntity, isHoming):ShotSphere
local ShotSphere = class:derive("ShotSphere")

local Vec2 = require("src.Essentials.Vector2")

local SphereEntity = require("src.Game.SphereEntity")



---Constructs a new Shot Sphere.
---@param deserializationTable table? The deserialization data to be used instead of the fields below if loading a previously saved game.
---@param shooter Shooter The shooter which this sphere has been shot from.
---@param pos Vector2 The inital position of this Shot Sphere.
---@param angle number The initial movement direction of this Shot Sphere, in radians. 0 is up.
---@param size number The diameter of this Shot Sphere in pixels.
---@param color integer The color of this Shot Sphere.
---@param speed number The initial speed of this Shot Sphere.
---@param sphereEntity SphereEntity The Sphere Entity that was attached to the Shooter from which this entity is created.
---@param isHoming boolean? If set, the sphere will be homing towards a specific sphere determined by `Level:getHomingBugsSphere()`.
function ShotSphere:new(deserializationTable, shooter, pos, angle, size, color, speed, sphereEntity, isHoming)
	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.shooter = shooter
		self.pos = pos
		self.angle = angle
		self.size = size
		self.steps = 0
		self.color = color
		self.speed = speed
		self.sphereEntity = sphereEntity
		self.homingTowards = nil
		if isHoming then
			self:pickNewHomingTarget()
		end

		self.gapsTraversed = {}

		self.hitTime = 0
		self.hitTimeMax = 0
		self.hitSphere = nil
	end

	self.config = _Game.resourceManager:getSphereConfig("spheres/sphere_" .. self.color .. ".json")

	self.PIXELS_PER_STEP = 8

	self.delQueue = false
end



---Updates the Shot Sphere logic.
---@param dt number Delta time in seconds.
function ShotSphere:update(dt)
	if self.hitSphere then
		-- increment the timer
		self.hitTime = self.hitTime + dt
		-- if the timer expired, destroy the entity and add the ball to the chain
		if self.hitTime >= self.hitTimeMax then
			self:destroy(true)
		end
	else
		-- If this is a homing sphere, go towards that.
		if self.homingTowards then
			-- If the sphere we were homing towards has been destroyed or is in a tunnel, pick a new homing target.
			if self.homingTowards.delQueue or self.homingTowards:getHidden() then
				self:pickNewHomingTarget()
			end
			-- If there is no new homing target, do not proceed.
			if self.homingTowards then
				local targetAngle = (self.homingTowards:getPos() - self.pos):angle() + math.pi / 2
				self.angle = targetAngle
			else
				self:destroy()
			end
		end
		-- move
		self.steps = self.steps + self.speed * dt / self.PIXELS_PER_STEP
		while self.steps > 0 and not self.hitSphere and not self.delQueue do
			self:moveStep()
		end
	end
end



---Performs a single movement step of `PIXELS_PER_STEP` length (default is 8 px).
---This allows the shot sphere behavior to be consistent while not being too laggy.
function ShotSphere:moveStep()
	-- you can do more pixels if it's not efficient (laggy), but that will decrease the accuracy
	self.steps = self.steps - 1
	local oldPos = self.pos
	self.pos = self.pos + Vec2(0, -self.PIXELS_PER_STEP):rotate(self.angle)

	-- count the gaps
	for i, path in ipairs(_Game.level.map.paths) do
		local offsets = path:getIntersectionPoints(oldPos, self.pos)
		for j, offset in ipairs(offsets) do
			local size, group = path:getGapSize(offset)
			if group then
				-- We've traversed a gap.
				if not self:didTraverseGap(group) then
					table.insert(self.gapsTraversed, {size = size, group = group})
					--local pos = path:getPos(offset)
					--_Game:spawnParticle("particles/collapse_vise.json", pos)
					--_Debug.console:print(size)
				end
			end
		end
	end

	-- add if there's a sphere nearby
	local nearestSphere = _Game.level:getNearestSphere(self.pos)
	if nearestSphere.dist and nearestSphere.dist < (self.size + nearestSphere.sphere.size) / 2 and (not self.homingTowards or self.homingTowards == nearestSphere.sphere) then
		-- If hit sphere is fragile, destroy the fragile spheres instead of hitting.
		if nearestSphere.sphere:isFragile() then
			nearestSphere.sphere:matchEffectFragile()
		else
			self.hitSphere = nearestSphere
			-- TODO: Move this logic to Sphere.lua and dehardcode it.
			local hitSphere = self.hitSphere.sphereGroup.spheres[self.hitSphere.sphereID]
			-- Redirect the hit sphere if it's a scarab or a stone sphere.
			local redirectedHitSphere = hitSphere
			if hitSphere.color == 0 or hitSphere:isStone() then
				-- The sphere can be redirected to the front or to the back. Both searches stop when either something that matches the requirements is found (valid result) or not (invalid result).
				local redirectedHitSpherePrev = redirectedHitSphere
				local redirectedHitSphereNext = redirectedHitSphere
				while redirectedHitSpherePrev and (redirectedHitSpherePrev.color == 0 or redirectedHitSpherePrev:isStone()) do
					redirectedHitSpherePrev = redirectedHitSpherePrev:getPrevSphereInChain()
				end
				while redirectedHitSphereNext and (redirectedHitSphereNext.color == 0 or redirectedHitSphereNext:isStone()) do
					redirectedHitSphereNext = redirectedHitSphereNext:getNextSphereInChain()
				end
				if redirectedHitSpherePrev and redirectedHitSphereNext then
					-- We found both. Choose randomly.
					redirectedHitSphere = math.random() < 0.5 and redirectedHitSpherePrev or redirectedHitSphereNext
				elseif redirectedHitSpherePrev then
					redirectedHitSphere = redirectedHitSpherePrev
				elseif redirectedHitSphereNext then
					redirectedHitSphere = redirectedHitSphereNext
				else
					-- We found nothing...?
					error("Congratulations! You found an error because the lazy developer doesn't even bother to write code for edge cases like this! Yay!")
				end
			end
			local badShot = false
			local shotCancelled = false
			hitSphere:dumpVariables("hitSphere")
			redirectedHitSphere:dumpVariables("redirectedHitSphere")
			if not self.config.doesNotCollideWith or not _Utils.isValueInTable(self.config.doesNotCollideWith, hitSphere.color) then
				if self.config.hitBehavior.type == "destroySpheres" then
					_Game.level:destroySelector(self.config.hitBehavior.selector, self.pos, self.config.hitBehavior.scoreEvent, self.config.hitBehavior.scoreEventPerSphere)
					if not self.config.hitBehavior.pierce then
						self:destroy()
					else
						self.hitSphere = nil
					end
				elseif self.config.hitBehavior.type == "recolorSpheres" then
					_Game.level:replaceColorSelector(self.config.hitBehavior, self.pos)
					if not self.config.hitBehavior.pierce then
						self:destroy()
					else
						self.hitSphere = nil
					end
				elseif self.config.hitBehavior.type == "applyEffect" then
					_Game.level:applyEffectSelector(self.config.hitBehavior, self.pos)
					if not self.config.hitBehavior.pierce then
						self:destroy()
					else
						self.hitSphere = nil
					end
				elseif self.config.hitBehavior.type == "splitAndPushBack" then
					if hitSphere.nextSphere then
						hitSphere.sphereGroup:divide(self.hitSphere.sphereID)
					end
					hitSphere.sphereGroup.speed = -self.config.hitBehavior.speed
					if not self.config.hitBehavior.pierce then
						self:destroy()
					else
						self.hitSphere = nil
					end
				else
					if self.hitSphere.half then
						self.hitSphere.sphereID = self.hitSphere.sphereID + 1
					end
					self.hitSphere.sphereID = self.hitSphere.sphereGroup:getAddSpherePos(self.hitSphere.sphereID)
					-- get the desired sphere position
					local p
					if self.hitSphere.sphereID <= #self.hitSphere.sphereGroup.spheres then
						-- the inserted ball is NOT at the end of the group
						p = self.hitSphere.sphereGroup:getSpherePos(self.hitSphere.sphereID)
					else
						-- the inserted ball IS at the end of the group
						local o = self.hitSphere.sphereGroup:getLastSphereOffset() + (self.size + self.hitSphere.sphere.size) / 2
						p = self.hitSphere.path:getPos(o)
					end
					-- calculate length from the current position
					local d = (self.pos - p):len()
					-- calculate time
					self.hitTimeMax = d / self.speed * 5
					self.hitSphere.sphereGroup:addSphere(self.color, self.pos, self.hitTimeMax, self.sphereEntity, self.hitSphere.sphereID, self.config.hitBehavior.effects, self:getGapSizeList(), _Game.configManager.gameplay.sphereBehavior.instantMatches)
					badShot = self.hitSphere.sphereGroup:getMatchLengthInChain(self.hitSphere.sphereID) == 1
				end
			else
				shotCancelled = true
			end
			if shotCancelled then
				self.hitSphere = nil -- avoid deleting this time
			else
				_Vars:set("shot.bad", badShot)
				if self.config.hitSound then
					_Game:playSound(self.config.hitSound, self.pos)
				end
				_Vars:unset("shot")
				if not badShot then
					_Game.level:markSuccessfulShot()
				end
			end
			_Vars:unset("hitSphere")
			_Vars:unset("redirectedHitSphere")
		end
	end

	-- delete if outside of the board
	if self:isOutsideBoard() then
		self:destroy(true)
		_Game.level.combo = 0
	end
end



---Returns whether this Shot Sphere is outside of the board.
---@return boolean
function ShotSphere:isOutsideBoard()
	local s = self.size / 2
	return self.pos.x < -s or self.pos.x > _Game:getNativeResolution().x + s or self.pos.y < -s or self.pos.y > _Game:getNativeResolution().y + s
end



---Returns whether this Shot Sphere has already traversed a gap identified by a given Sphere Group.
---@param group SphereGroup The sphere group which identifies a gap.
function ShotSphere:didTraverseGap(group)
	for i, gap in ipairs(self.gapsTraversed) do
		if gap.group == group then
			return true
		end
	end
	return false
end



---Returns a simplified version of traversed gap list, consisting only of sizes of each gaps in pixels.
---@return table
function ShotSphere:getGapSizeList()
	local gaps = {}
	for i, gap in ipairs(self.gapsTraversed) do
		table.insert(gaps, gap.size)
	end
	return gaps
end



---Picks a random sphere from `Level:getHomingBugsTarget()` and sets that sphere as the new homing target.
function ShotSphere:pickNewHomingTarget()
	self.homingTowards = _Game.level:getHomingBugsSphere(self.color)
end



---Deinitializates itself, destroys the associated sphere entity and allows the shooter to shoot again.
---@param silent boolean? If set, the sphere will not emit any particles.
function ShotSphere:destroy(silent)
	if self.delQueue then
		return
	end
	if self.sphereEntity then
		self.sphereEntity:setPos(self:getDrawPos())
		self.sphereEntity:destroy(not silent)
	end
	self.delQueue = true
end



---Draws the associated sphere entity.
function ShotSphere:draw()
	if not self.hitSphere then
		self.sphereEntity:setPos(self:getDrawPos())
		self.sphereEntity:setAngle(self.angle)
		self.sphereEntity:draw(true)
		self.sphereEntity:draw()
		--self:drawDebug()
	end
end



---Draws something which is meant to debug.
function ShotSphere:drawDebug()
	love.graphics.setColor(0, 1, 1)
	for i = self.pos.y, 0, -self.PIXELS_PER_STEP do
		love.graphics.circle("fill", self.pos.x, i, 2)
		local nearestSphere = _Game.level:getNearestSphere(Vec2(self.pos.x, i))
		if nearestSphere.dist and nearestSphere.dist < 32 then
			love.graphics.setLineWidth(3)
			love.graphics.circle("line", nearestSphere.pos.x, nearestSphere.pos.y, self.size / 2)
			break
		end
	end
end



---Returns the position at which the entity should be drawn. This is different to the real position so the ball movement is smooth visually.
---@return Vector2
function ShotSphere:getDrawPos()
	return self.pos + Vec2(0, self.steps * -self.PIXELS_PER_STEP):rotate(self.angle)
end



---Serializes this entity's data so it can be reused again during reload.
---@return table
function ShotSphere:serialize()
	local t = {
		pos = {x = self.pos.x, y = self.pos.y},
		angle = self.angle,
		size = self.size,
		color = self.color,
		speed = self.speed,
		steps = self.steps,
		homingTowards = self.homingTowards and self.homingTowards:getIDs(),
		hitSphere = self.hitSphere and self.hitSphere.sphere:getIDs(),
		hitTime = self.hitTime,
		hitTimeMax = self.hitTimeMax
	}

	if #self.gapsTraversed > 0 then
		t.gaps = {}
		for i, gap in ipairs(self.gapsTraversed) do
			local gapT = gap.group:getIDs()
			gapT.size = gap.size
			table.insert(t.gaps, gapT)
		end
	end

	return t
end



---Loads previously saved entity data.
---@param t table Deserialization data.
function ShotSphere:deserialize(t)
	self.pos = Vec2(t.pos.x, t.pos.y)
	self.angle = t.angle
	self.size = t.size
	self.color = t.color
	self.speed = t.speed
	self.steps = t.steps
	if t.homingTowards then
		self.homingTowards = _Game.level:getSphere(t.homingTowards)
	end

	self.shooter = _Game.level.shooter

	self.gapsTraversed = {}
	if t.gaps then
		for i, gap in ipairs(t.gaps) do
			local group = _Game.level.map.paths[gap.pathID].sphereChains[gap.chainID].sphereGroups[gap.groupID]
			table.insert(self.gapsTraversed, {group = group, size = gap.size})
		end
	end

	self.hitSphere = nil
	self.sphereEntity = nil

	if t.hitSphere then
		self.hitSphere = {
			sphereID = t.hitSphere.sphereID,
			sphereGroup = _Game.level:getSphere(t.hitSphere).sphereGroup
		}
	else
		self.sphereEntity = SphereEntity(self.pos, self.color)
		self.sphereEntity:setAngle(self.angle)
	end

	self.hitTime = t.hitTime
	self.hitTimeMax = t.hitTimeMax
end



return ShotSphere
