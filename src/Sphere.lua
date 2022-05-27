### This class is not used yet. All sphere algorithms are stored in SphereGroup.lua.

local class = require "com/class"
local Sphere = class:derive("Sphere")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")
local SphereEntity = require("src/SphereEntity")

function Sphere:new(sphereGroup, deserializationTable, color, shootOrigin, shootTime)
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

	if not self.map.isDummy and self.color > 0 then
		_Game.session.colorManager:increment(self.color)
	end

	self.danger = false

	self.entity = SphereEntity(self:getPos(), self.color)

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
			-- DEBUG: apply effect.
			--self:applyEffect("poison")
			if self.sphereGroup:shouldMatch(index) then
				self.sphereGroup:matchAndDelete(index)
			end
		end
	end

	-- Update the effects.
	for i, effect in ipairs(self.effects) do
		-- Load a configuration for the given effect.
		local effectConfig = _Game.configManager.sphereEffects[effect.name]
		-- Update particle position.
		effect.particle.pos = self:getPos()
		-- If it has to infect...
		if effect.infectionSize > 0 then
			-- Tick the infection timer.
			effect.infectionTime = effect.infectionTime - dt
			-- If the timer elapses, infect neighbors.
			if effect.infectionTime <= 0 then
				effect.infectionTime = effect.infectionTime + effectConfig.infection_time
				effect.infectionSize = effect.infectionSize - 1
				if self.prevSphere and self.prevSphere.color ~= 0 then -- TODO: make a sphere tag in order to determine which spheres to infect.
					self.prevSphere:applyEffect(effect.name, effect.infectionSize, effect.infectionTime)
				end
				if self.nextSphere and self.nextSphere.color ~= 0 then -- TODO: as above.
					-- We need to compensate the time for the next sphere, because it will be updated in this tick!
					self.nextSphere:applyEffect(effect.name, effect.infectionSize, effect.infectionTime + dt)
				end
			end
		else
			-- Tick the timer.
			effect.time = effect.time - dt
			-- If the timer elapses, destroy this sphere.
			if effect.time <= 0 then
				self.sphereGroup:destroySphere(self.sphereGroup:getSphereID(self))
				self.map.level:grantScore(100)
			end
		end
	end

	-- if the sphere was flagged as it was a part of a combo but got obstructed then it's unflagged
	if self.boostCombo then
		if not self.sphereGroup:isMagnetizing() and not (self.sphereGroup.nextGroup and self.sphereGroup.nextGroup:isMagnetizing()) then self.boostCombo = false end
	end

	-- count/uncount the sphere from the danger sphere counts
	if not self.map.isDummy and self.color > 0 and not self.delQueue then
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
	-- Increment sphere collapse count.
	if not self.map.isDummy and self.color ~= 0 then
		self.map.level:destroySphere()
	end
	-- Update links !!!
	if self.prevSphere then self.prevSphere.nextSphere = self.nextSphere end
	if self.nextSphere then self.nextSphere.prevSphere = self.prevSphere end
	-- Update color count.
	if not self.map.isDummy and self.color > 0 then
		_Game.session.colorManager:decrement(self.color)
		if self.danger then
			_Game.session.colorManager:decrement(self.color, true)
		end
	end
	-- Remove the entity.
	self.entity:destroy()
	-- Remove all effect particles.
	for i, effect in ipairs(self.effects) do
		effect.particle:destroy()
	end
end



-- Applies an effect to this sphere.
function Sphere:applyEffect(name, infectionSize, infectionTime)
	-- Don't allow a single sphere to have the same effect applied twice.
	if self:hasEffect(name) then
		return
	end

	-- Load a configuration for the given effect.
	local effectConfig = _Game.configManager.sphereEffects[name]
	-- Prepare effect data and insert it.
	local effect = {
		name = name,
		time = effectConfig.time,
		infectionSize = infectionSize or effectConfig.infection_size,
		infectionTime = infectionTime or effectConfig.infection_time,
		particle = _Game:spawnParticle(effectConfig.particle, self:getPos())
	}
	table.insert(self.effects, effect)
	-- Sound effect.
	_Game:playSound(effectConfig.apply_sound, 1, self:getPos())
end



-- Returns true if this sphere has already that effect applied.
function Sphere:hasEffect(name)
	for i, effect in ipairs(self.effects) do
		if effect.name == name then
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



function Sphere:serialize()
	local t = {
		color = self.color,
		--frameOffset = self.frameOffset, -- who cares about that, you can uncomment this if you do
		shootOrigin = self.shootOrigin and {x = self.shootOrigin.x, y = self.shootOrigin.y} or nil,
		shootTime = self.shootTime,
		effects = {}
	}

	if self.size ~= 1 then
		t.size = self.size
	end
	if self.boostCombo then
		t.boostCombo = self.boostCombo
	end

	for i, effect in ipairs(self.effects) do
		local tt = {
			name = effect.name,
			time = effect.time,
			infectionSize = effect.infectionSize,
			infectionTime = effect.infectionTime
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
	for i, effect in ipairs(t.effects) do
		local effectConfig = _Game.configManager.sphereEffects[effect.name]
		local e = {
			name = effect.name,
			time = effect.time,
			infectionSize = effect.infectionSize,
			infectionTime = effect.infectionTime
			--particle = _Game:spawnParticle(effectConfig.particle, self:getPos())
		}
		table.insert(self.effects, e)
	end
end

return Sphere
