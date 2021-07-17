local class = require "com/class"
local Collectible = class:derive("Collectible")

local Vec2 = require("src/Essentials/Vector2")
local Image = require("src/Essentials/Image")

function Collectible:new(deserializationTable, pos, data)
	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.data = data
		self.pos = pos
		local beh = game.configManager.config.gameplay.collectibleBehaviour
		self.speed = parseVec2(beh.speed)
		self.acceleration = parseVec2(beh.acceleration)
	end

	self.powerupConfig = nil

	local particleName = nil
	if self.data.type == "powerup" then
		self.powerupConfig = game.configManager.powerups[self.data.name]
		if self.powerupConfig.colored then
			particleName = self.powerupConfig.particle[tostring(self.data.color)]
		else
			particleName = self.powerupConfig.particle
		end
	elseif self.data.type == "gem" then
		particleName = "particles/gem_" .. tostring(self.data.color) .. ".json"
	elseif self.data.type == "coin" then
		particleName = "particles/powerup_coin.json"
	end
	self.particle = game:spawnParticle(particleName, self.pos)
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
	self.particle.pos = self.pos
end

function Collectible:catch()
	self:destroy()
	if self.data.type == "powerup" then
		for i, effect in ipairs(self.powerupConfig.effects) do
			game.session:usePowerupEffect(effect)
		end
		game:playSound(self.powerupConfig.pickupSound, 1, self.pos)
	else
		game:playSound("collectible_catch_" .. self.data.type, 1, self.pos)
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
		local font = self.powerupConfig.pickupFont
		if self.powerupConfig.colored then
			font = game.configManager.spheres[self.data.color].matchFont
		end
		game.session.level:spawnFloatingText(self.powerupConfig.pickupName, self.pos, font)
	end
	game:spawnParticle("particles/powerup_catch.json", self.pos)
end

function Collectible:destroy()
	if self._delQueue then return end
	self._list:destroy(self)
	self.particle:destroy()
end



function Collectible:draw()

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
