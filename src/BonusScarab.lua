local class = require "com/class"
local BonusScarab = class:derive("BonusScarab")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")

function BonusScarab:new(path, deserializationTable)
	self.path = path

	self.config = game.configManager.gameplay.bonusScarab



	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.offset = path.length
		self.distance = 0
		self.trailDistance = 0
		self.coinDistance = 0
	end
	self.minOffset = math.max(path.clearOffset, 64)

	self.sprite = game.resourceManager:getSprite(self.config.sprite)
	self.shadowSprite = game.resourceManager:getSprite("sprites/game/ball_shadow.json")

	self.sound = game:playSound("bonus_scarab_loop", 1, self:getPos())
end

function BonusScarab:update(dt)
	-- Offset and distance
	self.offset = self.offset - self.config.speed * dt
	self.distance = self.path.length - self.offset
	-- Coins
	if self.config.coinDistance then
		while self.coinDistance < self.distance do
			if self.coinDistance > 0 then game.session.level:spawnCollectible(self:getPos(), {type = "coin"}) end
			self.coinDistance = self.coinDistance + self.config.coinDistance
		end
	end
	-- Trail
	if self.config.trailParticle then
		while self.trailDistance < self.distance do
			local offset = self.path.length - self.trailDistance
			if not self.path:getHidden(offset) then -- the particles shouldn't be visible under obstacles
				game:spawnParticle(self.config.trailParticle, self.path:getPos(offset))
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

	game.session.level:grantScore(score)
	game.session.level:spawnFloatingText(numStr(score) .. "\nBONUS", pos, self.config.scoreFont)
	game:spawnParticle(self.config.destroyParticle, pos)
	game:playSound("bonus_scarab", 1, pos)
	self:destroy()
end

function BonusScarab:destroy()
	self.path.bonusScarab = nil
	self.sound:stop()
end



function BonusScarab:draw(hidden, shadow)
	if self.path:getHidden(self.offset) == hidden then
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
