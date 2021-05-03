local class = require "com/class"
local Scorpion = class:derive("Scorpion")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")

function Scorpion:new(path, deserializationTable)
	self.path = path

	self.settings = game.config.gameplay.scorpion



	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.offset = path.length
		self.distance = 0
		self.trailDistance = 0
		self.destroyedSpheres = 0
		self.destroyedChains = 0
		self.maxSpheres = self.settings.maxSpheres
		self.maxChains = self.settings.maxChains
	end

	self.image = game.resourceManager:getImage(self.settings.image)
	self.shadowImage = game.resourceManager:getImage("img/game/ball_shadow.png")

	game:playSound("scorpion_loop")

	self.delQueue = false
end

function Scorpion:update(dt)
	-- Offset and distance
	self.offset = self.offset - self.settings.speed * dt
	self.distance = self.path.length - self.offset
	-- Destroying spheres
	while (self.maxSpheres and self.destroyedSpheres < self.maxSpheres) or (self.maxChains and self.destroyedChains < self.maxChains) do
		-- Attempt to erase one sphere per iteration
		-- The routine simply finds the closest sphere to the pyramid
		-- If it's too far away, the loop ends
		if self.path:getEmpty() then break end
		local sphereGroup = self.path.sphereChains[1].sphereGroups[1]
		if sphereGroup:getFrontPos() + 16 > self.offset and sphereGroup:getLastSphere().color ~= 0 then
			sphereGroup:destroySphere(#sphereGroup.spheres)
			game.session.level:destroySphere()
			game:playSound("scorpion_destroys")
			self.destroyedSpheres = self.destroyedSpheres + 1
			-- if this sphere is the last sphere, the scorpion gets rekt
			if not sphereGroup.prevGroup and not sphereGroup.nextGroup and #sphereGroup.spheres == 1 and sphereGroup.spheres[1].color == 0 then
				self.destroyedChains = self.destroyedChains + 1
			end
		else
			break
		end
	end
	-- Trail
	if self.settings.trailParticle then
		while self.trailDistance < self.distance do
			local offset = self.path.length - self.trailDistance
			if not self.path:getHidden(offset) then -- the particles shouldn't be visible under obstacles
				game:spawnParticle(self.settings.trailParticle, self.path:getPos(offset))
			end
			self.trailDistance = self.trailDistance + self.settings.trailParticleDistance
		end
	end
	-- Destroy when near spawn point or when no more spheres to destroy
	if self.offset <= 64 or (self.destroyedSpheres and self.destroyedSpheres == self.maxSpheres) or (self.destroyedChains and self.destroyedChains == self.maxChains) then
		self:destroy()
	end
end

function Scorpion:destroy()
	if self.delQueue then return end
	self.delQueue = true
	local score = self.destroyedSpheres * 100
	game.session.level:grantScore(score)
	game.session.level:spawnFloatingText(numStr(score), self.path:getPos(self.offset), self.settings.scoreFont)
	if self.destroyedSpheres == self.maxSpheres then
		game.session.level:spawnCollectible(self.path:getPos(self.offset), {type = "coin"})
	end
	game:spawnParticle(self.settings.destroyParticle, self.path:getPos(self.offset))
	game:stopSound("scorpion_loop")
	game:playSound("scorpion_destroy")
end



function Scorpion:draw(hidden, shadow)
	if self.path:getHidden(self.offset) == hidden then
		if shadow then
			self.shadowImage:draw(self.path:getPos(self.offset) + Vec2(4), Vec2(0.5))
		else
			self.image:draw(self.path:getPos(self.offset), Vec2(0.5), nil, self.path:getAngle(self.offset) + math.pi, Color(self.path:getBrightness(self.offset)))
		end
	end
end



function Scorpion:serialize()
	local t = {
		offset = self.offset,
		distance = self.distance,
		trailDistance = self.trailDistance,
		destroyedSpheres = self.destroyedSpheres,
		destroyedChains = self.destroyedChains,
		maxSpheres = self.maxSpheres,
		maxChains = self.maxChains
	}
	return t
end

function Scorpion:deserialize(t)
	self.offset = t.offset
	self.distance = t.distance
	self.trailDistance = t.trailDistance
	self.destroyedSpheres = t.destroyedSpheres
	self.destroyedChains = t.destroyedChains
	self.maxSpheres = t.maxSpheres
	self.maxChains = t.maxChains
end

return Scorpion
