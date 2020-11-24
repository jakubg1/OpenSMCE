### This class is not used yet. All sphere algorithms are stored in SphereGroup.lua.

local class = require "com/class"
local Sphere = class:derive("Sphere")

local Vec2 = require("src/Essentials/Vector2")

function Sphere:new(sphereGroup, deserializationTable, color, shootOrigin)
	self.sphereGroup = sphereGroup
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
	end
	
	self.frameOffset = math.random() * 32 -- move to the "else" part if you're a purist and want this to be saved
	
	if self.color == 0 then -- vises follow another way
		self.frameOffset = 0
	end
	
	if shootOrigin then
		self.shootOrigin = shootOrigin
		self.size = 0
	end
	
	if not self.map.isDummy and self.color > 0 then
		game.session.sphereColorCounts[self.color] = game.session.sphereColorCounts[self.color] + 1
	end
	
	self.danger = false
	
	self.delQueue = false
end

function Sphere:update(dt)
	-- for spheres that are being added
	if self.size < 1 then
		self.size = self.size + dt / 0.15
		if self.size >= 1 then
			self.size = 1
			self.shootOrigin = nil
			local index = self.sphereGroup:getSphereID(self)
			if self.sphereGroup:shouldBoostCombo(index) then
				self.boostCombo = true
			else
				self.map.level.combo = 0
			end
			--if self.sphereGroup:shouldFit(index) then SOUNDS.hit2:play() end
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
				game.session.dangerSphereColorCounts[self.color] = game.session.dangerSphereColorCounts[self.color] + 1
			else
				game.session.dangerSphereColorCounts[self.color] = game.session.dangerSphereColorCounts[self.color] - 1
			end
		end
	end
end

function Sphere:updateOffset()
	-- calculate the offset
	self.offset = self.prevSphere and self.prevSphere.offset + 32 * self.size or 0
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
		game.session.sphereColorCounts[self.color] = game.session.sphereColorCounts[self.color] - 1
		game.session.lastSphereColor = self.color
		if self.danger then
			game.session.dangerSphereColorCounts[self.color] = game.session.dangerSphereColorCounts[self.color] - 1
		end
	end
	-- particles
	if self.color == 0 then
		game:spawnParticle("particles/collapse_vise.json", self.sphereGroup:getSpherePos(self.sphereGroup:getSphereID(self)))
	end
	if not self.map.isDummy and not self.map.level.lost then
		if self.color == -1 then
			game:spawnParticle("particles/collapse_ball_6.json", self.sphereGroup:getSpherePos(self.sphereGroup:getSphereID(self)))
		end
		if self.color > 0 then
			game:spawnParticle("particles/collapse_ball_" .. tostring(self.color) .. ".json", self.sphereGroup:getSpherePos(self.sphereGroup:getSphereID(self)))
		end
	end
end

function Sphere:getFrame()
	if self.color == 0 then return 1 end
	return (self.frameOffset + self.offset + self.sphereGroup.offset) % 32
end



function Sphere:serialize()
	local t = {
		color = self.color,
		--frameOffset = self.frameOffset, -- who cares about that, you can uncomment this if you do
		shootOrigin = self.shootOrigin and {x = self.shootOrigin.x, y = self.shootOrigin.y} or nil
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
end

return Sphere