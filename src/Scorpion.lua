local class = require "com.class"

---Represents a Scorpion, which moves along the path starting from the end point and moving backwards. Destroys any Spheres it encounters.
---@class Scorpion
---@overload fun(path, deserializationTable):Scorpion
local Scorpion = class:derive("Scorpion")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")



---Constructs a new Scorpion.
---@param path Path The path this Scorpion is on.
---@param deserializationTable table? The data to be loaded from if loading a saved game.
function Scorpion:new(path, deserializationTable)
	self.path = path

	self.config = _Game.configManager.gameplay.scorpion
	self.config.offset = self.config.offset or 0
	self.config.acceleration = self.config.acceleration or 0



	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.offset = path.length - self.config.offset
		self.speed = self.config.speed
		self.distance = 0
		self.trailDistance = 0
		self.destroyedSpheres = 0
		self.destroyedChains = 0
		self.maxSpheres = self.config.maxSpheres
		self.maxChains = self.config.maxChains
	end

	self.sprite = _Game.resourceManager:getSprite(self.config.sprite)
	self.shadowSprite = _Game.resourceManager:getSprite(self.config.shadowSprite)

	self.sound = _Game:playSound(self.config.loopSound, 1, self:getPos())

	self.delQueue = false
end



---Updates the Scorpion's logic.
---@param dt number Delta time in seconds.
function Scorpion:update(dt)
	-- Offset and distance
	self.speed = self.speed + self.config.acceleration * dt
	self.offset = self.offset - self.speed * dt
	self.distance = self.path.length - self.offset
	-- Destroying spheres
	while not self:shouldExplode() do
		-- Attempt to erase one sphere per iteration
		-- The routine simply finds the closest sphere to the pyramid
		-- If it's too far away, the loop ends
		if self.path:getEmpty() then
			break
		end
		local sphereGroup = self.path.sphereChains[1].sphereGroups[1]
		if sphereGroup:getFrontPos() + 16 > self.offset and sphereGroup:getLastSphere().color ~= 0 then
			sphereGroup:destroySphere(#sphereGroup.spheres)
			_Game:playSound(self.config.sphereDestroySound, 1, self:getPos())
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



---Returns whether the Scorpion should be now destroyed.
---@return boolean
function Scorpion:shouldExplode()
	return self.offset <= 64
	or (self.destroyedSpheres and self.destroyedSpheres == self.maxSpheres)
	or (self.destroyedChains and self.destroyedChains == self.maxChains)
end



---Destroys the Scorpion, adds points to score, plays a sound etc.
function Scorpion:explode()
	if self.delQueue then
		return
	end

	local pos = self:getPos()
	local score = self.destroyedSpheres * 100

	_Game.session.level:grantScore(score)
	_Game.session.level:spawnFloatingText(_NumStr(score), pos, self.config.scoreFont)
	_Game.session.level:spawnCollectiblesFromEntry(pos, self.config.destroyGenerator)
	_Game:spawnParticle(self.config.destroyParticle, pos)
	_Game:playSound(self.config.destroySound, 1, pos)

	self:destroy()
end



---Destructor.
function Scorpion:destroy()
	if self.delQueue then
		return
	end
	self.delQueue = true
	self.sound:stop()
end



---Draws this Scorpion on the screen.
---@param hidden boolean Whether this drawing call comes from a hidden sphere pass.
---@param shadow boolean Whether to draw the actual entity or its shadow.
function Scorpion:draw(hidden, shadow)
	if self:getHidden() == hidden then
		if shadow then
			self.shadowSprite:draw(self:getPos() + Vec2(4), Vec2(0.5))
		else
			self.sprite:draw(self:getPos(), Vec2(0.5), nil, nil, self:getAngle() + math.pi, Color(self:getBrightness()))
		end
	end
end



---Returns the onscreen position of this Scorpion.
---@return Vector2
function Scorpion:getPos()
	return self.path:getPos(self.offset)
end



---Returns the current angle of this Scorpion.
---@return number
function Scorpion:getAngle()
	return self.path:getAngle(self.offset)
end



---Returns the current brightness of this Scorpion.
---@return number
function Scorpion:getBrightness()
	return self.path:getBrightness(self.offset)
end



---Returns whether this Scorpion is marked as hidden.
---@return boolean
function Scorpion:getHidden()
	return self.path:getHidden(self.offset)
end



---Serializes this Scorpion to a set of values which can be reimported later.
---@return table
function Scorpion:serialize()
	local t = {
		offset = self.offset,
		speed = self.speed,
		distance = self.distance,
		trailDistance = self.trailDistance,
		destroyedSpheres = self.destroyedSpheres,
		destroyedChains = self.destroyedChains,
		maxSpheres = self.maxSpheres,
		maxChains = self.maxChains
	}
	return t
end



---Loads previously saved data from a given table.
---@param t table The data to be loaded.
function Scorpion:deserialize(t)
	self.offset = t.offset
	self.speed = t.speed
	self.distance = t.distance
	self.trailDistance = t.trailDistance
	self.destroyedSpheres = t.destroyedSpheres
	self.destroyedChains = t.destroyedChains
	self.maxSpheres = t.maxSpheres
	self.maxChains = t.maxChains
end



return Scorpion
