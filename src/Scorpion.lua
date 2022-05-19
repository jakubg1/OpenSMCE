local class = require "com/class"
local Scorpion = class:derive("Scorpion")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")

function Scorpion:new(path, deserializationTable)
	self.path = path

	self.config = _Game.configManager.gameplay.scorpion



	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.offset = path.length
		self.distance = 0
		self.trailDistance = 0
		self.destroyedSpheres = 0
		self.destroyedChains = 0
		self.maxSpheres = self.config.maxSpheres
		self.maxChains = self.config.maxChains
	end

	self.sprite = _Game.resourceManager:getSprite(self.config.sprite)
	self.shadowSprite = _Game.resourceManager:getSprite("sprites/game/ball_shadow.json")

	self.sound = _Game:playSound("sound_events/scorpion_loop.json", 1, self:getPos())

	self.delQueue = false
end

function Scorpion:update(dt)
	-- Offset and distance
	self.offset = self.offset - self.config.speed * dt
	self.distance = self.path.length - self.offset
	-- Destroying spheres
	while not self:shouldExplode() do
		-- Attempt to erase one sphere per iteration
		-- The routine simply finds the closest sphere to the pyramid
		-- If it's too far away, the loop ends
		if self.path:getEmpty() then break end
		local sphereGroup = self.path.sphereChains[1].sphereGroups[1]
		if sphereGroup:getFrontPos() + 16 > self.offset and sphereGroup:getLastSphere().color ~= 0 then
			sphereGroup:destroySphere(#sphereGroup.spheres)
			_Game.session.level:destroySphere()
			_Game:playSound("sound_events/scorpion_destroys.json")
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
	-- Destroy when near spawn point or when no more spheres to destroy
	if self:shouldExplode() then
		self:explode()
	end
end

function Scorpion:shouldExplode()
	return self.offset <= 64
	or (self.destroyedSpheres and self.destroyedSpheres == self.maxSpheres)
	or (self.destroyedChains and self.destroyedChains == self.maxChains)
end

function Scorpion:explode()
	if self.delQueue then return end
	local score = self.destroyedSpheres * 100
	_Game.session.level:grantScore(score)
	_Game.session.level:spawnFloatingText(_NumStr(score), self:getPos(), self.config.scoreFont)
	if self.destroyedSpheres == self.maxSpheres then
		_Game.session.level:spawnCollectible(self:getPos(), _Game.session.level:newCoinData())
	end
	_Game:spawnParticle(self.config.destroyParticle, self:getPos())
	_Game:playSound("sound_events/scorpion_destroy.json", 1, self:getPos())

	self:destroy()
end

function Scorpion:destroy()
	if self.delQueue then return end
	self.delQueue = true
	self.sound:stop()
end



function Scorpion:draw(hidden, shadow)
	if self:getHidden() == hidden then
		if shadow then
			self.shadowSprite:draw(self:getPos() + Vec2(4), Vec2(0.5))
		else
			self.sprite:draw(self:getPos(), Vec2(0.5), nil, nil, self:getAngle() + math.pi, Color(self:getBrightness()))
		end
	end
end



function Scorpion:getPos()
	return self.path:getPos(self.offset)
end

function Scorpion:getAngle()
	return self.path:getAngle(self.offset)
end

function Scorpion:getBrightness()
	return self.path:getBrightness(self.offset)
end

function Scorpion:getHidden()
	return self.path:getHidden(self.offset)
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
