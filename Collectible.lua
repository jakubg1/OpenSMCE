local class = require "class"
local Collectible = class:derive("Collectible")

local Vec2 = require("Essentials/Vector2")
local Image = require("Essentials/Image")
local Particle = require("Particle")

function Collectible:new(pos, data)
	self.data = data
	self.particle = Particle(game.resourceBank:getLegacyParticle("particles/collectible.json"), pos, data)
	
	self.delQueue = false
end

function Collectible:update(dt)
	self.particle:update(dt)
	if game.session.level.shooter:catchablePos(self.particle.pos) then self:catch() end
	if self.particle.delQueue then self:destroy() end
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
		game.session:spawnFloatingText(numStr(score), self.particle.pos, "fonts/score0.json")
	end
	if self.data.type == "powerup" then
		game.session:spawnFloatingText(POWERUP_CATCH_TEXTS[self.data.name], self.particle.pos, "fonts/score" .. tostring(self.data.color or 0) .. ".json")
	end
	game:spawnParticle("particles/powerup_catch.json", self.particle.pos)
end

function Collectible:destroy()
	if self.delQueue then return end
	self.delQueue = true
	self.particle:destroy()
end



function Collectible:draw()
	self.particle:draw()
end

return Collectible