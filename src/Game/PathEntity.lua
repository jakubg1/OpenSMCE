local class = require "com.class"
local Color = require("src.Essentials.Color")

---Represents a PathEntity.
---@class PathEntity
---@overload fun(path, config):PathEntity
local PathEntity = class:derive("PathEntity")

---Constructs a new PathEntity.
---@param path Path The path this PathEntity is on.
---@param config PathEntityConfig|table Either the config of this Path Entity or data to be loaded if loading from a saved game.
function PathEntity:new(path, config)
	self.path = path

	if config.id then
		self:deserialize(config)
	else
		self.config = config
		if self.config.spawnPlacement == "start" then
			self.offset = self.config.spawnOffset
		elseif self.config.spawnPlacement == "end" then
			self.offset = path.length - self.config.spawnOffset
		elseif self.config.spawnPlacement == "furthestSpheres" then
			self.offset = path:getMaxOffset() + self.config.spawnOffset
		end
		self.backwards = self.config.spawnPlacement == "end"
		if self.config.maxOffset then
			if self.backwards then
				self.offsetBound = self.offset - self.config.maxOffset
			else
				self.offsetBound = self.offset + self.config.maxOffset
			end
		end
		self.speed = self.config.speed
		self.time = 0
		self.traveledDistance = 0
		self.trailDistance = 0
		self.collectibleDistance = 0
		self.destroyedSpheres = 0
		self.destroyedChains = 0
	end

	if self.config.loopSound then
		local x, y = self:getPos()
		self.sound = self.config.loopSound:play(x, y)
	end

	self.delQueue = false
end

---Updates the Path Entity's logic.
---@param dt number Delta time in seconds.
function PathEntity:update(dt)
	-- Offset and distance
	self.speed = self.speed + self.config.acceleration * dt
	if self.config.maxSpeed then
		self.speed = math.min(self.speed, self.config.maxSpeed)
	end
	local oldOffset = self.offset
	if self.backwards then
		self.offset = self.offset - self.speed * dt
	else
		self.offset = self.offset + self.speed * dt
	end
	if self.offsetBound then
		if self.backwards then
			self.offset = math.max(self.offset, self.offsetBound)
		else
			self.offset = math.min(self.offset, self.offsetBound)
		end
	end
	self.traveledDistance = self.traveledDistance + math.abs(self.offset - oldOffset)

	-- Time
	self.time = self.time + dt

	-- Trail
	if self.config.particle then
		while self.trailDistance < self.traveledDistance do
			local offsetFromCurrentOffset = self.traveledDistance - self.trailDistance
			if self.backwards then
				offsetFromCurrentOffset = -offsetFromCurrentOffset
			end
			local offset = self.offset - offsetFromCurrentOffset
			if self.config.renderParticlesInTunnels or self.path:getBrightness(offset) > 0.5 then -- the particles shouldn't be visible under obstacles
				local x, y = self.path:getPos(offset)
				_Game:spawnParticle(self.config.particle, x, y, self.config.particleLayer)
			end
			self.trailDistance = self.trailDistance + self.config.particleSeparation
		end
	end

	-- Collectibles
	if self.config.collectibleGenerator then
		while self.collectibleDistance < self.traveledDistance do
			local offsetFromCurrentOffset = self.traveledDistance - self.collectibleDistance
			if self.backwards then
				offsetFromCurrentOffset = -offsetFromCurrentOffset
			end
			local offset = self.offset - offsetFromCurrentOffset
			if self.collectibleDistance > 0 then -- We don't spawn anything the moment this Entity is spawned.
				local x, y = self:getPos()
				_Game.level:spawnCollectiblesFromEntry(self.config.collectibleGenerator, x, y)
			end
			self.collectibleDistance = self.collectibleDistance + self.config.collectibleGeneratorSeparation
		end
	end

	-- Destroying spheres
	if self.config.canDestroySpheres then
		while not self:shouldExplode() do
			-- Attempt to erase one sphere per iteration
			-- The routine simply finds the closest sphere to the pyramid
			-- If it's too far away, the loop ends
			if self.path:getEmpty() then
				break
			end
			local sphereGroup = self.path.sphereChains[1].sphereGroups[1]
			if sphereGroup:getFrontOffset() + 16 > self.offset and sphereGroup:getLastSphere().color ~= 0 then
				sphereGroup:destroySphere(#sphereGroup.spheres)
				if self.config.sphereDestroySound then
					local x, y = self:getPos()
					self.config.sphereDestroySound:play(x, y)
				end
				self.destroyedSpheres = self.destroyedSpheres + 1
				-- if this sphere is the last sphere, the entity gets rekt
				local thisGroupKill = not sphereGroup.prevGroup and not sphereGroup.nextGroup and #sphereGroup.spheres == 1 and sphereGroup.spheres[1].color == 0
				local prevGroupKill = sphereGroup.prevGroup and not sphereGroup.nextGroup and #sphereGroup.spheres == 0 and #sphereGroup.prevGroup.spheres == 1 and sphereGroup.prevGroup.spheres[1].color == 0
				if thisGroupKill or prevGroupKill then
					self.destroyedChains = self.destroyedChains + 1
				end
			else
				break
			end
		end
	end

	-- Sound
	if self.sound then
		local x, y = self:getPos()
		self.sound:setPos(x, y)
	end

	-- Destroy the entity when certain conditions are met.
	if self:shouldExplode() then
		self:explode()
	end
end

---Returns whether this Path Entity should be destroyed now.
---@return boolean
function PathEntity:shouldExplode()
	if self.config.destroyOffset then
		local offset = self.backwards and self.offset or (self.path.length - self.offset)
		if offset <= self.config.destroyOffset then
			return true
		end
	end
	if self.config.destroyTime and self.time >= self.config.destroyTime then
		return true
	end
	if self.config.destroyWhenPathEmpty and self.path:getEmpty() then
		return true
	end
	if self.config.destroyAtClearOffset and self.offset <= self.path.clearOffset then
		return true
	end
	if self.config.maxSpheresDestroyed and self.destroyedSpheres == self.config.maxSpheresDestroyed then
		return true
	end
	if self.config.maxSphereChainsDestroyed and self.destroyedChains == self.config.maxSphereChainsDestroyed then
		return true
	end
	return false
end

---Destroys the Path Entity, by giving points, spawning particles and playing a sound.
function PathEntity:explode()
	if self.delQueue then
		return
	end

	self.path:setOffsetVars("entity", self.offset)
	_Vars:set("entity.traveledPixels", self.traveledDistance)
	_Vars:set("entity.destroyedSpheres", self.destroyedSpheres)
	_Vars:set("entity.destroyedChains", self.destroyedChains)

	local x, y = self:getPos()
	if self.config.destroyScoreEvent then
		_Game.level:executeScoreEvent(self.config.destroyScoreEvent, x, y)
	end
	if self.config.destroyCollectibleGenerator then
		_Game.level:spawnCollectiblesFromEntry(self.config.destroyCollectibleGenerator, x, y)
	end
	if self.config.destroyParticle then
		_Game:spawnParticle(self.config.destroyParticle, x, y, self.config.destroyParticleLayer)
	end
	if self.config.destroySound then
		self.config.destroySound:play(x, y)
	end

	_Vars:unset("entity")

	self:destroy()
end

---Queues this Path Entity for removal.
function PathEntity:destroy()
	if self.delQueue then
		return
	end
	self.delQueue = true
	if self.sound then
		self.sound:stop()
	end
end

---Draws this Path Entity on the screen.
function PathEntity:draw()
	local x, y = self:getPos()
	local hidden = self:getHidden()
	local angle = self:getAngle() + math.pi
	-- Draw the main sprite.
	if self.config.sprite then
		_Renderer:setLayer(hidden and "GamePieceHidden" or "GamePieceNormal")
		self.config.sprite:draw(x, y, 0.5, 0.5, nil, nil, angle, Color(self:getBrightness()))
	end
	-- Draw the shadow.
	if self.config.shadowSprite then
		_Renderer:setLayer(hidden and "GamePieceHShadow" or "GamePieceNShadow")
		self.config.shadowSprite:draw(x + 4, y + 4, 0.5, 0.5, nil, nil, angle)
	end
end

---Returns the onscreen position of this Path Entity.
---@return number, number
function PathEntity:getPos()
	return self.path:getPos(self.offset)
end

---Returns the current angle of this Path Entity.
---@return number
function PathEntity:getAngle()
	return self.path:getAngle(self.offset)
end

---Returns the current brightness of this Path Entity.
---@return number
function PathEntity:getBrightness()
	return self.path:getBrightness(self.offset)
end

---Returns whether this Path Entity is marked as hidden.
---@return boolean
function PathEntity:getHidden()
	return self.path:getHidden(self.offset)
end

---Serializes this Path Entity to a set of values which can be reimported later.
---@return table
function PathEntity:serialize()
	local t = {
		id = _Res:getResourceReference(self.config),
		offset = self.offset,
		backwards = self.backwards,
		offsetBound = self.offsetBound,
		speed = self.speed,
		time = self.time,
		traveledDistance = self.traveledDistance,
		trailDistance = self.trailDistance,
		collectibleDistance = self.collectibleDistance,
		destroyedSpheres = self.destroyedSpheres,
		destroyedChains = self.destroyedChains
	}
	return t
end

---Loads previously saved data from a given table.
---@param t table The data to be loaded.
function PathEntity:deserialize(t)
	self.config = _Res:getPathEntityConfig(t.id)
	self.offset = t.offset
	self.backwards = t.backwards
	self.offsetBound = t.offsetBound
	self.speed = t.speed
	self.time = t.time
	self.traveledDistance = t.traveledDistance
	self.trailDistance = t.trailDistance
	self.collectibleDistance = t.collectibleDistance
	self.destroyedSpheres = t.destroyedSpheres
	self.destroyedChains = t.destroyedChains
end

return PathEntity
