### This class is not used yet. All sphere algorithms are stored in SphereGroup.lua.

local class = require "com/class"
local Sphere = class:derive("Sphere")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")

function Sphere:new(sphereGroup, deserializationTable, color, shootOrigin, shootTime)
	self.sphereGroup = sphereGroup
	self.path = sphereGroup.sphereChain.path
	self.map = sphereGroup.map

	-- these two are filled by the sphere group object
	self.prevSphere = nil
	self.nextSphere = nil

	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.color = color
		self.offset = 0
		self.size = 1
		self.boostCombo = false
		self.shootOrigin = nil
		self.shootTime = nil
	end

	self:loadConfig()

	if shootOrigin then
		self.shootOrigin = shootOrigin
		self.shootTime = shootTime
		self.size = 0
		self.frameOffset = 0
	end

	if not self.map.isDummy and self.color > 0 then
		_Game.session.colorManager:increment(self.color)
	end

	self.danger = false

	self.delQueue = false
end

function Sphere:update(dt)
	-- for spheres that are being added
	if self.size < 1 then
		self.size = self.size + dt / self.shootTime
		if self.size >= 1 then
			self.size = 1
			self.shootOrigin = nil
			self.shootTime = nil
			local index = self.sphereGroup:getSphereID(self)
			if self.sphereGroup:shouldBoostCombo(index) then
				self.boostCombo = true
			else
				self.map.level.combo = 0
			end
			if self.sphereGroup:shouldMatch(index) then self.sphereGroup:matchAndDelete(index) end
		end
	end
	-- if the sphere was flagged as it was a part of a combo but got obstructed then it's unflagged
	if self.boostCombo then
		if not self.sphereGroup:isMagnetizing() and not (self.sphereGroup.nextGroup and self.sphereGroup.nextGroup:isMagnetizing()) then self.boostCombo = false end
	end

	-- count/uncount the sphere from the danger sphere counts
	if not self.map.isDummy and self.color > 0 and not self.delQueue then
		local danger = self.sphereGroup.sphereChain:getDanger()
		if self.danger ~= danger then
			self.danger = danger
			if danger then
				_Game.session.colorManager:increment(self.color, true)
			else
				_Game.session.colorManager:decrement(self.color, true)
			end
		end
	end
end

function Sphere:updateOffset()
	-- calculate the offset
	self.offset = self.prevSphere and self.prevSphere.offset + 32 * self.size or 0
end

function Sphere:changeColor(color, particle)
	_Game.session.colorManager:decrement(self.color)
	_Game.session.colorManager:increment(color)
	self.color = color
	self:loadConfig()
	if particle then
		_Game:spawnParticle(particle, self:getPos())
	end
end

function Sphere:delete()
	if self.delQueue then return end
	self.delQueue = true
	if not self.map.isDummy and self.color ~= 0 then self.map.level:destroySphere() end
	-- update links !!!
	if self.prevSphere then self.prevSphere.nextSphere = self.nextSphere end
	if self.nextSphere then self.nextSphere.prevSphere = self.prevSphere end
	-- update color count
	if not self.map.isDummy and self.color > 0 then
		_Game.session.colorManager:decrement(self.color)
		if self.danger then
			_Game.session.colorManager:decrement(self.color, true)
		end
	end
	-- particles
	if not self.map.isDummy and (not self.map.level.lost or self.color == 0) then
		_Game:spawnParticle(_Game.configManager.spheres[self.color].destroyParticle, self:getPos())
	end
end

function Sphere:getFrame()
	return ((self.frameOffset + self.offset + self.sphereGroup.offset) * self.frameCount / 32) % self.frameCount
end

function Sphere:getOffset()
	return self.sphereGroup.offset + self.offset
end

function Sphere:getPos()
	return self.path:getPos(self:getOffset())
end

function Sphere:getAngle()
	return self.path:getAngle(self:getOffset())
end

function Sphere:getHidden()
	return self.path:getHidden(self:getOffset())
end

function Sphere:getColor()
	local brightness = self.path:getBrightness(self:getOffset())
	return Color(brightness)
end

function Sphere:isOffscreen()
	return self:getOffset() < 32
end



function Sphere:draw(color, hidden, shadow)
	if self.color ~= color or self:getHidden() ~= hidden then
		return
	end

	local pos = self:getPos()
	if self.size < 1 then
		pos = self.path:getPos(self:getOffset() + 16 - self.size * 16) * self.size + self.shootOrigin * (1 - self.size)
	end

	local angle = self.config.spriteAnimationSpeed and 0 or self:getAngle()
	if shadow then
		self.shadowSprite:draw(pos + Vec2(4), Vec2(0.5), nil, nil, angle)
	else
		local frame = Vec2(1)
		if self.config.spriteAnimationSpeed then
			frame = Vec2(math.floor(self.config.spriteAnimationSpeed * _TotalTime), 1)
		elseif self.size == 1 then
			frame = Vec2(math.ceil(self.frameCount - self:getFrame()), 1)
		end
		self.sprite:draw(pos, Vec2(0.5), nil, frame, angle, self:getColor())
	end
end



function Sphere:loadConfig()
	self.config = _Game.configManager.spheres[self.color]
	self.sprite = _Game.resourceManager:getSprite(self.config.sprite)
	-- TODO/DEPRECATED: Remove default value
	self.shadowSprite = _Game.resourceManager:getSprite(self.config.shadowSprite or "sprites/game/ball_shadow.json")
	self.frameCount = self.sprite.states[1].frameCount.x
	self.frameOffset = math.random() * self.frameCount -- move to the "else" part if you're a purist and want this to be saved

	if self.color == 0 then -- vises follow another way
		self.frameOffset = 0
	end
end



function Sphere:serialize()
	local t = {
		color = self.color,
		--frameOffset = self.frameOffset, -- who cares about that, you can uncomment this if you do
		shootOrigin = self.shootOrigin and {x = self.shootOrigin.x, y = self.shootOrigin.y} or nil,
		shootTime = self.shootTime
	}
	if self.size ~= 1 then t.size = self.size end
	if self.boostCombo then t.boostCombo = self.boostCombo end
	return t
end

function Sphere:deserialize(t)
	self.color = t.color
	--self.frameOffset = t.frameOffset
	self.size = t.size or 1
	self.boostCombo = t.boostCombo or false
	self.shootOrigin = t.shootOrigin and Vec2(t.shootOrigin.x, t.shootOrigin.y) or nil
	self.shootTime = t.shootTime
end

return Sphere
