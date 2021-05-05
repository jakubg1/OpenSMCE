local class = require "com/class"
local BonusScarab = class:derive("BonusScarab")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")

function BonusScarab:new(path, deserializationTable)
	self.path = path

	self.config = game.configManager.config.gameplay.bonusScarab



	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.offset = path.length
		self.distance = 0
		self.trailDistance = 0
		self.coinDistance = 0
	end
	self.minOffset = math.max(path.clearOffset, 64)

	self.image = game.resourceManager:getImage(self.config.image)
	self.shadowImage = game.resourceManager:getImage("img/game/ball_shadow.png")

	game:playSound("bonus_scarab_loop")
end

function BonusScarab:update(dt)
	-- Offset and distance
	self.offset = self.offset - self.config.speed * dt
	self.distance = self.path.length - self.offset
	-- Coins
	if self.config.coinDistance then
		while self.coinDistance < self.distance do
			if self.coinDistance > 0 then game.session.level:spawnCollectible(self.path:getPos(self.offset), {type = "coin"}) end
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
	-- Destroy when exceeded minimum offset
	if self.offset <= self.minOffset then self:destroy() end
end

function BonusScarab:destroy()
	self.path.bonusScarab = nil
	local score = math.max(math.floor((self.path.length - self.minOffset) / self.config.stepLength), 1) * self.config.pointsPerStep
	game.session.level:grantScore(score)
	game.session.level:spawnFloatingText(numStr(score) .. "\nBONUS", self.path:getPos(self.offset), self.config.scoreFont)
	game:spawnParticle(self.config.destroyParticle, self.path:getPos(self.offset))
	game:stopSound("bonus_scarab_loop")
	game:playSound("bonus_scarab")
end



function BonusScarab:draw(hidden, shadow)
	if self.path:getHidden(self.offset) == hidden then
		if shadow then
			self.shadowImage:draw(self.path:getPos(self.offset) + Vec2(4), Vec2(0.5))
		else
			self.image:draw(self.path:getPos(self.offset), Vec2(0.5), nil, self.path:getAngle(self.offset) + math.pi, Color(self.path:getBrightness(self.offset)))
		end
	end
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
