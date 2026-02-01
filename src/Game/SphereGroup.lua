local class = require "com.class"
local Sphere = require("src.Game.Sphere")

---Represents a Sphere Group, which is a single group of spheres connected to each other. Handles all sphere movement on the track.
---@class SphereGroup
---@overload fun(sphereChain, data):SphereGroup
local SphereGroup = class:derive("SphereGroup")

---Constructs a new Sphere Group.
---@param sphereChain SphereChain The sphere chain this Sphere Group belongs to.
---@param data table? Saved data if this Sphere Group is loaded from a saved game.
function SphereGroup:new(sphereChain, data)
	self.sphereChain = sphereChain
	self.map = sphereChain.map

	-- these two are filled later by the sphere chain object
	self.prevGroup = nil
	self.nextGroup = nil

	if data then
		self:deserialize(data)
	else
		self.offset = 0
		self.speed = 0
		self.speedDesired = 0
		self.speedTime = nil -- this is used ONLY in zuma knockback; aka the speed of this group will be locked for this time
		---@type Sphere[]
		self.spheres = {}
		self.matchCheck = true -- this is used ONLY in vise destruction to not trigger a chain reaction
		self.distanceEventStates = {}
	end

	self.maxSpeed = 0

	self.config = _Game.configManager.gameplay.sphereBehavior

	self.delQueue = false
end

---Updates the Sphere Group.
---@param dt number Time delta in seconds.
function SphereGroup:update(dt)
	-- Empty sphere groups are not updated.
	assert(#self.spheres > 0, "This should not happen: Empty Sphere Group gets updated!")

	-- Correct the speed bound if this chain is daisy-chained with another chain.
	local speedGrp = self:getLastChainedGroup()
	local speedBound = speedGrp.sphereChain.path:getSpeed(speedGrp:getLastSphereOffset())

	self.speedDesired = self.sphereChain.speedOverrideBase + speedBound * self.sphereChain.speedOverrideMult
	if self:isMagnetizing() and not self:hasImmobileSpheres() then
		self.maxSpeed = self.config.attractionSpeedBase + self.config.attractionSpeedMult * math.max(self:getCascade(), 1)
	else
		self.maxSpeed = 0
		self.matchCheck = true
	end

	-- If this group is the first one, it can push spheres forward.
	if not self.prevGroup then
		if self.map.level.lost then
			-- If this level is lost, apply the foul speed.
			self.maxSpeed = self.config.foulSpeed
		elseif self:hasImmobileSpheres() then
			-- If this group has immobile spheres, prevent from moving.
			self.maxSpeed = 0
			self.speed = 0
		elseif speedGrp:hasImmobileSpheres() then
			-- The same goes for the first daisy-chained group.
			self.maxSpeed = 0
			self.speed = 0
		elseif self.speedDesired >= 0 then
			-- Note that this group only pushes, so it must have positive speed in order to work!
			self.maxSpeed = self.speedDesired
		end
	end
	-- If this group is last, it can pull spheres back when the speed is going to be negative.
	if not self.nextGroup then
		-- If the level is lost or this group is magnetizing at this moment, do not apply any other speed.
		if not self.map.level.lost and not self:isMagnetizing() and not self:hasImmobileSpheres() then
			if self.speedDesired < 0 then
				-- Note that this group only pulls, so it must have negative speed in order to work!
				self.maxSpeed = self.speedDesired
			end
		end
	end

	if self.speedTime then
		-- Omit speed calculation if this group's speed is locked.
		self.speedTime = self.speedTime - dt
		if self.speedTime <= 0 then
			self.speedTime = nil
			if self.config.knockbackStopAfterTime then
				self.speed = 0
			end
		end
	else
		if self.speed > self.maxSpeed then
			-- Decceleration rate used in this frame.
			local deccel = self.config.decceleration

			-- Can be different if defined accordingly, such as reverse powerup, magnetizing or under a slow powerup.
			if self.sphereChain.speedOverrideTime > 0 and self.speedDesired < 0 and not self:isMagnetizing() then
				deccel = self.sphereChain.speedOverrideDecc or deccel
			elseif self:isMagnetizing() then
				deccel = self.config.attractionAcceleration or deccel
				if self.speed > 0 then
					deccel = self.config.attractionForwardDecceleration or deccel
					if self.prevGroup:getLastMatureSphere().color == 0 then
						deccel = self.config.attractionForwardDeccelerationScarab or deccel
					end
				end
			elseif self.prevGroup then
				deccel = self.config.decceleration or deccel
			elseif self.sphereChain.speedOverrideTime > 0 then
				deccel = self.sphereChain.speedOverrideDecc or deccel
			end

			self.speed = math.max(self.speed - deccel * dt, self.maxSpeed)
		end

		if self.speed < self.maxSpeed then
			-- Acceleration rate used in this frame.
			local accel = self.config.acceleration

			-- Can be different if defined accordingly, such as when the level is lost.
			if self.map.level.lost then
				accel = self.config.foulAcceleration or accel
			elseif self.speed < 0 then
				accel = self.config.backwardsDecceleration or accel
			end

			self.speed = math.min(self.speed + accel * dt, self.maxSpeed)
		end
		-- anti-slow-catapulting
		if self.config.overspeedCheck and not self.map.level.lost and self.speed > speedBound then
			self.speed = speedBound
		end
	end

	-- stop spheres when away from board and rolling back
	if self.speed < 0 and self:getFrontOffset() < 0 then
		self.speed = 0
		self.speedTime = nil
	end

	self:move(self.speed * dt)

	-- Tick the powerup timers, but only if the current speed matches the desired value.
	if self.sphereChain.speedOverrideTime > 0 then
		local fw = not self.prevGroup and self.speedDesired >= 0 and self.speedDesired == self.speed
		local bw = not self.nextGroup and self.speedDesired < 0 and self.speedDesired == self.speed

		if fw or bw then
			self.sphereChain.speedOverrideTime = math.max(self.sphereChain.speedOverrideTime - dt, 0)
		end

		-- Reset the timer if the spheres are outside of the screen.
		if not self.nextGroup and self:getLastSphereOffset() < 0 and self.speedDesired <= 0 then
			self.sphereChain.speedOverrideTime = 0
		end

		if self.sphereChain.speedOverrideTime == 0 then
			-- The time has elapsed, reset values.
			self.sphereChain.speedOverrideBase = 0
			self.sphereChain.speedOverrideMult = 1
		end
	end

	-- Remove spheres at the end of path when the level is lost/it's a dummy path.
	if (self.map.level.lost and self.config.foulDestroySpheres.type == "atEnd") or self.map.isDummy then
		for i = #self.spheres, 1, -1 do
			if self:getSphereOffset(i) >= self.sphereChain.path.length then
				self:destroySphere(i)
			end
		end
	end

	-- Ultra-Safe Loop (TM)
	local i = 1
	while self.spheres[i] do
		local sphere = self.spheres[i]
		if not sphere.delQueue then
			sphere:update(dt)
		end
		if self.spheres[i] == sphere then
			i = i + 1
		end
	end
end

---Generates a Sphere at the back of this Sphere Group without any animation.
---@param color integer The sphere color.
---@param chainLevel integer? If set, the sphere will have that many chain layers on it.
function SphereGroup:pushSphereBack(color, chainLevel)
	self:addSphere(color, nil, nil, nil, 1, nil, nil, nil, nil, chainLevel)
end

---Generates a Sphere at the front of this Sphere Group without any animation.
---@param color integer The sphere color.
---@param chainLevel integer? If set, the sphere will have that many chain layers on it.
function SphereGroup:pushSphereFront(color, chainLevel)
	self:addSphere(color, nil, nil, nil, #self.spheres + 1, nil, nil, nil, nil, chainLevel)
end

---Adds a new sphere to this group.
---@param color integer The color of a sphere to be inserted.
---@param pos Vector2? The position in where was the shot sphere.
---@param time number? How long will that sphere "grow" until it's completely in its place.
---@param sphereEntity SphereEntity? A sphere entity to be used (nil = create a new entity).
---@param position integer The new sphere will gain this ID, which means it will be created BEHIND a sphere of this ID in this group.
---@param effects table? A list of Sphere Effects to be applied to the added sphere.
---@param gaps table? A list of gaps through which this sphere has traversed.
---@param destroyedFragileSpheres boolean? If set, this Sphere will be marked as a sphere which has destroyed at least one fragile sphere during its lifetime as a shot sphere.
---@param canStopGrowing boolean? If set, the new sphere will not grow if it constitutes a match.
---@param chainLevel integer? If set, the sphere will have that many chain layers on it.
function SphereGroup:addSphere(color, pos, time, sphereEntity, position, effects, gaps, destroyedFragileSpheres, canStopGrowing, chainLevel)
	local sphere = Sphere(self, nil, color, pos, time, sphereEntity, gaps, destroyedFragileSpheres, chainLevel)
	local prevSphere = self.spheres[position - 1]
	local nextSphere = self.spheres[position]
	sphere.prevSphere = prevSphere
	sphere.nextSphere = nextSphere
	if prevSphere then prevSphere.nextSphere = sphere end
	if nextSphere then nextSphere.prevSphere = sphere end
	table.insert(self.spheres, position, sphere)
	if effects then
		for i, effect in ipairs(effects) do
			sphere:applyEffect(effect)
		end
	end
	-- if it's a first sphere in the group, lower the offset
	if position == 1 then
		self.offset = self.offset - sphere:getDesiredSize() / 2
		if nextSphere then
			self.offset = self.offset - nextSphere:getDesiredSize() / 2
		end
		self:updateSphereOffsets()
	end
	sphere:updateOffset()
	-- If the new sphere can stop growing, we must check if it actually will.
	local stopGrowing = false
	if canStopGrowing then
		if self:getMatchLength(position) >= 3 then
			stopGrowing = true
		end
	end
	if stopGrowing then
		sphere:stopGrowing()
	else
		-- Destroy all frozen spheres at the front of the sphere in this group.
		self:destroyFragileSpheres(position + 1)
	end
end

---Returns the position at which a new sphere should be added.
---Used to make sure no spheres can be added behind scarabs.
---@param position integer The desired position of the added sphere.
---@return integer
function SphereGroup:getAddSpherePos(position)
	-- we can't add spheres behind the vise
	if not self.prevGroup and position == 1 and not self.config.noScarabs then
		return 2
	end
	return position
end

---Destroys the sphere at the given position.
---If the given sphere is in the middle of this group, it will be split.
---@param position integer The index of the sphere to be destroyed.
---@param crushed boolean? If specified, the targeted sphere will be destroyed as crushed. This is used for when a scarab is destroyed in a train merge event.
function SphereGroup:destroySphere(position, crushed)
	-- no need to divide if it's the first or last sphere in this group
	if position == 1 then
		-- Shift the group offset to the next sphere. It might not exist.
		self.offset = self.offset + self.spheres[position].config.size / 2
		if self.spheres[position + 1] then
			self.offset = self.offset + self.spheres[position + 1].config.size / 2
		end
		self.spheres[position]:delete(crushed)
		table.remove(self.spheres, position)
		self:updateSphereOffsets()
		self:checkUnfinishedDestructionAtSpawn()
	elseif position == #self.spheres then
		self.spheres[position]:delete(crushed)
		table.remove(self.spheres, position)
	else
		self:divide(position)
		self.spheres[position]:delete(crushed)
		table.remove(self.spheres, position)
	end

	self:checkDeletion()
end

---Visually destroys the sphere at the given position. Physically, the sphere is still going to exist in the group.
---@param position integer The index of the sphere to be destroyed.
---@param ghostTime number? If specified, the sphere will be physically removed after this time in seconds.
---@param crushed boolean? If specified, the targeted sphere will be destroyed as crushed. This is used for when a scarab is destroyed in a train merge event.
function SphereGroup:destroySphereVisually(position, ghostTime, crushed)
	self.spheres[position]:deleteVisually(ghostTime, crushed)
end

---Destroys a section of spheres from this Sphere Group.
---If the specified selection is in the middle of this Group, it will be split.
---@param position1 integer The index of the first sphere to be destroyed, inclusive.
---@param position2 integer The index of the last sphere to be destroyed, inclusive.
function SphereGroup:destroySpheres(position1, position2)
	assert(position1 <= position2, string.format("Illegal sphere range to be destroyed: from %s to %s", position1, position2))
	-- check if it's on the beginning or on the end of the group
	if position1 == 1 then
		-- Shift the group offset to the next sphere. It might not exist.
		self.offset = self.offset + self.spheres[position2].config.size / 2
		if self.spheres[position2 + 1] then
			self.offset = self.offset + self.spheres[position2 + 1].config.size / 2
		end
		for i = position1, position2 do
			self.spheres[1]:delete()
			table.remove(self.spheres, 1)
		end
		self:updateSphereOffsets()
		self:checkUnfinishedDestructionAtSpawn()
	elseif position2 == #self.spheres then -- or maybe on the end?
		for i = position1, position2 do
			self.spheres[#self.spheres]:delete()
			table.remove(self.spheres, #self.spheres)
		end
	else
		-- divide on the end of the broken spheres
		self:divide(position2)
		for i = position1, position2 do
			self.spheres[#self.spheres]:delete()
			table.remove(self.spheres, #self.spheres)
		end
	end

	self:checkDeletion()
end

---If this is an unfinished group, this means we're removing spheres at the spawn point.
---Thus, in order to avoid bugs, we need to create a new sphere group behind this one at the path origin point
---and flag that one as the new unfinished group.
---
---This function checks whether a sphere group has been completely gotten rid of spheres and spawns a new group if necessary.
function SphereGroup:checkUnfinishedDestructionAtSpawn()
	-- Spawn that sphere group only when there are no spheres behind the spawn point. Either in this, or the next sphere group.
	local noSpheresHere = #self.spheres == 0 or self:getBackOffset() > 0
	local noSpheresNext = not self.nextGroup or self.nextGroup:getBackOffset() > 0
	if self:isUnfinished() and noSpheresHere and noSpheresNext then
		local newGroup = SphereGroup(self.sphereChain, nil)
		-- Update group links.
		self.prevGroup = newGroup
		newGroup.nextGroup = self

		-- add to the master, on the back
		table.insert(self.sphereChain.sphereGroups, newGroup)
	elseif #self.spheres == 0 then
		-- If there's no fresh group which would be unfinished, we're passing that title to the next group. Let this one die...
		self:delete()
	end
end

---Updates offsets of all Spheres in this group.
function SphereGroup:updateSphereOffsets()
	for i, sphere in ipairs(self.spheres) do
		sphere:updateOffset()
	end
end

---Checks whether this group should trigger Distance Events which are defined in `gameplay.json`, and triggers them.
function SphereGroup:updateDistanceEvents()
	-- Abort if no Distance Events are defined.
	if not self.config.distanceEvents then
		return
	end
	-- Go through Distance Events.
	for i, event in ipairs(self.config.distanceEvents) do
		local refDistance = event.reference == "front" and self:getFrontOffset() or self:getBackOffset()
		local distance = self.sphereChain.path.length * event.distance
		local rolledPast = refDistance > distance
		if not self.distanceEventStates[i] then
			self.distanceEventStates[i] = {rolledPast = rolledPast}
		else
			if event.forwards and rolledPast and not self.distanceEventStates[i].rolledPast then
				_Game:executeGameEvent(event.event)
			end
			if event.backwards and not rolledPast and self.distanceEventStates[i].rolledPast then
				_Game:executeGameEvent(event.event)
			end
			self.distanceEventStates[i].rolledPast = rolledPast
		end
	end
end

---Checks whether this Sphere Group, and by proxy its host Sphere Chain, should be destroyed.
---This happens when the group is empty or only contains the scarab and there are no other sphere groups in this Chain.
function SphereGroup:checkDeletion()
	-- abort if this group is unfinished
	if self:isUnfinished() then
		return
	end
	-- if this group contains no spheres, it gets yeeted
	local shouldDelete = true
	for i, sphere in ipairs(self.spheres) do
		if not sphere.delQueue then
			shouldDelete = false
		end
	end
	if shouldDelete then
		self:delete()
	end

	-- if there's only a vise in this chain, or this chain is completely empty, the whole chain gets yeeted!
	-- TODO: Move this logic to SphereChain.lua
	if not self.prevGroup and not self.nextGroup then
		if #self.spheres == 0 then
			self.sphereChain:delete(false)
		elseif not self.config.noScarabs then
			if #self.spheres == 1 and self.spheres[1].color == 0 then
				self.spheres[1]:delete()
				self.sphereChain:delete(false)
			end
		end
	end
end

---Returns `true` if this Sphere Group is in state which causes the level to be lost.
---@private
---@return boolean
function SphereGroup:shouldCauseLevelLoss()
	if self:getLastSphereOffset() < self.sphereChain.path.length then
		return false
	end
	if self:isMagnetizing() then
		return false
	end
	if self:hasShotSpheres() then
		return false
	end
	if self:hasLossProtectedSpheres() then
		return false
	end
	if self:hasGhostSpheres() then
		return false
	end
	if self.map.isDummy then
		return false
	end
	return true
end

---Moves this Sphere Group by a certain distance.
---@param offset number Distance to move this Group in pixels.
function SphereGroup:move(offset)
	self.offset = self.offset + offset
	self:updateSphereOffsets()
	-- If reached the end of the level, it's over.
	if self:shouldCauseLevelLoss() then
		self.map.level:lose()
	end
	-- Update Distance Events.
	if not self.map.level.lost and not self.map.isDummy then
		self:updateDistanceEvents()
	end
	-- Check frozen spheres.
	if offset ~= 0 then
		--self:destroyFragileSpheres()
	end
	-- Check collisions.
	if offset <= 0 then
		-- if it's going to crash into the previous group, move only what is needed
		-- join the previous group if this group starts to overlap the previous one
		if self.prevGroup and #self.prevGroup.spheres > 0 and self:getBackOffset() - self.prevGroup:getFrontOffset() < 0 then
			self:join()
		end
	end
	-- check the other direction too
	if offset > 0 then
		if self.nextGroup and self.nextGroup:getBackOffset() - self:getFrontOffset() < 0 then
			self.nextGroup:join()
		end
	end
end

---Joins this Sphere Group with the previous Sphere Group, if it exists.
---During the process, this Sphere Group is destroyed.
---This function also checks for matches, fragile spheres and applies appropriate knockback.
function SphereGroup:join()
	-- join this group with a previous group
	-- the first group has nothing to join to
	if not self.prevGroup then
		return
	end
	-- deploy the value to check for combo and linking later
	local joinPosition = #self.prevGroup.spheres
	-- modify the previous group to contain the joining spheres
	for i, sphere in ipairs(self.spheres) do
		table.insert(self.prevGroup.spheres, sphere)
		sphere.sphereGroup = self.prevGroup
	end
	-- Apply appropriate knockback.
	if self.speed < 0 then
		local cascade = self:getCascade()
		if self.config.luxorized and self.speedDesired < 0 and cascade == 0 then
			-- Reverse powerup in OG Luxor works a bit wonky.
			self.prevGroup.speed = self.speed
		else
			self.prevGroup.speed = self.config.knockbackSpeedBase + self.config.knockbackSpeedMult * math.max(cascade, 1)
		end
		self.prevGroup.speedTime = self.config.knockbackTime
	end
	-- link the spheres from both groups
	self.prevGroup.spheres[joinPosition].nextSphere = self.spheres[1]
	self.spheres[1].prevSphere = self.prevGroup.spheres[joinPosition]
	-- recalculate sphere positions
	self.prevGroup:updateSphereOffsets()
	-- remove this group
	self:delete()
	-- check for combo
	if not self.map.level.lost and self.map.level:colorsMatch(self.prevGroup.spheres[joinPosition].color, self.spheres[1].color) and self.matchCheck and self.prevGroup:shouldMatch(joinPosition) then
		self.prevGroup:matchAndDelete(joinPosition)
	end
	-- check for fragile spheres
	self.prevGroup:destroyFragileSpheres()
	self:destroyFragileSpheres()
	-- play a sound
	local x, y = self.sphereChain.path:getPos(self.offset)
	self.config.joinSound:play(x, y)
end

---Divides this Sphere Group into two Sphere Groups.
---@param position integer The index of the sphere. The split will happen between that and the next sphere.
function SphereGroup:divide(position)
	-- example:
	-- group: ooooooo
	-- position: 3
	-- groups after: ooo | oooo
	-- that means this group will remain with 3 spheres (the break appears AFTER the specified position) and the rest will be given to a new group

	-- first, create a new group and give its properties there
	local newGroup = SphereGroup(self.sphereChain)
	newGroup.offset = self:getSphereOffset(position + 1)
	newGroup.speed = self.config.knockbackStopAfterTime and 0 or self.speed
	for i = position + 1, #self.spheres do
		local sphere = self.spheres[i]
		sphere.sphereGroup = newGroup
		table.insert(newGroup.spheres, sphere)
		self.spheres[i] = nil
	end
	-- break sphere links between two new groups
	self.spheres[position].nextSphere = nil
	newGroup.spheres[1].prevSphere = nil
	-- recalculate sphere positions
	newGroup:updateSphereOffsets()
	-- rearrange group links
	newGroup.prevGroup = self
	newGroup.nextGroup = self.nextGroup
	if self.nextGroup then
		self.nextGroup.prevGroup = newGroup
	end
	-- here, the previous group stays the same
	self.nextGroup = newGroup

	-- add to the master
	-- TODO: Move this logic to SphereChain.lua...?
	table.insert(self.sphereChain.sphereGroups, assert(self.sphereChain:getSphereGroupID(self)), newGroup)
end

---Destroys this Sphere Group.
---This function **does not** destroy spheres contained in this Group. Use `:destroy()` for that purpose instead.
function SphereGroup:delete()
	if self.delQueue then
		return
	end
	-- do this if this group is empty
	self.delQueue = true
	-- update links !!!
	if self.prevGroup then
		self.prevGroup.nextGroup = self.nextGroup
		self.prevGroup:checkDeletion() -- if the vise might be alone in its own group and last spheres ahead of him are being just destroyed
	end
	if self.nextGroup then
		self.nextGroup.prevGroup = self.prevGroup
	end
	-- TODO: Move this logic to SphereChain.lua
	table.remove(self.sphereChain.sphereGroups, self.sphereChain:getSphereGroupID(self))
end

---Checks this Sphere Group for spheres with a Sphere Effect which is configured as `fragile`, and if so, destroys them.
---@param startFrom integer? If set, checks only spheres starting with the provided index and to the front of the group.
function SphereGroup:destroyFragileSpheres(startFrom)
	-- Ultra-Safe Loop (TM)
	local i = startFrom or 1
	while self.spheres[i] do
		local sphere = self.spheres[i]
		if not sphere.delQueue and sphere:isFragile() then
			sphere:matchEffectFragile()
		end
		if self.spheres[i] == sphere then
			i = i + 1
		end
	end
end

---Unloads all spheres contained in this Sphere Group.
function SphereGroup:destroy()
	for i, sphere in ipairs(self.spheres) do
		sphere:destroy()
	end
end

---Returns `true` if the sphere at the given position matches at least one of its neighbors by color.
---@param position integer The sphere index in this sphere group.
---@return boolean
function SphereGroup:shouldFit(position)
	return
		self:getSphereInChain(position - 1) and self.map.level:colorsMatch(self:getSphereInChain(position - 1).color, self.spheres[position].color)
	or
		self:getSphereInChain(position + 1) and self.map.level:colorsMatch(self:getSphereInChain(position + 1).color, self.spheres[position].color)
	or false
end

---Returns `true` if the sphere at the given position in this group will match - the streak combo should not be reset and the sphere should be marked as streak-boosting.
---@param position integer The sphere index in this sphere group.
---@return boolean
function SphereGroup:shouldBoostStreak(position)
	return self:getMatchLengthInChain(position) >= 3
end

---Returns `true` if the sphere at the given position can now perform a match.
---@param position integer The sphere index in this sphere group.
---@return boolean
function SphereGroup:shouldMatch(position)
	local position1, position2 = self:getMatchBounds(position)
	-- if not enough spheres
	if position2 - position1 < 2 then
		return false
	end
	if self.config.permitLongMatches then
		-- if is magnetizing with previous group and we want to maximize the count of spheres
		-- We are doing a check whether that previous group is empty. It CAN be empty, if the Zuma sphere generation is enabled.
		if self.prevGroup and #self.prevGroup.spheres > 0 and not self.prevGroup.delQueue and self.map.level:colorsMatch(self.prevGroup:getLastSphere().color, self.spheres[1].color) and position1 == 1 then
			return false
		end
		-- same check with the next group
		if self.nextGroup and not self.nextGroup.delQueue and self.map.level:colorsMatch(self:getLastSphere().color, self.nextGroup.spheres[1].color) and position2 == #self.spheres then
			return false
		end
	end
	-- all checks passed?
	return true
end

---Checks for a match at the given position and, if all requirements are satisfied, applies a `match` Sphere Effect from the Level Config file to all involved spheres.
---@param position integer The sphere index in this sphere group which should be checked.
function SphereGroup:matchAndDelete(position)
	local position1, position2 = self:getMatchBounds(position)

	local boostStreak = false
	-- abort if any sphere from the given ones has not joined yet and see if we have to boost the combo
	for i = position1, position2 do
		if not self.spheres[i]:isReadyForMatching() then
			return
		end
		boostStreak = boostStreak or self.spheres[i].boostStreak
	end

	-- First, check if any of the matched spheres do have the match effect already.
	local effectConfig = self.map.level.matchEffect
	local effectGroupID = nil
	for i = position1, position2 do
		if self.spheres[i]:hasEffect(effectConfig) then
			effectGroupID = self.spheres[i]:getEffectGroupID(effectConfig)
			break
		end
	end
	-- If not found, create a new sphere effect group with a sphere at position, so that sphere is noted down as a cause.
	if not effectGroupID then
		effectGroupID = self.sphereChain.path:createSphereEffectGroup(self.spheres[position])
	end
	-- Now, apply the effect.
	for i = position1, position2 do
		self.spheres[i]:applyEffect(effectConfig, nil, nil, effectGroupID)
	end
end

---Destroys a group of spheres with the given effect at the given position.
---@param position integer The sphere index in this group that will be the origin ("cause") sphere.
---@param effectConfig SphereEffectConfig The sphere effect config which the sphere at the given position MUST have, otherwise this function will throw an error.
function SphereGroup:matchAndDeleteEffect(position, effectConfig)
	local effectGroupID = assert(self.spheres[position]:getEffectGroupID(effectConfig), string.format("Assertion failed: no effect %s found on sphere %s!", effectConfig._path, position))

	-- Prepare a list of spheres to be destroyed.
	local spheres = {}
	local position1 = nil
	local position2 = 0
	if effectConfig.causeCheck then
		-- Cause check: destroy all spheres in the same group if they have the same cause.
		for i, sphere in ipairs(self.spheres) do
			if sphere:hasEffect(effectConfig, effectGroupID) and not sphere:isGhost() then
				table.insert(spheres, sphere)
				if not position1 then
					position1 = i
				end
				position2 = i
			end
		end
	else
		-- No cause check: destroy all spheres in the same group if they lay near each other.
		position1, position2 = self:getEffectBounds(position, effectConfig)
		for i = position1, position2 do
			if not self.spheres[i]:isGhost() then
				table.insert(spheres, self.spheres[i])
			end
		end
	end

	local length = #spheres
	-- If there are precisely zero spheres to be destroyed, abort.
	if length == 0 then
		return
	end

	local prevSphere = self.spheres[position1 - 1]
	local nextSphere = self.spheres[position2 + 1]

	local boostStreak = false
	-- Abort if any sphere from the given ones has not joined yet and see if we have to boost the combo.
	for i, sphere in ipairs(spheres) do
		if not sphere:isReadyForMatching() then
			return
		end
		boostStreak = boostStreak or sphere.boostStreak
	end
	boostStreak = boostStreak and effectConfig.canBoostStreak

	-- Retrieve and simplify a list of gaps. Only the cause sphere is checked.
	local gaps = self.spheres[position].gaps

	-- Check if the match contains a sphere which has destroyed a frozen segment.
	local destroyedFragileSpheres = false
	for i, sphere in ipairs(spheres) do
		if sphere.destroyedFragileSpheres then
			destroyedFragileSpheres = true
			break
		end
	end



	-- Determine the center position and destroy spheres.
	local x, y = self.sphereChain.path:getPos((self:getSphereOffset(position1) + self:getSphereOffset(position2)) / 2)
	local color = self.sphereChain.path:getSphereEffectGroup(effectGroupID).cause.color
	for i = #spheres, 1, -1 do
		local sphere = spheres[i]
		local n = self:getSphereID(sphere)
		if not effectConfig.destroyChainedSpheres and sphere:isChained() then
			sphere:breakChainLevel()
			sphere:removeAllEffects()
		elseif effectConfig.ghostTime then
			self:destroySphereVisually(n, effectConfig.ghostTime)
		else
			self:destroySphere(n)
		end
	end

	-- Destroy adjacent spheres if they are stone spheres.
	if nextSphere and nextSphere:isStone() then
		local group = nextSphere.sphereGroup
		group:destroySphere(group:getSphereID(nextSphere))
	end
	if prevSphere and prevSphere:isStone() then
		local group = prevSphere.sphereGroup
		group:destroySphere(group:getSphereID(prevSphere))
	end

	-- Now that we've finished destroying the spheres, we can adjust the group speed.
	-- TODO: This is dirty. See issue #121 for a potential resolution.
	if self.config.luxorized and self.nextGroup and self.nextGroup.speed < 0 and #self.spheres > 0 then
		if self:getLastSphere().color == 0 or not self.nextGroup:isMagnetizing() then
			-- Stop the sphere group in front of us like how Luxor does (when there will be no further magnetization).
			self.nextGroup.speed = 0
		elseif self.speedDesired < 0 then
			-- Or at the back, if the reverse powerup is currently active.
			self.speed = 0
		end
	end

	-- Boost chain and combo values.
	if effectConfig.canBoostCascade then
		self:incrementCascade()
	end
	if boostStreak then
		self:incrementStreak()
	end

	-- Spawn collectibles, play sounds, add score, etc.
	_Vars:set("match.length", length)
	_Vars:set("match.streak", self:getStreak())
	_Vars:set("match.streakBoost", boostStreak)
	_Vars:set("match.cascade", self:getCascade())
	_Vars:set("match.gapCount", #gaps)
	_Vars:set("match.color", color)
	_Vars:set("match.destroyedFragileSpheres", destroyedFragileSpheres)
	-- Execute the "before" game events.
	if effectConfig.eventsBefore then
		for i, event in ipairs(effectConfig.eventsBefore) do
			_Game:executeGameEvent(event)
		end
	end
	-- Play sounds.
	if effectConfig.destroySound then
		effectConfig.destroySound:play(x, y)
	end
	-- Execute a score event.
	if effectConfig.destroyScoreEvent then
		local score = self.map.level:executeScoreEvent(effectConfig.destroyScoreEvent, x, y)
		self:addToCascadeScore(score)
	end
	-- Spawn any collectibles if applicable.
	if effectConfig.destroyCollectible then
		self.map.level:spawnCollectiblesFromEntry(effectConfig.destroyCollectible, x, y)
	end
	-- Execute the "after" game events.
	if effectConfig.eventsAfter then
		for i, event in ipairs(effectConfig.eventsAfter) do
			_Game:executeGameEvent(event)
		end
	end
	_Vars:unset("match")
end

---Removes a substring of ghost spheres at the given position.
---@param position integer The sphere index in this group.
function SphereGroup:deleteGhost(position)
	-- Prepare a list of spheres to be destroyed.
	local position1, position2 = self:getGhostBounds(position)
	self:destroySpheres(position1, position2)
end

---Returns whether this Sphere Group should be attracted to the previous Sphere Group, if it exists.
---@return boolean
function SphereGroup:isMagnetizing()
	--print("----- " .. (self.prevGroup and self.prevGroup:getDebugText() or "xxx") .. " -> " .. self:getDebugText() .. " -> " .. (self.nextGroup and self.nextGroup:getDebugText() or "xxx"))
	--print("----- " .. tostring(self.sphereChain:getSphereGroupID(self.prevGroup)) .. " -> " .. tostring(self.sphereChain:getSphereGroupID(self)) .. " -> " .. tostring(self.sphereChain:getSphereGroupID(self.nextGroup)))

	-- If this group is empty, is pending deletion or would have nothing to magnetize to, abort.
	if not self.prevGroup or self.prevGroup.delQueue or #self.spheres == 0 then
		return false
	end

	-- Get mature spheres on both ends.
	local sphere1 = self.prevGroup:getLastMatureSphere()
	local sphere2 = self:getFirstMatureSphere()

	-- If there are no candidate spheres, abort.
	if not sphere1 or not sphere2 then
		return false
	end

	-- Abort if there are ghost spheres on any end.
	if sphere1:isGhost() or sphere2:isGhost() then
		return false
	end

	-- Check if on each side of the empty area there's the same color.
	local byColor = self.map.level:colorsMatch(sphere1.color, sphere2.color)
	-- The scarab can magnetize any color.
	local byScarab = sphere1.color == 0 and not self.config.noScarabAttraction


	return byColor or byScarab
end

---Increments the cascade combo value of either this group's Sphere Train or Path, depending on the behavior.
---Also, updates the cascade combo record for this level if appropriate.
function SphereGroup:incrementCascade()
	if self.config.cascadeScope == "chain" then
		self.sphereChain.cascade = self.sphereChain.cascade + 1
		self.map.level.maxCascade = math.max(self.map.level.maxCascade, self.sphereChain.cascade)
	elseif self.config.cascadeScope == "path" then
		self.sphereChain.path.cascade = self.sphereChain.path.cascade + 1
		self.map.level.maxCascade = math.max(self.map.level.maxCascade, self.sphereChain.path.cascade)
	elseif self.config.cascadeScope == "level" then
		self.map.level.cascade = self.map.level.cascade + 1
		self.map.level.maxCascade = math.max(self.map.level.maxCascade, self.map.level.cascade)
	end
end

---Returns the cascade combo value of either this group's Sphere Train or Path, depending on the behavior.
---@return integer
function SphereGroup:getCascade()
	if self.config.cascadeScope == "chain" then
		return self.sphereChain.cascade
	elseif self.config.cascadeScope == "path" then
		return self.sphereChain.path.cascade
	elseif self.config.cascadeScope == "level" then
		return self.map.level.cascade
	end
	return 1
end

---Adds the provided amount of points to the currently ongoing cascade combo's score.
---@param score integer The score to be added.
function SphereGroup:addToCascadeScore(score)
	if self.config.cascadeScope == "chain" then
		self.sphereChain.cascadeScore = self.sphereChain.cascadeScore + score
	elseif self.config.cascadeScope == "path" then
		self.sphereChain.path.cascadeScore = self.sphereChain.path.cascadeScore + score
	elseif self.config.cascadeScope == "level" then
		self.map.level.cascadeScore = self.map.level.cascadeScore + score
	end
end

---Increments the streak combo value for this group's level.
---Also, updates the streak combo record for this level if appropriate.
function SphereGroup:incrementStreak()
	self.map.level.streak = self.map.level.streak + 1
	self.map.level.maxStreak = math.max(self.map.level.streak, self.map.level.maxStreak)
end

---Returns the streak combo value for this group's level.
---@return integer
function SphereGroup:getStreak()
	return self.map.level.streak
end

---Draws the Sphere Group on the screen.
function SphereGroup:draw()
	--love.graphics.print(self:getDebugText2(), 10, 10 * #self.spheres)
	for i, sphere in ipairs(self.spheres) do
		sphere:draw()
	end
	if _Debug.gameDebugVisible then
		self:drawDebug()
	end
end

---Draws debug information of this Sphere Group: front and back position indicators, and where the group offset points to.
function SphereGroup:drawDebug()
	if #self.spheres == 0 then
		return
	end
	local x, y = self.sphereChain.path:getPos(self:getFrontOffset())
	love.graphics.setColor(0.5, 1, 0)
	love.graphics.circle("fill", x, y, 6)
	local x, y = self.sphereChain.path:getPos(self:getBackOffset())
	love.graphics.setColor(1, 0.5, 0)
	love.graphics.circle("fill", x, y, 6)
	local x, y = self.sphereChain.path:getPos(self.offset)
	love.graphics.setColor(1, 1, 1)
	love.graphics.circle("fill", x, y, 4)
end

---Returns the first and last sphere index from this group, representing a continuous chunk of spheres, which all match the sphere at the given position.
---@param position integer The index of the sphere which will be the search origin.
---@return integer, integer
function SphereGroup:getMatchBounds(position)
	local position1 = position
	local position2 = position
	-- seek backwards
	while true do
		position1 = position1 - 1
		-- end if no more spheres or found an unmatched sphere
		if not self.spheres[position1] or not self.map.level:colorsMatch(self.spheres[position1].color, self.spheres[position1 + 1].color) then
			break
		end
	end
	-- seek forwards
	while true do
		position2 = position2 + 1
		-- end if no more spheres or found an unmatched sphere
		if not self.spheres[position2] or not self.map.level:colorsMatch(self.spheres[position2].color, self.spheres[position2 - 1].color) then
			break
		end
	end
	return position1 + 1, position2 - 1
end

---Similar to `:getMatchBounds()`, but instead of returning the first and last sphere index of the given substring, returns the amount of spheres contained in the found substring.
---@param position integer The starting sphere index in this group to be considered.
---@return integer
function SphereGroup:getMatchLength(position)
	local position1, position2 = self:getMatchBounds(position)
	return position2 - position1 + 1
end

---Returns the first and last sphere index from this group, representing a continuous chunk of spheres, which all have the provided Sphere Effect.
---@param position integer The index of the sphere which will be the search origin.
---@param effectConfig SphereEffectConfig The config of the Sphere Effect which will be searched for.
---@param effectGroupID integer? If given, the continuous chunk of spheres will be guaranteed to have this particular effect group ID.
---@return integer, integer
function SphereGroup:getEffectBounds(position, effectConfig, effectGroupID)
	local position1 = position
	local position2 = position
	-- seek backwards
	while true do
		position1 = position1 - 1
		-- end if no more spheres or found an unmatched sphere
		if not self.spheres[position1] or not self.spheres[position1]:hasEffect(effectConfig, effectGroupID) then
			break
		end
	end
	-- seek forwards
	while true do
		position2 = position2 + 1
		-- end if no more spheres or found an unmatched sphere
		if not self.spheres[position2] or not self.spheres[position2]:hasEffect(effectConfig, effectGroupID) then
			break
		end
	end
	return position1 + 1, position2 - 1
end

---Returns the first and last sphere index from this group, representing a continuous chunk of spheres, which all are ghosts (have been visually deleted).
---@param position integer The index of the sphere which will be the search origin.
---@return integer, integer
function SphereGroup:getGhostBounds(position)
	local position1 = position
	local position2 = position
	-- seek backwards
	while true do
		position1 = position1 - 1
		-- end if no more spheres or found an unmatched sphere
		if not self.spheres[position1] or not self.spheres[position1]:isGhostForDeletion() then
			break
		end
	end
	-- seek forwards
	while true do
		position2 = position2 + 1
		-- end if no more spheres or found an unmatched sphere
		if not self.spheres[position2] or not self.spheres[position2]:isGhostForDeletion() then
			break
		end
	end
	return position1 + 1, position2 - 1
end

---Returns the total length of a potential match at the given sphere, including neighboring sphere groups in this sphere chain.
---@param position integer The index of the sphere which will be the search origin.
---@return integer
function SphereGroup:getMatchLengthInChain(position)
	-- special seek for a shouldBoostStreak function
	local position1 = position
	local position2 = position
	-- seek backwards
	while true do
		position1 = position1 - 1
		-- end if no more spheres or found an unmatched sphere
		if not self:getSphereInChain(position1) or not self.map.level:colorsMatch(self:getSphereInChain(position1).color, self:getSphereInChain(position1 + 1).color) then
			break
		end
	end
	-- seek forwards
	while true do
		position2 = position2 + 1
		-- end if no more spheres or found an unmatched sphere
		if not self:getSphereInChain(position2) or not self.map.level:colorsMatch(self:getSphereInChain(position2).color, self:getSphereInChain(position2 - 1).color) then
			break
		end
	end
	return position2 - position1 - 1
end

---Returns the colors next to a potential match at the given sphere, including neighboring sphere groups in this sphere chain.
---If at either end there is no extra sphere after or before the found match, `nil` is returned in place of the color.
---@param position integer The index of the sphere which will be the search origin.
---@return integer?, integer?
function SphereGroup:getMatchBoundColorsInChain(position)
	-- special seek for a lightning storm search algorithm
	local position1 = position
	local position2 = position
	-- seek backwards
	while true do
		position1 = position1 - 1
		-- end if no more spheres or found an unmatched sphere
		if not self:getSphereInChain(position1) or not self.map.level:colorsMatch(self:getSphereInChain(position1).color, self:getSphereInChain(position1 + 1).color) then
			break
		end
	end
	-- seek forwards
	while true do
		position2 = position2 + 1
		-- end if no more spheres or found an unmatched sphere
		if not self:getSphereInChain(position2) or not self.map.level:colorsMatch(self:getSphereInChain(position2).color, self:getSphereInChain(position2 - 1).color) then
			break
		end
	end
	return self:getSphereInChain(position1) and self:getSphereInChain(position1).color, self:getSphereInChain(position2) and self:getSphereInChain(position2).color
end

---Returns the first Sphere in this Group (the backmost one, sometimes it's the scarab).
---Returns `nil` if this Sphere Group is empty.
---@return Sphere?
function SphereGroup:getFirstSphere()
	return self.spheres[1]
end

---Returns the last Sphere in this Group (the frontmost one).
---Returns `nil` if this Sphere Group is empty.
---@return Sphere?
function SphereGroup:getLastSphere()
	return self.spheres[#self.spheres]
end

---Returns the first (backmost) Sphere in this Group, ignoring Spheres which have not been fully appended to this group yet.
---Returns `nil` if none of the spheres match this condition.
---@return Sphere?
function SphereGroup:getFirstMatureSphere()
	for i = 1, #self.spheres do
		if self.spheres[i].appendSize == 1 then
			return self.spheres[i]
		end
	end
end

---Returns the last (frontmost) Sphere in this Group, ignoring Spheres which have not been fully appended to this group yet.
---Returns `nil` if none of the spheres match this condition.
---@return Sphere?
function SphereGroup:getLastMatureSphere()
	for i = #self.spheres, 1, -1 do
		if self.spheres[i].appendSize == 1 then
			return self.spheres[i]
		end
	end
end

---Returns the path offset at which the specified sphere is at, in pixels.
---@param position integer The sphere index in this sphere group.
---@return number
function SphereGroup:getSphereOffset(position)
	return self.spheres[position]:getOffset()
end

---Returns the size of the sphere at which the specified sphere is at, in pixels.
---@param position integer The sphere index in this sphere group.
---@return number
function SphereGroup:getSphereSize(position)
	return self.spheres[position]:getSize()
end

---Returns the onscreen position at which the specified sphere is at.
---@param position integer The sphere index in this sphere group.
---@return Vector2
function SphereGroup:getSpherePos(position)
	return self.spheres[position]:getPos()
end

---Returns the index of the provided Sphere in this Sphere Group.
---Returns `nil` if the provided Sphere is not in this group.
---@param sphere Sphere The sphere to be looked for.
---@return integer?
function SphereGroup:getSphereID(sphere)
	return _Utils.iTableGetValueIndex(self.spheres, sphere)
end

---Returns the path offset at which the last (frontmost) sphere is at, in pixels.
---@return number
function SphereGroup:getLastSphereOffset()
	return self:getSphereOffset(#self.spheres)
end

---Returns the size of the last (frontmost) sphere, in pixels.
---@return number
function SphereGroup:getLastSphereSize()
	return self:getSphereSize(#self.spheres)
end

---Returns the last Sphere Group in this group's Sphere Chain.
---@return SphereGroup
function SphereGroup:getLastGroup()
	local group = self
	while group.nextGroup do
		group = group.nextGroup
	end
	return group
end

---Returns the last Sphere Group in the backmost Sphere Chain, if this Group is a part of a daisy-chained Sphere Chain.
---@return SphereGroup
function SphereGroup:getLastChainedGroup()
	local group = self
	while not group.nextGroup and group.sphereChain:isPushingFrontTrain() do
		group = group.sphereChain:getPreviousChain():getLastSphereGroup()
	end
	return group
end

---Returns the offset of the head of this Sphere Group on its path, in pixels.
---@return number
function SphereGroup:getFrontOffset()
	return self:getLastSphereOffset() + self:getLastSphereSize() / 2
end

---Returns the offset of the tail of this Sphere Group on its path, in pixels.
---@return number
function SphereGroup:getBackOffset()
	return self:getSphereOffset(1) - self:getSphereSize(1) + self.spheres[1].config.size / 2
end

---Returns the sphere based on the given index.
---If an out-of-bounds index has been provided, a respective sphere from within the chain will be attempted to be returned.
---@param position integer The sphere index in this sphere group.
---@return Sphere?
function SphereGroup:getSphereInChain(position)
	-- values out of bounds are possible, it will seek in neighboring spheres then
	if position < 1 then
		-- previous group
		if not self.prevGroup or self.prevGroup.delQueue then
			return nil
		end
		return self.prevGroup:getSphereInChain(position + #self.prevGroup.spheres)
	elseif position > #self.spheres then
		-- next group
		if not self.nextGroup or self.nextGroup.delQueue then
			return nil
		end
		return self.nextGroup:getSphereInChain(position - #self.spheres)
	else
		-- this group
		return self.spheres[position]
	end
end

---Returns `true` if this Sphere Group contains at least one sphere which is not yet ready for matching.
---@return boolean
function SphereGroup:hasShotSpheres()
	for i, sphere in ipairs(self.spheres) do
		if not sphere:isReadyForMatching() then
			return true
		end
	end
	return false
end

---Returns `true` if this Sphere Group contains at least one sphere which is marked as loss-protected, `false` otherwise.
---@return boolean
function SphereGroup:hasLossProtectedSpheres()
	for i, sphere in ipairs(self.spheres) do
		if sphere:hasLossProtection() then
			return true
		end
	end
	return false
end

---Returns `true` if this Sphere Group contains at least one immobile sphere, `false` otherwise.
---@return boolean
function SphereGroup:hasImmobileSpheres()
	for i, sphere in ipairs(self.spheres) do
		if sphere:isImmobile() then
			return true
		end
	end
	return false
end

---Returns `true` if this Sphere Group contains at least one fragile sphere, `false` otherwise.
---@return boolean
function SphereGroup:hasFragileSpheres()
	for i, sphere in ipairs(self.spheres) do
		if sphere:isFragile() then
			return true
		end
	end
	return false
end

---Returns `true` if this Sphere Group contains at least one sphere that can keep the cascade combo, `false` otherwise.
---@return boolean
function SphereGroup:hasKeepCascadeSpheres()
	for i, sphere in ipairs(self.spheres) do
		if sphere:canKeepCascade() then
			return true
		end
	end
	return false
end

---Returns `true` if this Sphere Group contains at least one ghost sphere, `false` otherwise.
---@return boolean
function SphereGroup:hasGhostSpheres()
	for i, sphere in ipairs(self.spheres) do
		if sphere:isGhost() then
			return true
		end
	end
	return false
end

---Returns whether this Sphere Group can still generate more spheres.
---@return boolean
function SphereGroup:isUnfinished()
	return self.sphereChain.generationAllowed and not self.prevGroup
end

---Returns a string which contains the sphere colors in this Sphere Group in order, for example `[1234567]`.
---@return string
function SphereGroup:getDebugText()
	local text = ""
	text = text .. "["
	for j, sphere in ipairs(self.spheres) do
		text = text .. tostring(sphere.color)
	end
	text = text .. "]"
	return text
end

---Returns a string which contains some debug data of this Sphere Group.
---@return string
function SphereGroup:getDebugText2()
	-- For example:
	-- xxx -> 1 -> 2
	-- 1 -> 2 -> 3
	-- 2 -> 3 -> 4
	-- 3 -> 4 -> 5
	-- 4 -> 5 -> 6
	-- 5 -> 6 -> 7
	-- 6 -> 7 -> xxx
	local text = ""
	for i, sphere in ipairs(self.spheres) do
		if sphere.prevSphere then
			text = text .. tostring(sphere.prevSphere.color)
		else
			text = text .. "xxx"
		end
		text = text .. " -> " .. tostring(sphere.color) .. " -> "
		if sphere.nextSphere then
			text = text .. tostring(sphere.nextSphere.color)
		else
			text = text .. "xxx"
		end
		text = text .. "\n"
	end
	return text
end

---Returns the indices of this Sphere Group which identify this Group at this very frame.
---@return {groupID: integer, chainID: integer, pathID: integer}
function SphereGroup:getIDs()
	local g = self
	local c = g.sphereChain
	local p = c.path
	local m = p.map

	local groupID = c:getSphereGroupID(g)
	local chainID = p:getSphereChainID(c)
	local pathID = m:getPathID(p)

	return {
		groupID = groupID,
		chainID = chainID,
		pathID = pathID
	}
end

---Returns data of this Sphere Group that can be saved in a JSON file and later reloaded using `:deserialize()`.
---@return table
function SphereGroup:serialize()
	local t = {
		offset = self.offset,
		speed = self.speed,
		speedTime = self.speedTime,
		spheres = {},
		matchCheck = self.matchCheck,
		distanceEventStates = self.distanceEventStates
	}
	for i, sphere in ipairs(self.spheres) do
		table.insert(t.spheres, sphere:serialize())
	end
	return t
end

---Deserializes this Sphere Group and sets its state based on data gathered in `:serialize()`.
---@param t table The save data to be loaded.
function SphereGroup:deserialize(t)
	self.offset = t.offset
	self.speed = t.speed
	self.speedTime = t.speedTime
	self.spheres = {}
	local offset = 0
	for i, sphere in ipairs(t.spheres) do
		local s = Sphere(self, sphere)
		s.offset = offset
		-- links are mandatory!!!
		if i > 1 then
			s.prevSphere = self.spheres[i - 1]
			self.spheres[i - 1].nextSphere = s
		end
		table.insert(self.spheres, s)
	end
	self.matchCheck = t.matchCheck
	self.distanceEventStates = t.distanceEventStates
	self:updateSphereOffsets()
end

return SphereGroup
