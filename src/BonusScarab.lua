local class = require "com/class"

---@class BonusScarab
---@overload fun(path, deserializationTable):BonusScarab
local BonusScarab = class:derive("BonusScarab")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")



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
	self.shadowSprite = _Game.resourceManager:getSprite("sprites/game/ball_shadow.json")

	self.sound = _Game:playSound("sound_events/bonus_scarab_loop.json", 1, self:getPos())
end

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

function BonusScarab:explode()
	local pos = self:getPos()
	local score = math.max(math.floor((self.path.length - self.minOffset) / self.config.stepLength), 1) * self.config.pointsPerStep

	self.path:dumpOffsetVars(self.offset)
	_Game.session.level:grantScore(score)
	_Game.session.level:spawnFloatingText(_NumStr(score) .. "\nBONUS", pos, self.config.scoreFont)
	_Game.session.level:spawnCollectiblesFromEntry(self:getPos(), self.config.destroyGenerator)
	_Game:spawnParticle(self.config.destroyParticle, pos)
	_Game:playSound("sound_events/bonus_scarab.json", 1, pos)
	self:destroy()
end

function BonusScarab:destroy()
	self.path.bonusScarab = nil
	self.sound:stop()
end



function BonusScarab:draw(hidden, shadow)
	if self:getHidden() == hidden then
		if shadow then
			self.shadowSprite:draw(self:getPos() + Vec2(4), Vec2(0.5))
		else
			self.sprite:draw(self:getPos(), Vec2(0.5), nil, nil, self:getAngle() + math.pi, Color(self:getBrightness()))
		end
	end
end



function BonusScarab:getPos()
	return self.path:getPos(self.offset)
end

function BonusScarab:getAngle()
	return self.path:getAngle(self.offset)
end

function BonusScarab:getBrightness()
	return self.path:getBrightness(self.offset)
end

function BonusScarab:getHidden()
	return self.path:getHidden(self.offset)
end



function BonusScarab:serialize()
	local t = {
		offset = self.offset,
		distance = self.distance,
		trailDistance = self.trailDistance,
		coinDistance = self.coinDistance
	}
	return t
end

function BonusScarab:deserialize(t)
	self.offset = t.offset
	self.distance = t.distance
	self.trailDistance = t.trailDistance
	self.coinDistance = t.coinDistance
end

return BonusScarab
