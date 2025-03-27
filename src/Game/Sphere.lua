### This class is not used yet. All sphere algorithms are stored in SphereGroup.lua.

local class = require "com.class"

---Represents a single Sphere which is inside of a Sphere Group on the board. Can have a lot of properties.
---@class Sphere
---@overload fun(sphereGroup, deserializationTable, color, shootOrigin, shootTime, sphereEntity, gaps, destroyedFragileSpheres):Sphere
local Sphere = class:derive("Sphere")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")
local SphereEntity = require("src.Game.SphereEntity")



---Constructs a new Sphere.
---@param sphereGroup SphereGroup The sphere group this sphere belongs to.
---@param deserializationTable table? If set, internal data will be loaded from this table.
---@param color integer The type/color ID of this Sphere.
---@param shootOrigin Vector2? If set, the position of Shot Sphere which has been transformed into this Sphere. It also implies that it will be inserted from that position.
---@param shootTime number? The duration of the sphere insertion animation.
---@param sphereEntity SphereEntity? If set, this will be the Sphere Entity used to draw this Sphere. Else, a new one will be created.
---@param gaps table? If set, this Sphere will have a list of numbers (traversed gap distances) stored so it can be used later when calculating gap shots.
---@param destroyedFragileSpheres boolean? If set, this Sphere will be marked as a sphere which has destroyed at least one fragile sphere during its lifetime as a shot sphere.
function Sphere:new(sphereGroup, deserializationTable, color, shootOrigin, shootTime, sphereEntity, gaps, destroyedFragileSpheres)
	self.sphereGroup = sphereGroup
	self.path = sphereGroup.sphereChain.path
	self.map = sphereGroup.map

	-- these two are filled by the sphere group object
	self.prevSphere = nil
	self.nextSphere = nil
	self.offset = 0

	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.color = color
		self.appendSize = 1
		self.boostStreak = false
		self.shootOrigin = nil
		self.shootTime = nil
		self.effects = {}
		self.gaps = gaps or {}
		self.destroyedFragileSpheres = destroyedFragileSpheres
		self.ghostTime = nil
		self.growStopped = false
		self.attachedSphere = nil -- The sphere this sphere is attached to, if its growth has been stopped.
		self.attachedAngle = nil -- The relative angle between this sphere and the attached sphere.
    end

	self:loadConfig()

	self.entity = sphereEntity or SphereEntity(self:getPos(), self.color)

	if shootOrigin then
		self.shootOrigin = shootOrigin
		self.shootTime = shootTime
		self.appendSize = 0
	end

	self.animationPrevOffset = self:getOffset()
	self.animationFrame = math.random() * self.frameCount

	if not self.map.isDummy then
		self.map.level.colorManager:increment(self.color)
	end

	self.danger = false

	self.delQueue = false
end



---Updates this Sphere.
---@param dt number Time delta in seconds.
function Sphere:update(dt)
	-- for spheres that are being added
	if self.appendSize < 1 and not self.growStopped then
		self.appendSize = self.appendSize + dt / self.shootTime
		if self.appendSize >= 1 then
			self.appendSize = 1
			self.shootOrigin = nil
			self.shootTime = nil
			self:finishShot()
		end
		self:updateOffset()
	end

	-- Update the effects.
	for i, effect in ipairs(self.effects) do
		-- If it has to infect...
		if effect.infectionSize > 0 then
			-- Tick the infection timer.
			effect.infectionTime = effect.infectionTime - dt
			-- If the timer elapses, infect neighbors.
			if effect.infectionTime <= 0 then
				effect.infectionTime = effect.infectionTime + effect.config.infectionTime
				effect.infectionSize = effect.infectionSize - 1
				if self.prevSphere and self.prevSphere.color ~= 0 then -- TODO: make a sphere tag in order to determine which spheres to infect.
					self.prevSphere:applyEffect(effect.config, effect.infectionSize, effect.infectionTime, effect.effectGroupID)
				end
				if self.nextSphere and self.nextSphere.color ~= 0 then -- TODO: as above.
					-- We need to compensate the time for the next sphere, because it will be updated in this tick!
					self.nextSphere:applyEffect(effect.config, effect.infectionSize, effect.infectionTime + dt, effect.effectGroupID)
				end
			end
		else
			-- Tick the timer.
			effect.time = effect.time - dt
			-- If the timer elapses, destroy this sphere.
			if effect.time <= 0 then
				self:matchEffect(effect.config)
			end
		end
	end

	-- Update the ghost time.
	if self.ghostTime then
		self.ghostTime = self.ghostTime - dt
		if self:isGhostForDeletion() then
			self:deleteGhost()
		end
	end

	-- if the sphere was flagged as it was a part of a combo but got obstructed, then it's unflagged. We also erase any shot sphere information.
	if self.boostStreak or self.gaps or self.destroyedFragileSpheres then
		if not self.sphereGroup:isMagnetizing() and not (self.sphereGroup.nextGroup and self.sphereGroup.nextGroup:isMagnetizing()) and not self:canKeepCascade() then
			self.boostStreak = false
			self.gaps = {}
			self.destroyedFragileSpheres = false
		end
	end

	-- count/uncount the sphere from the danger sphere counts
	if not self.map.isDummy and not self.delQueue then
		local danger = self.sphereGroup.sphereChain:getDanger()
		if self.danger ~= danger then
			self.danger = danger
			if danger then
				self.map.level.colorManager:increment(self.color, true)
			else
				self.map.level.colorManager:decrement(self.color, true)
			end
		end
	end
end



---Recalculates the offset this Sphere has from the offset of the Sphere Group it belongs to.
function Sphere:updateOffset()
	-- The offset calculation is performed using the scale on the current offset (before recalculation),
	-- which can be far away from the new point (a new group starts with all spheres having offset = 0).
	-- Since making a solver for all possible scenarios wouldn't be feasible,
	-- we'll do with just reiterating a few times, to bring the inaccuracy down enough.

	-- TODO: Pointless on certain paths. Might optimize this down at some point.
	for i = 1, 4 do
		self.offset = self.prevSphere and self.prevSphere.offset + self:getPrevSeparation() or 0
	end
end



---Executed when this Sphere finishes its growth, either naturally or by it being stopped.
---Checks the matches, combos, etc.
function Sphere:finishShot()
	local index = self.sphereGroup:getSphereID(self)
	if self.sphereGroup:shouldBoostStreak(index) then
		self.boostStreak = true
	else
		self.map.level.streak = 0
	end
	if self.sphereGroup:shouldMatch(index) then
		self.sphereGroup:matchAndDelete(index)
	end
end



---Changes the color of this Sphere.
---@param color integer The new color for this Sphere to be obtained.
---@param particle string? A one-time particle packet pointer to be spawned if the color change is successful.
function Sphere:changeColor(color, particle)
	self.map.level.colorManager:decrement(self.color)
	self.map.level.colorManager:increment(color)
	if self.danger then
		self.map.level.colorManager:decrement(self.color, true)
		self.map.level.colorManager:increment(color, true)
	end
	self.color = color
	self.entity:setColor(color)
	self:loadConfig()
	if particle then
		_Game:spawnParticle(particle, self:getPos())
	end
end



---Removes this sphere.
---Warning! The removal of the sphere itself is done in SphereGroup.lua!
---Please do not call this function if you want to remove this sphere from the board.
---@param crushed boolean? Used when this sphere is a vise and is destroyed by joining two sphere chains together. Sets a variable.
function Sphere:delete(crushed)
	if self.delQueue then
		return
	end

	self.delQueue = true

	-- Update links !!!
	if self.prevSphere then self.prevSphere.nextSphere = self.nextSphere end
	if self.nextSphere then self.nextSphere.prevSphere = self.prevSphere end

	self:deleteVisually(nil, crushed)
end



---Removes this sphere, but only visually. The sphere will remain physically on the board until `:delete()` has been called or after a given time.
---@param crushed boolean? Used when this sphere is a vise and is destroyed by joining two sphere chains together. Sets a variable.
---@param ghostTime number? The time this Sphere will exist in its ghost form before it will get deleted completely.
function Sphere:deleteVisually(ghostTime, crushed)
	if not self.entity then
		return
	end

	if not self.map.isDummy then
		-- Increment sphere collapse count.
		if self.color ~= 0 then
			self.map.level:destroySphere()
		end
		if not self.map.level.lost then
			self.path:setOffsetVars("sphere", self:getOffset())
			self:dumpVariables()
			_Vars:set("sphere.crushed", crushed or false)
			-- Spawn collectibles, if any.
			if self.config.destroyCollectible then
				self.map.level:spawnCollectiblesFromEntry(self:getPos(), self.config.destroyCollectible)
			end
			-- Play a sound.
			if self.config.destroySound then
				_Game:playSound(self.config.destroySound, self:getPos())
			end
			-- Execute a Game Event.
			if self.config.destroyEvent then
				_Game:executeGameEvent(self.config.destroyEvent)
			end
			_Vars:unset("sphere")
		end
		-- Update color count.
		self.map.level.colorManager:decrement(self.color)
		if self.danger then
			self.map.level.colorManager:decrement(self.color, true)
		end
	end

	-- Remove the entity.
	self.entity:destroy(not ((self.map.level.lost or self.map.isDummy) and self:getOffset() >= self.path.length))
	self.entity = nil

	-- Remove all effects.
	for i, effect in ipairs(self.effects) do
		-- Remove particles.
		if effect.particle then
			effect.particle:destroy()
		end
		-- Emit destroy particles.
		if effect.config.destroyParticle then
			_Game:spawnParticle(effect.config.destroyParticle, self:getPos())
		end
		-- Decrement the sphere effect group counter.
		self.path:decrementSphereEffectGroup(effect.effectGroupID)
	end
	self.effects = {}

	-- Mark as ghosted if the SphereGroup actually does not remove this Sphere.
	self.ghostTime = ghostTime
end



---Unloads this sphere.
function Sphere:destroy()
	if self.entity then
		self.entity:destroy(false)
	end
	for i, effect in ipairs(self.effects) do
		-- Remove particles.
		if effect.particle then
			effect.particle:destroy()
		end
	end
end



---Applies an effect to this sphere.
---@param effectConfig SphereEffectConfig The config of the Sphere Effect to be applied to this Sphere.
---@param infectionSize integer? How many spheres can this effect traverse to in one direction. If not set, data from the sphere effect config is prepended.
---@param infectionTime number? The time that needs to elapse before this effect traverses to the neighboring spheres. If not set, data from the sphere effect config is prepended.
---@param effectGroupID integer? The sphere effect group ID this sphere belongs to. Used to determine the cause sphere.
function Sphere:applyEffect(effectConfig, infectionSize, infectionTime, effectGroupID)
	-- Don't allow a single sphere to have the same effect applied twice.
	if self:hasEffect(effectConfig) then
		return
	end

	-- Create an effect group if it doesn't exist.
	if not effectGroupID then
		effectGroupID = self.path:createSphereEffectGroup(self)
	end
	self.path:incrementSphereEffectGroup(effectGroupID)
	-- Prepare effect data and insert it.
	local effect = {
		name = effectConfig._path,
		config = effectConfig,
		time = effectConfig.time,
		infectionSize = infectionSize or effectConfig.infectionSize,
		infectionTime = infectionTime or effectConfig.infectionTime,
		effectGroupID = effectGroupID
	}
	if effectConfig.particle then
		effect.particle = _Game:spawnParticle(effectConfig.particle, self:getPos())
	end
	table.insert(self.effects, effect)

	-- Sound effect.
	if effectConfig.applySound then
		_Game:playSound(effectConfig.applySound, self:getPos())
	end
end



---Returns the previous Sphere in this Sphere Chain, or `nil` if this is the first (backmost) sphere in the chain.
---@return Sphere?
function Sphere:getPrevSphereInChain()
	if self.prevSphere then
		return self.prevSphere
	end
	-- The previous sphere might be in the previous group.
	if self.sphereGroup.prevGroup then
		return self.sphereGroup.prevGroup:getLastSphere()
	end
end



---Returns the next Sphere in this Sphere Chain, or `nil` if this is the last (frontmost) sphere in the chain.
---@return Sphere?
function Sphere:getNextSphereInChain()
	if self.nextSphere then
		return self.nextSphere
	end
	-- The next sphere might be in the next group.
	if self.sphereGroup.nextGroup then
		return self.sphereGroup.nextGroup:getFirstSphere()
	end
end



---Returns `true` if this sphere is a stone sphere.
---@return boolean
function Sphere:isStone()
	return self.config.type == "stone"
end



---Returns `true` if this sphere is either mature or its growth has been stopped (it will never be mature).
---@return boolean
function Sphere:isReadyForMatching()
	return self.appendSize == 1 or self.growStopped
end



---Destroys this and any number of connected spheres with a given effect.
---@param effectConfig SphereEffectConfig The sphere effect config.
function Sphere:matchEffect(effectConfig)
	self.sphereGroup:matchAndDeleteEffect(self.sphereGroup:getSphereID(self), effectConfig)
end



---Destroys this and any number of connected spheres with the first found fragile effect.
function Sphere:matchEffectFragile()
	local effectConfig = nil
	for i, effect in ipairs(self.effects) do
		if effect.config.fragile then
			effectConfig = effect.config
			break
		end
	end
	self.sphereGroup:matchAndDeleteEffect(self.sphereGroup:getSphereID(self), effectConfig)
end



---Returns the effect group ID of a given effect of this sphere, or `nil` if not found.
---@param effectConfig SphereEffectConfig The sphere effect config.
---@return integer?
function Sphere:getEffectGroupID(effectConfig)
	for i, effect in ipairs(self.effects) do
		if effect.name == effectConfig._path then
			return effect.effectGroupID
		end
	end
end



---Returns `true` if this sphere is inflicted with a given effect.
---@param effectConfig SphereEffectConfig The sphere effect config.
---@param effectGroupID integer? If given, this function will return `true` only if this sphere is in that particular effect group ID.
---@return boolean
function Sphere:hasEffect(effectConfig, effectGroupID)
	for i, effect in ipairs(self.effects) do
		if effect.name == effectConfig._path and (not effectGroupID or effect.effectGroupID == effectGroupID) then
			return true
		end
	end

	return false
end



---Returns `true` if this sphere has an effect which prevents the level from being lost.
---@return boolean
function Sphere:hasLossProtection()
	for i, effect in ipairs(self.effects) do
		if effect.config.levelLossProtection then
			return true
		end
	end

	return false
end



---Returns `true` if this sphere has an effect which makes the group immobile.
---@return boolean
function Sphere:isImmobile()
	for i, effect in ipairs(self.effects) do
		if effect.config.immobile then
			return true
		end
	end

	return false
end



---Returns `true` if this sphere has an effect which makes it fragile.
---@return boolean
function Sphere:isFragile()
	for i, effect in ipairs(self.effects) do
		if effect.config.fragile then
			return true
		end
	end

	return false
end



---Returns `true` if this Sphere has an effect which makes its sphere train/path able to keep the current cascade combo.
---@return boolean
function Sphere:canKeepCascade()
	for i, effect in ipairs(self.effects) do
		if effect.config.canKeepCascade then
			return true
		end
	end

	return false
end



---Destroys this and any number of connected spheres if their ghost time has expired.
function Sphere:deleteGhost()
	self.sphereGroup:deleteGhost(self.sphereGroup:getSphereID(self))
end



---Returns `true` if this sphere is a ghost, i.e. has no visual representation and no hitbox, but exists.
---@return boolean
function Sphere:isGhost()
	return self.ghostTime and self.ghostTime >= 0 or false
end



---Returns `true` if this sphere is a ghost and can be now removed entirely from the board.
---@return boolean
function Sphere:isGhostForDeletion()
	return self.ghostTime and self.ghostTime <= 0 or false
end



---Makes the Sphere's appending size locked at the current value so it never grows further.
function Sphere:stopGrowing()
	if self.growStopped or self.appendSize == 1 then
		return
	end
	self.growStopped = true
	-- Attach to the nearest sphere.
	if self.prevSphere and not self.nextSphere then
		self.attachedSphere = self.prevSphere
	elseif not self.prevSphere and self.nextSphere then
		self.attachedSphere = self.nextSphere
	else
		local prevDistance = (self.prevSphere:getPos() - self:getPos()):len()
		local nextDistance = (self.nextSphere:getPos() - self:getPos()):len()
		self.attachedSphere = prevDistance < nextDistance and self.prevSphere or self.nextSphere
	end
	self.attachedAngle = (self.attachedSphere:getPos() - self:getPos()):angle() - self.attachedSphere:getAngle()
	-- Calculate the matches and so on.
	self:finishShot()
end



---Returns the current global offset of this sphere on its path.
---@return number
function Sphere:getOffset()
	return self.sphereGroup.offset + self.offset
end



---Returns the current global position of this Sphere.
---@return Vector2
function Sphere:getPos()
	if self.appendSize < 1 then
		return self.path:getPos(self:getOffset() + self.size / 2 * (1 - self.appendSize)) * self.appendSize + self.shootOrigin * (1 - self.appendSize)
	end
	return self.path:getPos(self:getOffset())
end



---Returns the current rotation of this Sphere.
---@return number
function Sphere:getAngle()
	return self.path:getAngle(self:getOffset())
end



---Returns the current scale of this Sphere, taking only path into the account.
---@return number
function Sphere:getScale()
	return self.path:getScale(self:getOffset())
end



---Returns the diameter of this Sphere, in pixels. This includes the normal Sphere size, its appending and path scaling.
---@return number
function Sphere:getSize()
	return self.size * self.appendSize * self:getScale()
end

---Same as `sphere:getSize()`, but will not include the appending size.
---@return number
function Sphere:getDesiredSize()
	return self.size * self:getScale()
end



---Returns the separation this Sphere should have compared to its previous sphere. If there's no previous sphere, this returns 0.
function Sphere:getPrevSeparation()
	if not self.prevSphere then
		return 0
	end
	if not self.prevSphere.prevSphere then
		-- This is a correction for spheres being appended at the back. They are instantly correctly aligned, so no need to counter it here.
		return (self:getSize() + self.prevSphere.size) / 2
	end
	return (self:getSize() + self.prevSphere:getSize()) / 2
end



---Returns `true` if this Sphere is near a path node flagged as hidden. This will make it impossible to shoot at.
---@return boolean
function Sphere:getHidden()
	return self.path:getHidden(self:getOffset())
end



---Returns the color tint the sphere should have.
---@return Color
function Sphere:getColor()
	local brightness = self.path:getBrightness(self:getOffset())
	return Color(brightness)
end



---Returns `true` if this sphere has not escaped the spawn point.
---@return boolean
function Sphere:isOffscreen()
	return self:getOffset() < 32
end



---Sets the Expression Variables in the `sphere` context:
--- - `sphere.object` - The Sphere object. The only thing that can be done with this field is comparison, to see if two spheres are the same sphere.
--- - `sphere.color` - The color ID of this Sphere.
--- - `sphere.isOffscreen` - Whether this Sphere is close enough to the spawning point that it should be considered offscreen.
---If `pos` is given, additional variables will be available:
--- - `sphere.distance` - The linear distance between the given position and the current sphere position.
--- - `sphere.distanceX` - Ditto, but only considering the X axis.
---The context can be changed, but defaults to `sphere`.
---
---@param context string? The context to be used for the variables, `"sphere"` by default.
---@param pos Vector2? The position relative to which additional variables can be inserted.
function Sphere:dumpVariables(context, pos)
	context = context or "sphere"
	_Vars:set(context .. ".object", self)
	_Vars:set(context .. ".color", self.color)
	_Vars:set(context .. ".isOffscreen", self:isOffscreen())
	if pos then
		_Vars:set(context .. ".distance", (self:getPos() - pos):len())
		_Vars:set(context .. ".distanceX", math.abs(self:getPos().x - pos.x))
	end
end



---Draws this Sphere.
---@param hidden boolean Filter the drawing routine only to hidden or not hidden spheres.
---@param shadow boolean If `true`, the shadow sprite will be rendered, else, the main entity.
function Sphere:draw(hidden, shadow)
	if not self.entity or self:getHidden() ~= hidden then
		return
	end

	local pos = self:getPos()
	if self.attachedSphere and self.attachedAngle then
		pos = self.attachedSphere:getPos() - Vec2(self:getSize() + self.attachedSphere:getSize(), 0):rotate(self.attachedAngle + self.attachedSphere:getAngle())
	end

	local angle = self.config.spriteAnimationSpeed and 0 or self:getAngle()

	local scale = self:getScale() * self.size / 32

	local frame = 1
	if self.config.spriteAnimationSpeed then
		frame = math.floor(self.config.spriteAnimationSpeed * _TotalTime)
	elseif self.appendSize == 1 then
		frame = math.ceil(self.frameCount - self.animationFrame)
	end

	local colorM = self:getColor()

	-- Rolling animation
	local dist = self:getOffset() - self.animationPrevOffset
	self.animationPrevOffset = self:getOffset()
	self.animationFrame = (self.animationFrame + dist * (self.config.spriteRollingSpeed or (2 / math.pi))) % self.frameCount

	-- Update the entity position, rotation, scale, frame, etc.
	self.entity:setPos(pos)
	self.entity:setAngle(angle)
	self.entity:setScale(scale)
	self.entity:setFrame(frame)
	self.entity:setColorM(colorM)

	-- Move the particles to the appropriate layer.
	if self:getHidden() then
		self.entity:setLayer(self.map.isDummy and "_DUMMY_SPHERES_H" or "_SPHERES_H")
	else
		self.entity:setLayer(self.map.isDummy and "_DUMMY_SPHERES" or "_SPHERES")
	end

	self.entity:draw(shadow)

	-- Update particle positions.
	for i, effect in ipairs(self.effects) do
		if effect.particle then
			effect.particle.pos = self:getPos()
		end
	end

	if _Debug.gameDebugVisible and self.appendSize < 1 then
		local p1 = self.path:getPos(self:getOffset() + self.size / 2 * (1 - self.appendSize))
		local p2 = self.shootOrigin
		love.graphics.setColor(1, 0.5, 0)
		love.graphics.setLineWidth(3)
		love.graphics.line(p1.x, p1.y, p2.x, p2.y)
		love.graphics.setColor(1, 1, 1)
		love.graphics.setLineWidth(1)
		love.graphics.circle("line", p1.x, p1.y, 15)
	end

	-- debug: you can peek some sphere-related values here
	--[[
	local effectConfig = _Game.resourceManager:getSphereEffectConfig("sphere_effects/match.json")
	if not shadow and self:hasEffect(effectConfig) then
		local p = self:getPos()
		love.graphics.print(self:getEffectGroupID(effectConfig), p.x, p.y + 20)
	end
	]]

	-- Sphere appending
	--[[
	if not shadow and _Debug.gameDebugVisible and self.appendSize < 1 then
		local p = self:getPos()
		local s = ""
		s = s .. "offset: " .. tostring(self.offset) .. "\n"
		s = s .. "getOffset(): " .. tostring(self:getOffset()) .. "\n"
		s = s .. "appendSize: " .. tostring(self.appendSize) .. "\n"
		s = s .. "\nResult: " .. tostring(self:getOffset() + 32 - self.appendSize * 32)
		love.graphics.print(s, p.x, p.y + 20)
	end
	]]
end



---Reloads the configuration variables of the current sphere color.
function Sphere:loadConfig()
	self.config = _Game.resourceManager:getSphereConfig("spheres/sphere_" .. self.color .. ".json")
	self.sprite = self.config.sprite
	-- TODO/DEPRECATED: Remove default value
	self.frameCount = self.sprite.states[1].frameCount
	self.size = self.config.size or 32
end



---Returns the config of this Sphere.
---@return table
function Sphere:getConfig()
	return self.config
end



---Returns a table of IDs, which at the very moment identify this very sphere. Use if you want to reference this Sphere in the save file.
---@return table
function Sphere:getIDs()
	local s = self
	local g = s.sphereGroup
	local c = g.sphereChain
	local p = c.path
	local m = p.map

	local sphereID = g:getSphereID(s)
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



---Serializes this Sphere's data for reusing it later.
---@return table|integer
function Sphere:serialize()
	local t = {
		color = self.color,
		--animationFrame = self.animationFrame, -- who cares about that, you can uncomment this if you do
		shootOrigin = self.shootOrigin and {x = self.shootOrigin.x, y = self.shootOrigin.y} or nil,
		shootTime = self.shootTime,
		ghostTime = self.ghostTime,
		attachedSphere = self.attachedSphere and self.attachedSphere:getIDs(),
		attachedAngle = self.attachedAngle
	}

	if self.appendSize ~= 1 then
		t.appendSize = self.appendSize
	end
	if self.boostStreak then
		t.boostStreak = self.boostStreak
	end

	if #self.effects > 0 then
		t.effects = {}
	end
	for i, effect in ipairs(self.effects) do
		local tt = {
			name = effect.name,
			time = effect.time,
			infectionSize = effect.infectionSize,
			infectionTime = effect.infectionTime,
			effectGroupID = effect.effectGroupID
		}
		table.insert(t.effects, tt)
	end

	if #self.gaps > 0 then
		t.gaps = self.gaps
	end
	if self.destroyedFragileSpheres then
		t.destroyedFragileSpheres = self.destroyedFragileSpheres
	end
	if self.growStopped then
		t.growStopped = self.growStopped
	end

	-- If the only data to be saved is the sphere's color, serialize to an integer value.
	if not t.shootOrigin and not t.shootTime and not t.ghostTime and not t.appendSize and not t.boostStreak and not t.effects and not t.gaps and not t.destroyedFragileSpheres and not t.growStopped then
		return t.color
	end

	return t
end



---Deserializes the Sphere's data so the saved data can be reused.
---@param t table|integer Previously serialized Sphere's data.
function Sphere:deserialize(t)
	if type(t) == "number" then
		t = {color = t}
	end

	self.color = t.color
	--self.animationFrame = t.animationFrame
	self.appendSize = t.appendSize or 1
	self.boostStreak = t.boostStreak or false
	self.shootOrigin = t.shootOrigin and Vec2(t.shootOrigin.x, t.shootOrigin.y) or nil
	self.shootTime = t.shootTime
	self.ghostTime = t.ghostTime
	-- The `attachedSphere` field is loaded in `Level:deserialize()` because of the loading order (the reference is incomplete during the loading progress).
	self.attachedAngle = t.attachedAngle

	self.effects = {}
	if t.effects then
		for i, effect in ipairs(t.effects) do
			local effectConfig = _Game.resourceManager:getSphereEffectConfig(effect.name)
			local e = {
				name = effect.name,
				config = effectConfig,
				time = effect.time,
				infectionSize = effect.infectionSize,
				infectionTime = effect.infectionTime,
				effectGroupID = effect.effectGroupID,
				particle = effectConfig.particle and _Game:spawnParticle(effectConfig.particle, self:getPos())
			}
			table.insert(self.effects, e)
		end
	end

	self.gaps = t.gaps or {}
	self.destroyedFragileSpheres = t.destroyedFragileSpheres or false
	self.growStopped = t.growStopped or false
end



return Sphere
