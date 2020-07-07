### This class is not used yet. All sphere algorithms are stored in SphereGroup.lua.

local class = require "class"
local Sphere = class:derive("Sphere")

local Vec2 = require("Essentials/Vector2")

function Sphere:new(sphereGroup, color, shootOrigin)
	self.sphereGroup = sphereGroup
	-- these two are filled by the sphere group object
	self.prevSphere = nil
	self.nextSphere = nil
	
	self.color = color
	self.frame = 0
	self.frameOffset = math.random() * 32
	self.offset = 0
	self.size = 1
	self.boostCombo = false
	self.shootOrigin = nil
	
	if self.color == 0 then -- vises follow another way
		self.frame = 1
		self.frameOffset = 0
	end
	
	if shootOrigin then
		self.shootOrigin = shootOrigin
		self.size = 0
	end
	
	if self.color > 0 then
		game.session.sphereColorCounts[self.color] = game.session.sphereColorCounts[self.color] + 1
	end
	
	self.danger = false
	
	self.delQueue = false
end

function Sphere:update(dt)
	-- sphere animation
	if self.color > 0 then self.frame = (self.frameOffset + self.offset + self.sphereGroup.offset) % 32 end
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
				game.session.level.combo = 0
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
	if self.color > 0 and not self.delQueue then
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
	if self.color ~= 0 then game.session.level:destroySphere() end
	-- update links !!!
	if self.prevSphere then self.prevSphere.nextSphere = self.nextSphere end
	if self.nextSphere then self.nextSphere.prevSphere = self.prevSphere end
	if self.color > 0 then
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
	if not game.session.level.lost then
		if self.color == -1 then
			game:spawnParticle("particles/collapse_ball_6.json", self.sphereGroup:getSpherePos(self.sphereGroup:getSphereID(self)))
		end
		if self.color > 0 then
			game:spawnParticle("particles/collapse_ball_" .. tostring(self.color) .. ".json", self.sphereGroup:getSpherePos(self.sphereGroup:getSphereID(self)))
		end
	end
end

return Sphere