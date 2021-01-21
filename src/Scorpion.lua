local class = require "com/class"
local Scorpion = class:derive("Scorpion")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")

function Scorpion:new(path, deserializationTable)
	self.path = path
	
	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.offset = path.length
		self.distance = 0
		self.trailDistance = 0
		self.destroyedSpheres = 0
		self.maxSpheres = 8
	end
	
	self.image = game.resourceBank:getImage("img/game/vise.png")
	self.shadowImage = game.resourceBank:getImage("img/game/ball_shadow.png")
	
	game:playSound("bonus_scarab_loop")
	
	self.delQueue = false
end

function Scorpion:update(dt)
	-- Offset and distance
	self.offset = self.offset - 2000 * dt
	self.distance = self.path.length - self.offset
	-- Destroying spheres
	while self.destroyedSpheres < self.maxSpheres do
		-- Attempt to erase one sphere per iteration
		-- The routine simply finds the closest sphere to the pyramid
		-- If it's too far away, the loop ends
		if self.path:getEmpty() then break end
		local sphereGroup = self.path.sphereChains[1].sphereGroups[1]
		if sphereGroup:getFrontPos() + 16 > self.offset and sphereGroup:getLastSphere().color ~= 0 then
			sphereGroup:destroySphere(#sphereGroup.spheres)
			game.session.level:destroySphere()
			self.destroyedSpheres = self.destroyedSpheres + 1
			-- if this sphere is the last sphere, the scorpion gets rekt (TODO make it configurable)
			if not sphereGroup.prevGroup and not sphereGroup.nextGroup and #sphereGroup.spheres == 1 and sphereGroup.spheres[1].color == 0 then
				self:destroy()
			end
		else
			break
		end
	end
	-- Trail
	while self.trailDistance < self.distance do
		local offset = self.path.length - self.trailDistance
		if not self.path:getHidden(offset) then -- the particles shouldn't be visible under obstacles
			game:spawnParticle("particles/bonus_scarab_trail.json", self.path:getPos(offset))
		end
		self.trailDistance = self.trailDistance + 24
	end
	-- Destroy when near spawn point or when no more spheres to destroy
	if self.offset <= 64 or self.destroyedSpheres == self.maxSpheres then
		self:destroy()
	end
end

function Scorpion:destroy()
	if self.delQueue then return end
	self.delQueue = true
	local score = self.destroyedSpheres * 100
	game.session.level:grantScore(score)
	game.session.level:spawnFloatingText(numStr(score), self.path:getPos(self.offset), "fonts/score0.json")
	if self.destroyedSpheres == self.maxSpheres then
		game.session.level:spawnCollectible(self.path:getPos(self.offset), {type = "coin"})
	end
	game:spawnParticle("particles/collapse_vise.json", self.path:getPos(self.offset))
	game:stopSound("bonus_scarab_loop")
	game:playSound("bonus_scarab")
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
		maxSpheres = self.maxSpheres
	}
	return t
end

function Scorpion:deserialize(t)
	self.offset = t.offset
	self.distance = t.distance
	self.trailDistance = t.trailDistance
	self.destroyedSpheres = t.destroyedSpheres
	self.maxSpheres = t.maxSpheres
end

return Scorpion