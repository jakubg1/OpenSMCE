--- Represents coins, gems and powerups that a Shooter can pick up.
-- @classmod Collectible



-- Class identification
local class = require "class"
local Collectible = class:derive("Collectible")

local Vec2 = require("Essentials/Vector2")
local Image = require("Essentials/Image")
local Sprite = require("Sprite")



--- Constructors
-- @section constructors

--- Object constructor.
-- Executed when this object is created.
-- @tparam table deserializationTable If not nil, this object will use the deserialization table rather than using next parameters.
-- @tparam Vector2 pos Where to spawn the Collectible in.
-- @tparam table data Collectible data.
function Collectible:new(deserializationTable, pos, data)
	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.data = data
		self.pos = pos
		self.speed = Vec2(math.random() * 100 - 50, math.random() * 100 - 250)
		self.acceleration = Vec2(0, 300)
	end
	
	self.sprite = Sprite("sprites/" .. self.data.type .. ".json", self.data)
end

function Collectible:update(dt)
	-- speed and position
	self.speed = self.speed + self.acceleration * dt
	self.pos = self.pos + self.speed * dt
	
	-- catching/bouncing/destroying
	if game.session.level.shooter:catchablePos(self.pos) then self:catch() end
	if self.pos.x < 10 then -- left
		self.pos.x = 10
		self.speed.x = -self.speed.x
	elseif self.pos.x > NATIVE_RESOLUTION.x - 10 then -- right
		self.pos.x = NATIVE_RESOLUTION.x - 10
		self.speed.x = -self.speed.x
	elseif self.pos.y < 10 then -- up
		self.pos.y = 10
		self.speed.y = -self.speed.y
	elseif self.pos.y > NATIVE_RESOLUTION.y + 20 then -- down - uncatched, falls down
		self:destroy()
	end
	
	-- sprite
	self.sprite:update(dt)
end

function Collectible:catch()
	self:destroy()
	if self.data.type == "powerup" then
		game.session:usePowerup(self.data)
	else
		game:playSound("collectible_catch_" .. self.data.type)
	end
	
	local score = 0
	if self.data.type == "coin" then
		score = 250
		game.session.level:grantCoin()
	elseif self.data.type == "gem" then
		score = self.data.color * 1000
		game.session.level:grantGem(self.data.color)
	end
	if score > 0 then
		game.session.level:grantScore(score)
		game.session.level:spawnFloatingText(numStr(score), self.pos, "fonts/score0.json")
	end
	if self.data.type == "powerup" then
		game.session.level:spawnFloatingText(POWERUP_CATCH_TEXTS[self.data.name], self.pos, "fonts/score" .. tostring(self.data.color or 0) .. ".json")
	end
	game:spawnParticle("particles/powerup_catch.json", self.pos)
end

function Collectible:destroy()
	if self._delQueue then return end
	self._list:destroy(self)
end



function Collectible:draw()
	self.sprite:draw(self.pos)
end



function Collectible:serialize()
	return {
		data = self.data,
		pos = {x = self.pos.x, y = self.pos.y},
		speed = {x = self.speed.x, y = self.speed.y},
		acceleration = {x = self.acceleration.x, y = self.acceleration.y}
	}
end

function Collectible:deserialize(t)
	self.data = t.data
	self.pos = Vec2(t.pos.x, t.pos.y)
	self.speed = Vec2(t.speed.x, t.speed.y)
	self.acceleration = Vec2(t.acceleration.x, t.acceleration.y)
end

return Collectible