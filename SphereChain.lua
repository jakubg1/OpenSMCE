local class = require "class"
local SphereChain = class:derive("SphereChain")

local Vec2 = require("Essentials/Vector2")
local Image = require("Essentials/Image")

local SphereGroup = require("SphereGroup")
local Sphere = require("Sphere")

function SphereChain:new(path, deserializationTable)
	self.path = path
	self.map = path.map
	
	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.combo = 0
		
		self.slowTime = 0
		self.stopTime = 0
		self.reverseTime = 0
		
		--[[ example:
			how it looks:
			xoooo     oo ooooo    ooo
			
			groups:
			1: offset=0, spheres=[0,1,3,2,2](len=5)
			2: offset=160, spheres=[4,1](len=2)
			3: offset=192, spheres=[3,3,1,3,4](len=5)
			4: offset=278, spheres=[2,4,1](len=3)
		--]]
		
		self.sphereGroups = {
			SphereGroup(self)
		}
		
		-- Pregenerate spheres
		self.sphereGroups[1].spheres[1] = Sphere(self.sphereGroups[1], nil, 0)
		local color = self.map.level:newSphereColor()
		for i = 1, self.map.level.spawnAmount do
			if math.random() >= self.map.level.colorStreak then color = self.map.level:newSphereColor() end
			self.sphereGroups[1].spheres[i + 1] = Sphere(self.sphereGroups[1], nil, color)
			self.sphereGroups[1].spheres[i].nextSphere = self.sphereGroups[1].spheres[i + 1]
			self.sphereGroups[1].spheres[i + 1].prevSphere = self.sphereGroups[1].spheres[i]
		end
		self.sphereGroups[1].offset = -32 * #self.sphereGroups[1].spheres -- 5000
	end
	
	self.maxOffset = 0
	
	self.delQueue = false
end

function SphereChain:update(dt)
	--print(self:getDebugText())
	for i, sphereGroup in ipairs(self.sphereGroups) do
		if not sphereGroup.delQueue then sphereGroup:update(dt) end
	end
	if #self.sphereGroups > 0 then self.maxOffset = self.sphereGroups[1]:getLastSphereOffset() end
	if not self:isMatchPredicted() then self.combo = 0 end
end

function SphereChain:move(offset)
	self.pos = self.pos + offset
	self.sphereGroups[1]:move(-offset)
end

function SphereChain:delete(joins)
	if self.delQueue then return end
	self.delQueue = true
	table.remove(self.path.sphereChains, self.path:getSphereChainID(self))
	-- mark the position to where the bonus scarab should arrive
	if not joins and not self.map.level.lost then self.path.clearOffset = self.maxOffset end
	
	if joins then game:playSound("sphere_destroy_vise") end
end

function SphereChain:isMatchPredicted()
	for i, sphereGroup in ipairs(self.sphereGroups) do
		if not sphereGroup.delQueue and (sphereGroup:isMagnetizing() or sphereGroup:hasShotSpheres()) then return true end
	end
end

function SphereChain:join()
	-- Joins with the previous group and deletes a vise from this group.
	local prevChain = self.path.sphereChains[self.path:getSphereChainID(self) + 1]
	self:getLastSphereGroup():destroySphere(1)
	-- update group links
	self:getLastSphereGroup().prevGroup = prevChain.sphereGroups[1]
	prevChain.sphereGroups[1].nextGroup = self:getLastSphereGroup()
	-- copy all groups
	local joinIndex = #self.sphereGroups
	for i, sphereGroup in ipairs(self.sphereGroups) do
		sphereGroup.sphereChain = prevChain
		table.insert(prevChain.sphereGroups, 1, sphereGroup)
	end
	if self.sphereGroups[joinIndex]:getMatchLengthInChain(1) >= 3 then self.sphereGroups[joinIndex].matchCheck = false end
	-- combine combos
	prevChain.combo = prevChain.combo + self.combo
	self:delete(true)
end



function SphereChain:draw(hidden, shadow)
	-- hidden: with that, you can filter the spheres drawn either to the visible ones or to the invisible ones
	-- shadow: to make all shadows rendered before spheres
	--love.graphics.print(self:getDebugText(), 10, 10)
	for i, sphereGroup in ipairs(self.sphereGroups) do
		if not sphereGroup.delQueue then sphereGroup:draw(hidden, shadow) end
	end
	--local pos = self.path:getPos(self.sphereGroups[1]:getLastSphereOffset())
	--love.graphics.circle("fill", pos.x, pos.y, 8)
	--love.graphics.setColor(0, 0, 0)
	--love.graphics.print(self:getDebugText(), 40, 40 + self.path:getSphereChainID(self) * 100)
end

function SphereChain:getSphereGroupID(sphereGroup)
	for i, sphereGroupT in pairs(self.sphereGroups) do if sphereGroupT == sphereGroup then return i end end
	return "ERROR"
end

function SphereChain:getLastSphereGroup()
	return self.sphereGroups[#self.sphereGroups]
end

function SphereChain:getDanger()
	return self.path:getDanger(self.maxOffset)
end



function SphereChain:getDebugText()
	local text = ""
	-- for i, sphereGroup in ipairs(self.sphereGroups) do
		-- if not sphereGroup.delQueue then
			-- if sphereGroup.prevGroup then
				-- text = text .. sphereGroup.prevGroup:getDebugText()
			-- else
				-- text = text .. "xxx"
			-- end
			-- text = text .. " -> " .. sphereGroup:getDebugText() .. " -> "
			-- if sphereGroup.nextGroup then
				-- text = text .. sphereGroup.nextGroup:getDebugText()
			-- else
				-- text = text .. "xxx"
			-- end
			-- if sphereGroup.delQueue then text = text .. " X" end
			-- text = text .. "\n"
		-- end
	-- end
	for i, sphereGroup in ipairs(self.sphereGroups) do
		if not sphereGroup.delQueue then
			if sphereGroup.prevGroup then
				text = text .. tostring(self:getSphereGroupID(sphereGroup.prevGroup)) .. " (" .. tostring(sphereGroup.prevGroup.offset) .. ")"
			else
				text = text .. "xxx"
			end
			text = text .. " -> " .. tostring(self:getSphereGroupID(sphereGroup)) .. " (" .. tostring(sphereGroup.offset) .. ")" .. " -> "
			if sphereGroup.nextGroup then
				text = text .. tostring(self:getSphereGroupID(sphereGroup.nextGroup)) .. " (" .. tostring(sphereGroup.nextGroup.offset) .. ")"
			else
				text = text .. "xxx"
			end
			if sphereGroup.delQueue then text = text .. " X" end
			text = text .. "\n"
		end
	end
	return text
end



function SphereChain:serialize()
	local t = {
		combo = self.combo,
		slowTime = self.slowTime,
		stopTime = self.stopTime,
		reverseTime = self.reverseTime,
		sphereGroups = {}
	}
	for i, sphereGroup in ipairs(self.sphereGroups) do
		table.insert(t.sphereGroups, sphereGroup:serialize())
	end
	return t
end

function SphereChain:deserialize(t)
	self.combo = t.combo
	self.slowTime = t.slowTime
	self.stopTime = t.stopTime
	self.reverseTime = t.reverseTime
	self.sphereGroups = {}
	for i, sphereGroup in ipairs(t.sphereGroups) do
		local s = SphereGroup(self, sphereGroup)
		-- links are mandatory!!!
		if i > 1 then
			s.nextGroup = self.sphereGroups[i - 1]
			self.sphereGroups[i - 1].prevGroup = s
		end
		table.insert(self.sphereGroups, s)
	end
end

return SphereChain