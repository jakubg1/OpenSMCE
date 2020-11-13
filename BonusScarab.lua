local class = require "class"
local BonusScarab = class:derive("BonusScarab")

local Vec2 = require("Essentials/Vector2")
local Color = require("Essentials/Color")
local Sprite = require("Sprite")

function BonusScarab:new(path, deserializationTable)
	self.path = path
	
	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.offset = path.length
		self.distance = 0
		self.trailDistance = 0
		self.coinDistance = 0
	end
	self.minOffset = math.max(path.clearOffset, 64)
	
	self.sprite = Sprite("sprites/sphere_vise.json")
	self.shadowImage = game.resourceBank:getImage("img/game/ball_shadow.png")
	
	game:playSound("bonus_scarab_loop")
end

function BonusScarab:update(dt)
	self.offset = self.offset - 1000 * dt
	self.distance = self.path.length - self.offset
	-- Luxor 2
	-- while self.coinDistance < self.distance do
		-- if self.coinDistance > 0 then game.session.level:spawnCollectible(self.path:getPos(self.offset), {type = "coin"}) end
		-- self.coinDistance = self.coinDistance + 500
	-- end
	while self.trailDistance < self.distance do
		local offset = self.path.length - self.trailDistance
		--if not self.path:getHidden(offset) then -- the particles shouldn't be visible under obstacles
			game:spawnParticle("particles/bonus_scarab_trail.json", self.path:getPos(offset))
		--end
		self.trailDistance = self.trailDistance + 24
	end
	if self.offset <= self.minOffset then self:destroy() end
end

function BonusScarab:destroy()
	self.path.bonusScarab = nil
	-- 50 points every 24 pixels
	local score = math.max(math.floor((self.path.length - self.minOffset) / 24), 1) * 50
	game.session.level:grantScore(score)
	game.session.level:spawnFloatingText(numStr(score) .. "\nBONUS", self.path:getPos(self.offset), "fonts/score0.json")
	game:spawnParticle("particles/collapse_vise.json", self.path:getPos(self.offset))
	game:stopSound("bonus_scarab_loop")
	game:playSound("bonus_scarab")
end



function BonusScarab:draw(hidden, shadow)
	if self.path:getHidden(self.offset) == hidden then
		if shadow then
			self.shadowImage:draw(self.path:getPos(self.offset) + Vec2(4), Vec2(0.5))
		else
			self.sprite:draw(self.path:getPos(self.offset), {angle = self.path:getAngle(self.offset) + math.pi, color = Color(self.path:getBrightness(self.offset))})
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