### This class is not used yet. All sphere algorithms are stored in SphereGroup.lua.

local class = require "com/class"
local Sphere = class:derive("Sphere")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")
local SphereEntity = require("src/SphereEntity")

function Sphere:new(sphereGroup, deserializationTable, color, shootOrigin, shootTime, sphereEntity)
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
	end

	self:loadConfig()

	if shootOrigin then
		self.shootOrigin = shootOrigin
		self.shootTime = shootTime
		self.size = 0
		self.frameOffset = 0
	end

	if not self.map.isDummy then
		_Game.session.colorManager:increment(self.color)
	end

	self.danger = false

	self.entity = sphereEntity or SphereEntity(self:getPos(), self.color)

	self.delQueue = false
end

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
				effect.infectionTime = effect.infectionTime + effect.config.infection_time
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

	-- if the sphere was flagged as it was a part of a combo but got obstructed then it's unflagged
	if self.boostCombo then
		if not self.sphereGroup:isMagnetizing() and not (self.sphereGroup.nextGroup and self.sphereGroup.nextGroup:isMagnetizing()) and not self:canKeepCombo() then
			self.boostCombo = false
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
end

function Sphere:updateOffset()
	-- calculate the offset
	self.offset = self.prevSphere and self.prevSphere.offset + 32 * self.size or 0
end

function Sphere:changeColor(color, particle)
	_Game.session.colorManager:decrement(self.color)
	_Game.session.colorManager:increment(color)
	self.color = color
	self.entity:setColor(color)
	self:loadConfig()
	if particle then
		_Game:spawnParticle(particle, self:getPos())
	end
end



-- Removes this sphere.
-- Warning! The removal of the sphere itself is done in SphereGroup.lua!
-- Please do not call this function if you want to remove this sphere from the board.
function Sphere:delete()
	if self.delQueue then
		return
	end

	self.delQueue = true
	if not self.map.isDummy then
		-- Increment sphere collapse count.
		if self.color ~= 0 then
			self.map.level:destroySphere()
		end
		-- Spawn collectibles, if any.
		self.path:dumpOffsetVars(self:getOffset())
		if self.config.destroy_collectible and not self.map.level.lost then
			self.map.level:spawnCollectiblesFromEntry(self:getPos(), self.config.destroy_collectible)
		end
		-- Update color count.
		_Game.session.colorManager:decrement(self.color)
		if self.danger then
			_Game.session.colorManager:decrement(self.color, true)
		end
	end

	-- Update links !!!
	if self.prevSphere then self.prevSphere.nextSphere = self.nextSphere end
	if self.nextSphere then self.nextSphere.prevSphere = self.prevSphere end

	-- Remove the entity.
	self.entity:destroy(not ((self.map.level.lost or self.map.isDummy) and self:getOffset() >= self.path.length))

	-- Remove all effects.
	for i, effect in ipairs(self.effects) do
		-- Remove particles.
		if effect.particle then
			effect.particle:destroy()
		end
		-- Emit destroy particles.
		if effect.config.destroy_particle then
			_Game:spawnParticle(effect.config.destroy_particle, self:getPos())
		end
		-- Decrement the sphere effect group counter.
		self.path:decrementSphereEffectGroup(effect.effectGroupID)
	end
end



-- Unloads this sphere.
function Sphere:destroy()
	self.entity:destroy(false)
	for i, effect in ipairs(self.effects) do
		-- Remove particles.
		if effect.particle then
			effect.particle:destroy()
		end
	end
end



-- Applies an effect to this sphere.
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
		infectionSize = infectionSize or effectConfig.infection_size,
		infectionTime = infectionTime or effectConfig.infection_time,
		effectGroupID = effectGroupID
	}
	if effectConfig.particle then
		effect.particle = _Game:spawnParticle(effectConfig.particle, self:getPos())
	end
	table.insert(self.effects, effect)

	-- Sound effect.
	if effectConfig.apply_sound then
		_Game:playSound(effectConfig.apply_sound, 1, self:getPos())
	end
end



-- Returns true if this sphere is a stone sphere.
function Sphere:isStone()
	return self.config.type == "stone"
end



-- Destroys this and any number of connected spheres with a given effect.
function Sphere:matchEffect(name)
	self.sphereGroup:matchAndDeleteEffect(self.sphereGroup:getSphereID(self), name)
end



-- Destroys this and any number of connected spheres with a fragile effect.
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



-- Returns the effect group ID of a given effect of this sphere.
function Sphere:getEffectGroupID(name)
	for i, effect in ipairs(self.effects) do
		if effect.name == name then
			return effect.effectGroupID
		end
	end
end



-- Returns true if this sphere has already that effect applied.
function Sphere:hasEffect(name, effectGroupID)
	for i, effect in ipairs(self.effects) do
		if effect.name == name and (not effectGroupID or effect.effectGroupID == effectGroupID) then
			return true
		end
	end

	return false
end



-- Returns true if this sphere has an effect which prevents the level from being lost.
function Sphere:hasLossProtection()
	for i, effect in ipairs(self.effects) do
		if effect.config.level_loss_protection then
			return true
		end
	end

	return false
end



-- Returns true if this sphere has an effect which makes it immobile.
function Sphere:isImmobile()
	for i, effect in ipairs(self.effects) do
		if effect.config.immobile then
			return true
		end
	end

	return false
end



-- Returns true if this sphere has an effect which makes it fragile.
function Sphere:isFragile()
	for i, effect in ipairs(self.effects) do
		if effect.config.fragile then
			return true
		end
	end

	return false
end



-- Returns true if this sphere has an effect which makes it able to keep combo.
function Sphere:canKeepCombo()
	for i, effect in ipairs(self.effects) do
		if effect.config.can_keep_combo then
			return true
		end
	end

	return false
end



function Sphere:getFrame()
	return ((self.frameOffset + self.offset + self.sphereGroup.offset) * self.frameCount / 32) % self.frameCount
end

function Sphere:getOffset()
	return self.sphereGroup.offset + self.offset
end

function Sphere:getPos()
	return self.path:getPos(self:getOffset())
end

function Sphere:getAngle()
	return self.path:getAngle(self:getOffset())
end

function Sphere:getHidden()
	return self.path:getHidden(self:getOffset())
end

function Sphere:getColor()
	local brightness = self.path:getBrightness(self:getOffset())
	return Color(brightness)
end

function Sphere:isOffscreen()
	return self:getOffset() < 32
end



function Sphere:draw(color, hidden, shadow)
	if self.color ~= color or self:getHidden() ~= hidden then
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
		frame = Vec2(math.ceil(self.frameCount - self:getFrame()), 1)
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



function Sphere:loadConfig()
	self.config = _Game.configManager.spheres[self.color]
	self.sprite = _Game.resourceManager:getSprite(self.config.sprite)
	-- TODO/DEPRECATED: Remove default value
	self.shadowSprite = _Game.resourceManager:getSprite(self.config.shadowSprite or "sprites/game/ball_shadow.json")
	self.frameCount = self.sprite.states[1].frameCount.x
	self.frameOffset = math.random() * self.frameCount -- move to the "else" part if you're a purist and want this to be saved

	if self.color == 0 then -- vises follow another way
		self.frameOffset = 0
	end
end



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



function Sphere:serialize()
	local t = {
		color = self.color,
		--frameOffset = self.frameOffset, -- who cares about that, you can uncomment this if you do
		shootOrigin = self.shootOrigin and {x = self.shootOrigin.x, y = self.shootOrigin.y} or nil,
		shootTime = self.shootTime
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

	return t
end

function Sphere:deserialize(t)
	self.color = t.color
	--self.frameOffset = t.frameOffset
	self.size = t.size or 1
	self.boostCombo = t.boostCombo or false
	self.shootOrigin = t.shootOrigin and Vec2(t.shootOrigin.x, t.shootOrigin.y) or nil
	self.shootTime = t.shootTime

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
end

return Sphere
