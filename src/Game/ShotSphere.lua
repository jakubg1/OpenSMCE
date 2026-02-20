local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")
local SphereEntity = require("src.Game.SphereEntity")

---Represents a Sphere which has been shot from the Shooter and is flying on the screen until it finds a Sphere Group on its way.
---@class ShotSphere
---@overload fun(data, shooter, posX, posY, angle, size, color, speed, sphereEntity, isHoming):ShotSphere
local ShotSphere = class:derive("ShotSphere")

---Constructs a new Shot Sphere.
---@param data table? The deserialization data to be used instead of the fields below if loading a previously saved game.
---@param shooter Shooter The shooter which this sphere has been shot from.
---@param posX number The inital X coordinate of this Shot Sphere.
---@param posY number The inital Y coordinate of this Shot Sphere.
---@param angle number The initial movement direction of this Shot Sphere, in radians. 0 is up.
---@param size number The diameter of this Shot Sphere in pixels.
---@param color integer The color of this Shot Sphere.
---@param speed number The initial speed of this Shot Sphere.
---@param sphereEntity SphereEntity The Sphere Entity that was attached to the Shooter from which this entity is created.
---@param isHoming boolean? If set, the sphere will be homing towards a specific sphere determined by `Level:getHomingBugsSphere()`.
function ShotSphere:new(data, shooter, posX, posY, angle, size, color, speed, sphereEntity, isHoming)
	if data then
		self:deserialize(data)
	else
		self.shooter = shooter
		self.x, self.y = posX, posY
		self.angle = angle
		self.size = size
		self.steps = 0
		self.color = color
		self.speed = speed
		self.sphereEntity = sphereEntity
		self.sphereEntity:setState("shot")
		self.homingTowards = nil
		if isHoming then
			self:pickNewHomingTarget()
		end

		self.gapsTraversed = {}
		self.destroyedFragileSpheres = false
		self.markedAsSuccessfulShot = false

		self.hitTime = 0
		self.hitTimeMax = 0
		self.hitSphere = nil
	end

	self.config = _Res:getSphereConfig("spheres/sphere_" .. self.color .. ".json")

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
			self:destroy(true, true)
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
				local homingX, homingY = self.homingTowards:getPos()
				self.angle = _V.angle(homingX - self.x, homingY - self.y) + math.pi / 2
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
	local oldPosX, oldPosY = self.x, self.y
	local x, y = _V.rotate(0, -self.PIXELS_PER_STEP, self.angle)
	self.x, self.y = self.x + x, self.y + y

	-- count the gaps
	for i, path in ipairs(_Game.level.map.paths) do
		local offsets = path:getIntersectionPoints(oldPosX, oldPosY, self.x, self.y)
		for j, offset in ipairs(offsets) do
			local size, group = path:getGapSize(offset)
			if group then
				-- We've traversed a gap.
				if not self:didTraverseGap(group) then
					table.insert(self.gapsTraversed, {size = size, group = group})
					--local x, y = path:getPos(offset)
					--_Game:spawnParticle("particles/collapse_vise.json", x, y)
					--_Debug:print(size)
				end
			end
		end
	end

	-- add if there's a sphere nearby
	local nearestSphere = _Game.level:getNearestSphere(self.x, self.y)
	if nearestSphere and nearestSphere.dist < (self.size + nearestSphere.sphere.config.size) / 2 and (not self.homingTowards or self.homingTowards == nearestSphere.sphere) then
		-- Execute this only if we are close enough to the nearest sphere and have ANY collision (we are not homing towards something different).
		if nearestSphere.sphere:isFragile() then
			-- If we've hit a fragile sphere, destroy the fragile spheres instead of hitting.
			nearestSphere.sphere:matchEffectFragile()
			self.destroyedFragileSpheres = true
		elseif not self.config.doesNotCollideWith or not _Utils.isValueInTable(self.config.doesNotCollideWith, nearestSphere.sphere.color) then
			-- We've hit a sphere and have collision with it.
			self.hitSphere = nearestSphere
			local hitSphere = nearestSphere.sphere
			local badShot = false
			hitSphere:dumpVariables("hitSphere")
			local hitBehavior = self.config.hitBehavior
			-- Instead of having different hit behavior types, make a field which states what happens to the shot sphere:
			-- - "append" - The sphere is appended
			-- - "pierce" - The sphere keeps on flying
			-- - "vanish" - The sphere vanishes
			local whatHappens = "append"
			if hitBehavior then
				whatHappens = hitBehavior.pierce and "pierce" or "vanish"
				if hitBehavior.type == "destroySpheres" then
					_Game.level:destroySelector(hitBehavior.selector, self.x, self.y, hitBehavior.scoreEvent, hitBehavior.scoreEventPerSphere, hitBehavior.gameEvent, hitBehavior.gameEventPerSphere)
				elseif hitBehavior.type == "recolorSpheres" then
					_Game.level:replaceColorSelector(hitBehavior, self.x, self.y)
				elseif hitBehavior.type == "applyEffect" then
					_Game.level:applyEffectSelector(hitBehavior, self.x, self.y)
				elseif hitBehavior.type == "splitAndPushBack" then
					if hitSphere.nextSphere then
						hitSphere.sphereGroup:divide(self.hitSphere.sphereID)
					end
					hitSphere.sphereGroup.speed = -hitBehavior.speed
				else
					whatHappens = "append"
				end
			end
			-- Do with the sphere what we're supposed to.
			if whatHappens == "vanish" then
				self:destroy()
			elseif whatHappens == "pierce" then
				self.hitSphere = nil
			elseif whatHappens == "append" then
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
					local o = self.hitSphere.sphereGroup:getLastSphereOffset() + (self.size + self.hitSphere.sphere.config.size) / 2
					p = Vec2(self.hitSphere.path:getPos(o))
				end
				-- calculate length from the current position
				local d = _V.length(self.x - p.x, self.y - p.y)
				-- calculate time
				self.hitTimeMax = d / self.speed * 5
				self.hitSphere.sphereGroup:addSphere(self.color, Vec2(self.x, self.y), self.hitTimeMax, self.sphereEntity, self.hitSphere.sphereID, hitBehavior and hitBehavior.effects, self:getGapSizeList(), self.destroyedFragileSpheres, _Game.configManager.gameplay.sphereBehavior.instantMatches)
				badShot = self.hitSphere.sphereGroup:getMatchLengthInChain(self.hitSphere.sphereID) == 1
			end
			_Vars:set("shot.bad", badShot)
			if self.config.hitSound then
				self.config.hitSound:play(self.x, self.y)
			end
			_Vars:unset("shot")
			if not badShot and not self.markedAsSuccessfulShot then
				_Game.level:markSuccessfulShot()
				self.markedAsSuccessfulShot = true
			end
			_Vars:unset("hitSphere")
		end
	end

	-- delete if outside of the board
	if self:isOutsideBoard() then
		self:destroy(true)
		_Game.level.streak = 0
	end
end



---Returns whether this Shot Sphere is outside of the board.
---@return boolean
function ShotSphere:isOutsideBoard()
	local margin = self.size / 2
	local w, h = _Game:getNativeResolution()
	return self.x < -margin or self.x > w + margin or self.y < -margin or self.y > h + margin
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
---@param pass boolean? If set, the sphere entity will be kept. Use if the sphere entity is passed on to a Sphere in the chain.
function ShotSphere:destroy(silent, pass)
	if self.delQueue then
		return
	end
	if self.sphereEntity and not pass then
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
		self.sphereEntity:draw()
		--self:drawDebug()
	end
end



---Draws something which is meant to debug.
function ShotSphere:drawDebug()
	love.graphics.setColor(0, 1, 1)
	for i = self.y, 0, -self.PIXELS_PER_STEP do
		love.graphics.circle("fill", self.x, i, 2)
		local nearestSphere = _Game.level:getNearestSphere(self.x, i)
		if nearestSphere and nearestSphere.dist < 32 then
			love.graphics.setLineWidth(3)
			love.graphics.circle("line", nearestSphere.pos.x, nearestSphere.pos.y, self.size / 2)
			break
		end
	end
end



---Returns the position at which the entity should be drawn. This is different to the real position so the ball movement is smooth visually.
---@return number
---@return number
function ShotSphere:getDrawPos()
	local x, y = _V.rotate(0, self.steps * -self.PIXELS_PER_STEP, self.angle)
	return self.x + x, self.y + y
end



---Serializes this entity's data so it can be reused again during reload.
---@return table
function ShotSphere:serialize()
	local t = {
		pos = {x = self.x, y = self.y},
		angle = self.angle,
		size = self.size,
		color = self.color,
		speed = self.speed,
		steps = self.steps,
		homingTowards = self.homingTowards and self.homingTowards:getIDs(),
		destroyedFragileSpheres = self.destroyedFragileSpheres,
		markedAsSuccessfulShot = self.markedAsSuccessfulShot,
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
	self.x, self.y = t.pos.x, t.pos.y
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
	self.destroyedFragileSpheres = t.destroyedFragileSpheres
	self.markedAsSuccessfulShot = t.markedAsSuccessfulShot

	self.hitSphere = nil
	self.sphereEntity = nil

	if t.hitSphere then
		self.hitSphere = {
			sphereID = t.hitSphere.sphereID,
			sphereGroup = _Game.level:getSphere(t.hitSphere).sphereGroup
		}
	else
		self.sphereEntity = SphereEntity(self.x, self.y, self.color)
		self.sphereEntity:setState("shot")
		self.sphereEntity:setAngle(self.angle)
	end

	self.hitTime = t.hitTime
	self.hitTimeMax = t.hitTimeMax
end



return ShotSphere
