local class = require "com/class"

---@class ShotSphere
---@overload fun(deserializationTable, shooter, pos, angle, color, speed):ShotSphere
local ShotSphere = class:derive("ShotSphere")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")

local SphereEntity = require("src/SphereEntity")



---Constructs a new Shot Sphere.
---@param deserializationTable table? The deserialization data to be used instead of the fields below if loading a previously saved game.
---@param shooter Shooter The shooter which this sphere has been shot from.
---@param pos Vector2 The inital position of this Shot Sphere.
---@param angle number The initial movement direction of this Shot Sphere, in radians. 0 is up.
---@param color integer The color of this Shot Sphere.
---@param speed number The initial speed of this Shot Sphere.
function ShotSphere:new(deserializationTable, shooter, pos, angle, color, speed)
	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.shooter = shooter
		self.pos = pos
		self.angle = angle
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



---Updates the Shot Sphere logic.
---@param dt number Delta time in seconds.
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



---Performs a single movement step of `PIXELS_PER_STEP` length (default is 8 px).
---This allows the shot sphere behavior to be consistent while not being too laggy.
function ShotSphere:moveStep()
	-- you can do more pixels if it's not efficient (laggy), but that will decrease the accuracy
	self.steps = self.steps - 1
	self.pos = self.pos + Vec2(0, -self.PIXELS_PER_STEP):rotate(self.angle)

	-- add if there's a sphere nearby
	local nearestSphere = _Game.session:getNearestSphere(self.pos)
	if nearestSphere.dist and nearestSphere.dist < 32 then
		-- If hit sphere is fragile, destroy the fragile spheres instead of hitting.
		if nearestSphere.sphere:isFragile() then
			nearestSphere.sphere:matchEffectFragile()
		else
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
					local o = self.hitSphere.sphereGroup:getLastSphereOffset() + 32
					p = self.hitSphere.path:getPos(o)
				end
				-- calculate length from the current position
				local d = (self.pos - p):len()
				-- calculate time
				self.hitTimeMax = d / self.speed * 5
				self.hitSphere.sphereGroup:addSphere(self.color, self.pos, self.hitTimeMax, self.sphereEntity, self.hitSphere.sphereID, sphereConfig.hitBehavior.effects)
				badShot = self.hitSphere.sphereGroup:getMatchLengthInChain(self.hitSphere.sphereID) == 1 and sphereConfig.hitSoundBad
			end
			if shotCancelled then
				self.hitSphere = nil -- avoid deleting this time
			else
				_Game:playSound(badShot and sphereConfig.hitSoundBad or sphereConfig.hitSound, 1, self.pos)
			end
		end
	end
	-- delete if outside of the board
	if self:isOutsideBoard() then
		self:destroy()
		_Game.session.level.combo = 0
	end
end



---Returns whether this Shot Sphere is outside of the board.
---@return boolean
function ShotSphere:isOutsideBoard()
	return self.pos.x < -16 or self.pos.x > _NATIVE_RESOLUTION.x + 16 or self.pos.y < -16 or self.pos.y > _NATIVE_RESOLUTION.y + 16
end



---Returns a table of IDs of the hit sphere, or `nil` if this sphere did not hit anything yet. Used for serialization purposes.
---@return table?
function ShotSphere:getHitSphereIDs()
	if not self.hitSphere then
		return nil
	end

	return self.hitSphere.sphere:getIDs()
end



---Deinitializates itself, destroys the associated sphere entity and allows the shooter to shoot again.
function ShotSphere:destroy()
	if self.delQueue then
		return
	end
	if self.sphereEntity then
		self.sphereEntity:destroy(false)
	end
	self.delQueue = true
	if not _Game.session.level.lost then
		self.shooter:activate()
	end
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



---Returns the position at which the entity should be drawn. This is different to the real position so the ball movement is smooth visually.
---@return Vector2
function ShotSphere:getDrawPos()
	return self.pos + Vec2(0, self.steps * -self.PIXELS_PER_STEP):rotate(self.angle)
end



---Serializes this entity's data so it can be reused again during reload.
---@return table
function ShotSphere:serialize()
	return {
		pos = {x = self.pos.x, y = self.pos.y},
		angle = self.angle,
		color = self.color,
		speed = self.speed,
		steps = self.steps,
		hitSphere = self:getHitSphereIDs(),
		hitTime = self.hitTime,
		hitTimeMax = self.hitTimeMax
	}
end



---Loads previously saved entity data.
---@param t table Deserialization data.
function ShotSphere:deserialize(t)
	self.pos = Vec2(t.pos.x, t.pos.y)
	self.angle = t.angle
	self.color = t.color
	self.speed = t.speed
	self.steps = t.steps

	self.shooter = _Game.session.level.shooter

	self.hitSphere = nil
	self.sphereEntity = nil

	if t.hitSphere then
		self.hitSphere = {
			sphereID = t.hitSphere.sphereID,
			sphereGroup = _Game.session.level.map.paths[t.hitSphere.pathID].sphereChains[t.hitSphere.chainID].sphereGroups[t.hitSphere.groupID]
		}
	else
		self.sphereEntity = SphereEntity(self.pos, self.color)
		self.sphereEntity:setAngle(self.angle)
	end

	self.hitTime = t.hitTime
	self.hitTimeMax = t.hitTimeMax
end



return ShotSphere
