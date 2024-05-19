local class = require "com.class"

---Represents a single Bonus Scarab which comes out from the end of the path and goes towards the Path's clear offset at the end of a Level.
---@class BonusScarab
---@overload fun(path, deserializationTable):BonusScarab
local BonusScarab = class:derive("BonusScarab")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")



---Constructs a new Bonus Scarab.
---@param path Path A path to spawn the Bonus Scarab on.
---@param deserializationTable table? If specified, data from this table will be used to load the entity state.
function BonusScarab:new(path, deserializationTable)
	self.path = path

	self.config = _Game.configManager.gameplay.bonusScarab



	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.offset = path.length
		self.distance = 0
		self.trailDistance = 0
		self.coinDistance = 0
	end
	self.minOffset = math.max(path.clearOffset, 64)

	self.sprite = _Game.resourceManager:getSprite(self.config.sprite)
	self.shadowSprite = _Game.resourceManager:getSprite(self.config.shadowSprite)
	self.scoreEvent = _Game.resourceManager:getScoreEventConfig(self.config.scoreEvent)

	self.sound = _Game:playSound(self.config.loopSound, self:getPos())

	self.delQueue = false
end



---Updates the Bonus Scarab.
---@param dt number Delta time in seconds.
function BonusScarab:update(dt)
	-- Offset and distance
	self.offset = self.offset - self.config.speed * dt
	self.distance = self.path.length - self.offset
	-- Coins
	if self.config.coinDistance then
		while self.coinDistance < self.distance do
			if self.coinDistance > 0 then
				_Game.session.level:spawnCollectiblesFromEntry(self:getPos(), self.config.coinGenerator)
			end
			self.coinDistance = self.coinDistance + self.config.coinDistance
		end
	end
	-- Trail
	if self.config.trailParticle then
		while self.trailDistance < self.distance do
			local offset = self.path.length - self.trailDistance
			if not self.path:getHidden(offset) then -- the particles shouldn't be visible under obstacles
				_Game:spawnParticle(self.config.trailParticle, self.path:getPos(offset))
			end
			self.trailDistance = self.trailDistance + self.config.trailParticleDistance
		end
	end
	-- Sound
	self.sound:setPos(self:getPos())
	-- Destroy when exceeded minimum offset
	if self.offset <= self.minOffset then self:explode() end
end



---Explodes the Bonus Scarab, by giving points, spawning particles and playing a sound.
function BonusScarab:explode()
	self.path:setOffsetVars("entity", self.offset)
	_Vars:setC("entity", "traveledPixels", self.path.length - self.minOffset)
	local pos = self:getPos()

	_Game.session.level:executeScoreEvent(self.scoreEvent, pos)
	_Game.session.level:spawnCollectiblesFromEntry(self:getPos(), self.config.destroyGenerator)
	_Game:spawnParticle(self.config.destroyParticle, pos)
	_Game:playSound(self.config.destroySound, pos)

	_Vars:unset("entity")

	self:destroy()
end



---Removes the Bonus Scarab from its path.
function BonusScarab:destroy()
	if self.delQueue then
		return
	end
	self.delQueue = true
	self.sound:stop()
end



---Draws the Bonus Scarab.
---@param hidden boolean Whether to draw this entity in the hidden pass.
---@param shadow boolean If `true`, the shadow will be drawn. Else, the actual sprite.
function BonusScarab:draw(hidden, shadow)
	if self:getHidden() == hidden then
		if shadow then
			self.shadowSprite:draw(self:getPos() + Vec2(4), Vec2(0.5))
		else
			self.sprite:draw(self:getPos(), Vec2(0.5), nil, nil, self:getAngle() + math.pi, Color(self:getBrightness()))
		end
	end
end



---Returns the current onscreen position of this Bonus Scarab.
---@return Vector2
function BonusScarab:getPos()
	return self.path:getPos(self.offset)
end

---Returns the current angle of this Bonus Scarab.
---@return number
function BonusScarab:getAngle()
	return self.path:getAngle(self.offset)
end

---Returns the brightness of this Bonus Scarab.
---@return number
function BonusScarab:getBrightness()
	return self.path:getBrightness(self.offset)
end

---Returns whether this Bonus Scarab is hidden.
---@return boolean
function BonusScarab:getHidden()
	return self.path:getHidden(self.offset)
end



---Serializes the Bonus Scarab's internal data to be ready for saving.
---@return table
function BonusScarab:serialize()
	local t = {
		offset = self.offset,
		distance = self.distance,
		trailDistance = self.trailDistance,
		coinDistance = self.coinDistance
	}
	return t
end



---Deserializes the Bonus Scarab's internal data.
---@param t table The data to be loaded.
function BonusScarab:deserialize(t)
	self.offset = t.offset
	self.distance = t.distance
	self.trailDistance = t.trailDistance
	self.coinDistance = t.coinDistance
end



return BonusScarab
