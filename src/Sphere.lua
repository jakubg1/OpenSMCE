### This class is not used yet. All sphere algorithms are stored in SphereGroup.lua.

local class = require "com.class"

---@class Sphere
---@overload fun(sphereGroup, deserializationTable, color, shootOrigin, shootTime, sphereEntity):Sphere
local Sphere = class:derive("Sphere")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")
local SphereEntity = require("src.SphereEntity")



---Constructs a new Sphere.
---@param sphereGroup SphereGroup The sphere group this sphere belongs to.
---@param deserializationTable table? If set, internal data will be loaded from this table.
---@param color integer The type/color ID of this Sphere.
---@param shootOrigin Vector2? If set, the position of Shot Sphere which has been transformed into this Sphere. It also implies that it will be inserted from that position.
---@param shootTime number? The duration of the sphere insertion animation.
---@param sphereEntity SphereEntity? If set, this will be the Sphere Entity used to draw this Sphere. Else, a new one will be created.
---@param gaps table? If set, this Sphere will have a list of numbers (traversed gap distances) stored so it can be used later when calculating gap shots.
function Sphere:new(sphereGroup, deserializationTable, color, shootOrigin, shootTime, sphereEntity, gaps)
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
		self.size = 1
		self.boostCombo = false
		self.shootOrigin = nil
		self.shootTime = nil
		self.effects = {}
		self.gaps = gaps or {}
		self.ghostTime = nil
    end

	self.entity = sphereEntity or SphereEntity(self:getPos(), self.color)

	self:loadConfig()

	if shootOrigin then
		self.shootOrigin = shootOrigin
		self.shootTime = shootTime
		self.size = 0
	end

	self.animationPrevOffset = self:getOffset()
	self.animationFrame = math.random() * self.frameCount

	if not self.map.isDummy then
		_Game.session.colorManager:increment(self.color)
	end

	self.danger = false

	self.entity = sphereEntity or SphereEntity(self:getPos(), self.color)

	self.delQueue = false
end



---Updates this Sphere.
---@param dt number Time delta in seconds.
function Sphere:update(dt)
	-- for spheres that are being added
	if self.size < 1 then
		self.size = self.size + dt / self.shootTime
		if self.size >= 1 then
			self.size = 1
			self.shootOrigin = nil
			self.shootTime = nil
			local index = self.sphereGroup:getSphereID(self)
			if self.sphereGroup:shouldBoostCombo(index) then
				self.boostCombo = true
			else
				self.map.level.combo = 0
			end
			if self.sphereGroup:shouldMatch(index) then
				self.sphereGroup:matchAndDelete(index)
			end
		end
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
					self.prevSphere:applyEffect(effect.name, effect.infectionSize, effect.infectionTime, effect.effectGroupID)
				end
				if self.nextSphere and self.nextSphere.color ~= 0 then -- TODO: as above.
					-- We need to compensate the time for the next sphere, because it will be updated in this tick!
					self.nextSphere:applyEffect(effect.name, effect.infectionSize, effect.infectionTime + dt, effect.effectGroupID)
				end
			end
		else
			-- Tick the timer.
			effect.time = effect.time - dt
			-- If the timer elapses, destroy this sphere.
			if effect.time <= 0 then
				self:matchEffect(effect.name)
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

	-- if the sphere was flagged as it was a part of a combo but got obstructed then it's unflagged
	if self.boostCombo then
		if not self.sphereGroup:isMagnetizing() and not (self.sphereGroup.nextGroup and self.sphereGroup.nextGroup:isMagnetizing()) and not self:canKeepCombo() then
			self.boostCombo = false
			-- we also erase any gap information
			self.gaps = {}
		end
	end

	-- count/uncount the sphere from the danger sphere counts
	if not self.map.isDummy and not self.delQueue then
		local danger = self.sphereGroup.sphereChain:getDanger()
		if self.danger ~= danger then
			self.danger = danger
			if danger then
				_Game.session.colorManager:increment(self.color, true)
			else
				_Game.session.colorManager:decrement(self.color, true)
			end
		end
	end

	-- animation
	local dist = self:getOffset() - self.animationPrevOffset
	self.animationPrevOffset = self:getOffset()
	self.animationFrame = (self.animationFrame + dist * (self.config.spriteRollingSpeed or 1)) % self.frameCount
end



---Recalculates the offset this Sphere has from the offset of the Sphere Group it belongs to.
function Sphere:updateOffset()
	-- calculate the offset
	self.offset = self.prevSphere and self.prevSphere.offset + 32 * self.size or 0
end



---Changes the color of this Sphere.
---@param color integer The new color for this Sphere to be obtained.
---@param particle string? A one-time particle packet pointer to be spawned if the color change is successful.
function Sphere:changeColor(color, particle)
	_Game.session.colorManager:decrement(self.color)
	_Game.session.colorManager:increment(color)
	if self.danger then
		_Game.session.colorManager:decrement(self.color, true)
		_Game.session.colorManager:increment(color, true)
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
			-- Spawn collectibles, if any.
			self.path:dumpOffsetVars(self:getOffset())
			if self.config.destroyCollectible then
				_Vars:set("crushed", crushed or false)
				self.map.level:spawnCollectiblesFromEntry(self:getPos(), self.config.destroyCollectible)
			end
			-- Play a sound.
			if self.config.destroySound and crushed then
				_Game:playSound(self.config.destroySound, 1, self:getPos())
			end
		end
		-- Update color count.
		_Game.session.colorManager:decrement(self.color)
		if self.danger then
			_Game.session.colorManager:decrement(self.color, true)
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
---@param name string The sphere effect ID.
---@param infectionSize integer? How many spheres can this effect traverse to in one direction. If not set, data from the sphere effect config is prepended.
---@param infectionTime number? The time that needs to elapse before this effect traverses to the neighboring spheres. If not set, data from the sphere effect config is prepended.
---@param effectGroupID integer The sphere effect group ID this sphere belongs to. Used to determine the cause sphere.
function Sphere:applyEffect(name, infectionSize, infectionTime, effectGroupID)
	-- Don't allow a single sphere to have the same effect applied twice.
	if self:hasEffect(name) then
		return
	end

	-- Load a configuration for the given effect.
	local effectConfig = _Game.configManager.sphereEffects[name]
	-- Create an effect group if it doesn't exist.
	if not effectGroupID then
		effectGroupID = self.path:createSphereEffectGroup(self)
	end
	self.path:incrementSphereEffectGroup(effectGroupID)
	-- Prepare effect data and insert it.
	local effect = {
		name = name,
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
		_Game:playSound(effectConfig.applySound, 1, self:getPos())
	end
end



---Returns `true` if this sphere is a stone sphere.
---@return boolean
function Sphere:isStone()
	return self.config.type == "stone"
end



---Destroys this and any number of connected spheres with a given effect.
---@param name string The name of the sphere effect.
function Sphere:matchEffect(name)
	self.sphereGroup:matchAndDeleteEffect(self.sphereGroup:getSphereID(self), name)
end



---Destroys this and any number of connected spheres with a fragile effect.
function Sphere:matchEffectFragile()
	local name = nil
	for i, effect in ipairs(self.effects) do
		if effect.config.fragile then
			name = effect.name
			break
		end
	end
	self.sphereGroup:matchAndDeleteEffect(self.sphereGroup:getSphereID(self), name)
end



---Returns the effect group ID of a given effect of this sphere, or `nil` if not found.
---@param name string The ID of the sphere effect.
---@return integer?
function Sphere:getEffectGroupID(name)
	for i, effect in ipairs(self.effects) do
		if effect.name == name then
			return effect.effectGroupID
		end
	end
end



---Returns `true` if this sphere is inflicted with a given effect.
---@param name string The ID of the sphere effect.
---@param effectGroupID integer? If given, this function will return `true` only if this sphere is in that particular effect group ID.
---@return boolean
function Sphere:hasEffect(name, effectGroupID)
	for i, effect in ipairs(self.effects) do
		if effect.name == name and (not effectGroupID or effect.effectGroupID == effectGroupID) then
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



---Returns `true` if this sphere has an effect which makes it able to keep combo.
---@return boolean
function Sphere:canKeepCombo()
	for i, effect in ipairs(self.effects) do
		if effect.config.canKeepCombo then
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
	return self.ghostTime and self.ghostTime >= 0
end



---Returns `true` if this sphere is a ghost and can be now removed entirely from the board.
---@return boolean
function Sphere:isGhostForDeletion()
	return self.ghostTime and self.ghostTime <= 0
end



---Returns the current global offset of this sphere on its path.
---@return number
function Sphere:getOffset()
	return self.sphereGroup.offset + self.offset
end



---Returns the current global position of this Sphere.
---@return Vector2
function Sphere:getPos()
	return self.path:getPos(self:getOffset())
end



---Returns the current rotation of this Sphere.
---@return number
function Sphere:getAngle()
	return self.path:getAngle(self:getOffset())
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



---Draws this Sphere.
---@param color integer Only if this sphere has this given color, the sphere will be drawn.
---@param hidden boolean Filter the drawing routine only to hidden or not hidden spheres.
---@param shadow boolean If `true`, the shadow sprite will be rendered, else, the main entity.
function Sphere:draw(color, hidden, shadow)
	if not self.entity or self.color ~= color or self:getHidden() ~= hidden then
		return
	end

	local pos = self:getPos()
	if self.size < 1 then
		pos = self.path:getPos(self:getOffset() + 16 - self.size * 16) * self.size + self.shootOrigin * (1 - self.size)
	end

	local angle = self.config.spriteAnimationSpeed and 0 or self:getAngle()

	local frame = Vec2(1)
	if self.config.spriteAnimationSpeed then
		frame = Vec2(math.floor(self.config.spriteAnimationSpeed * _TotalTime), 1)
	elseif self.size == 1 then
		frame = Vec2(math.ceil(self.frameCount - self.animationFrame), 1)
	end

	local colorM = self:getColor()

	-- Update the entity position.
	self.entity:setPos(pos)
	self.entity:setAngle(angle)
	self.entity:setFrame(frame)
	self.entity:setColorM(colorM)

	self.entity:draw(shadow)

	-- Update particle positions.
	for i, effect in ipairs(self.effects) do
		if effect.particle then
			effect.particle.pos = self:getPos()
		end
	end

	-- debug: you can peek some sphere-related values here

	--if not shadow and self:hasEffect("match") then
	--	local p = _PosOnScreen(self:getPos())
	--	love.graphics.print(self:getEffectGroupID("match"), p.x, p.y + 20)
	--end
end



---Reloads the configuration variables of the current sphere color.
function Sphere:loadConfig()
	self.config = _Game.configManager.spheres[self.color]
	self.sprite = _Game.resourceManager:getSprite(self.config.sprite)
	-- TODO/DEPRECATED: Remove default value
	self.shadowSprite = _Game.resourceManager:getSprite(self.config.shadowSprite or "sprites/game/ball_shadow.json")
	self.frameCount = self.sprite.states[1].frameCount.x
end



---Returns a table of IDs, which at the very moment identify this very sphere. Used in saving.
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
---@return table
function Sphere:serialize()
	local t = {
		color = self.color,
		--animationFrame = self.animationFrame, -- who cares about that, you can uncomment this if you do
		shootOrigin = self.shootOrigin and {x = self.shootOrigin.x, y = self.shootOrigin.y} or nil,
		shootTime = self.shootTime,
		ghostTime = self.ghostTime
	}

	if self.size ~= 1 then
		t.size = self.size
	end
	if self.boostCombo then
		t.boostCombo = self.boostCombo
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

	return t
end



---Deserializes the Sphere's data so the saved data can be reused.
---@param t table Previously serialized Sphere's data.
function Sphere:deserialize(t)
	self.color = t.color
	--self.animationFrame = t.animationFrame
	self.size = t.size or 1
	self.boostCombo = t.boostCombo or false
	self.shootOrigin = t.shootOrigin and Vec2(t.shootOrigin.x, t.shootOrigin.y) or nil
	self.shootTime = t.shootTime
	self.ghostTime = t.ghostTime

	self.effects = {}
	if t.effects then
		for i, effect in ipairs(t.effects) do
			local effectConfig = _Game.configManager.sphereEffects[effect.name]
			local e = {
				name = effect.name,
				config = effectConfig,
				time = effect.time,
				infectionSize = effect.infectionSize,
				infectionTime = effect.infectionTime,
				effectGroupID = effect.effectGroupID,
				particle = _Game:spawnParticle(effectConfig.particle, self:getPos())
			}
			table.insert(self.effects, e)
		end
	end

	self.gaps = t.gaps or {}
end



return Sphere
