local class = require "com/class"
local SphereChain = class:derive("SphereChain")

local SphereGroup = require("src/SphereGroup")



function SphereChain:new(path, deserializationTable)
	self.path = path
	self.map = path.map

	if deserializationTable then
		self:deserialize(deserializationTable)
	else
		self.combo = 0
		self.comboScore = 0

		self.speedOverrideBase = 0
		self.speedOverrideMult = 1
		self.speedOverrideDecc = 0
		self.speedOverrideTime = 0

		self.sphereGroups = {}
		self.generationAllowed = self.path.spawnRules.type == "continuous"
		self.generationColor = self.path:newSphereColor()


		-- Generate the first group.
		self.sphereGroups[1] = SphereGroup(self)

		-- Pre-generate spheres if the level spawning rules allow doing so.
		if self.path.spawnRules.type == "waves" then
			for i = 1, self.path.spawnRules.amount do
				self:generateSphere()
			end
			self:concludeGeneration()
		end
	end

	self.maxOffset = 0

	self.delQueue = false
end



function SphereChain:update(dt)
	--print(self:getDebugText())

	-- Deal with chains overlapping.
	if not self.delQueue then
		local prevChain = self:getPreviousChain()
		if prevChain and not prevChain.delQueue then
			-- Check whether this sphere chain collides with a front one.
			local dist = prevChain:getLastSphereGroup():getSphereOffset(1) - self.sphereGroups[1]:getLastSphereOffset()
			if dist <= 32 then
				-- If so, either destroy the scarab or move the frontmost chain.
				if _Game.configManager.gameplay.sphereBehaviour.invincible_scarabs then
					if not prevChain:hasImmobileSpheres() then
						prevChain:getLastSphereGroup():move(32 - dist)
					end
				else
					prevChain:join()
				end
			end
		end
	end
	
	-- Update all sphere groups.
	-- Ultra-Safe Loop (TM)
	local i = 1
	while self.sphereGroups[i] do
		local sphereGroup = self.sphereGroups[i]
		if not sphereGroup.delQueue then
			sphereGroup:update(dt)
		end
		if self.sphereGroups[i] == sphereGroup then
			i = i + 1
		end
	end

	-- Update max offset.
	if #self.sphereGroups > 0 then
		if self.generationAllowed then
			while self:getLastSphereGroup().offset >= 0 do
				self:generateSphere()
			end
			if self.map.level.targetReached or self.map.level.lost then
				self:concludeGeneration()
			end
		end

		self.maxOffset = self.sphereGroups[1]:getLastSphereOffset()
	end

	-- Reset combo if necessary.
	if not self:isMatchPredicted() then
		self:endCombo()
	end
end

function SphereChain:move(offset)
	self.pos = self.pos + offset
	self.sphereGroups[1]:move(-offset)
end

function SphereChain:delete(joins)
	if self.delQueue then return end
	self.delQueue = true

	-- Remove itself from their path.
	table.remove(self.path.sphereChains, self.path:getSphereChainID(self))
	-- mark the position to where the bonus scarab should arrive
	if not joins and not self.map.level.lost then
		self.path.clearOffset = self.maxOffset
	end

	if joins then _Game:playSound("sound_events/sphere_destroy_vise.json") end
end

-- Unloads this chain.
function SphereChain:destroy()
	for i, sphereGroup in ipairs(self.sphereGroups) do
		sphereGroup:destroy()
	end
end

function SphereChain:getPreviousChain()
	return self.path.sphereChains[self.path:getSphereChainID(self) - 1]
end

function SphereChain:getNextChain()
	return self.path.sphereChains[self.path:getSphereChainID(self) + 1]
end

function SphereChain:isMatchPredicted()
	for i, sphereGroup in ipairs(self.sphereGroups) do
		if not sphereGroup.delQueue and (sphereGroup:isMagnetizing() or sphereGroup:hasShotSpheres() or sphereGroup:hasKeepComboSpheres()) then
			return true
		end
	end
end

function SphereChain:isPushingFrontTrain()
	if self.delQueue then
		return false
	end
	-- The previous chain (in front of this one) must exist.
	local prevChain = self:getPreviousChain()
	if prevChain and not prevChain.delQueue then
		-- Check whether this sphere chain collides with a front one. If so, return true.
		local dist = prevChain:getLastSphereGroup():getSphereOffset(1) - self.sphereGroups[1]:getLastSphereOffset()
		return dist <= 32
	end
end

function SphereChain:endCombo()
	if self.combo == 0 and self.comboScore == 0 then
		return
	end
	_Debug.console:print(self.comboScore)
	_Game.uiManager:executeCallback({
		name = "comboEnded",
		parameters = {self.combo, self.comboScore}
	})
	self.combo = 0
	self.comboScore = 0
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

function SphereChain:generateSphere()
	local group = self:getLastSphereGroup()

	-- Add a new sphere.
	self:getLastSphereGroup():pushSphereBack(self.generationColor)
	-- Each sphere: check whether we should generate a fresh new color (chance is colorStreak).
	if math.random() >= self.path.colorStreak then
		self.generationColor = self.path:newSphereColor()
	end
end

function SphereChain:concludeGeneration()
	-- Spawns a vise. Now eliminating a chain via removing all spheres contained is allowed.
	local group = self:getLastSphereGroup()

	-- Spawn a vise.
	group:pushSphereBack(0)

	self.generationAllowed = false
end



function SphereChain:draw(color, hidden, shadow)
	-- color: draw only spheres with a given color - this will enable batching and will reduce drawing time significantly
	-- hidden: with that, you can filter the spheres drawn either to the visible ones or to the invisible ones
	-- shadow: to make all shadows rendered before spheres
	--love.graphics.print(self:getDebugText(), 10, 10)
	for i, sphereGroup in ipairs(self.sphereGroups) do
		if not sphereGroup.delQueue then sphereGroup:draw(color, hidden, shadow) end
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
		comboScore = self.comboScore,
		speedOverrideBase = self.speedOverrideBase,
		speedOverrideMult = self.speedOverrideMult,
		speedOverrideDecc = self.speedOverrideDecc,
		speedOverrideTime = self.speedOverrideTime,
		sphereGroups = {},
		generationAllowed = self.generationAllowed,
		generationColor = self.generationColor
	}

	for i, sphereGroup in ipairs(self.sphereGroups) do
		table.insert(t.sphereGroups, sphereGroup:serialize())
	end

	return t
end

function SphereChain:deserialize(t)
	self.combo = t.combo
	self.comboScore = t.comboScore
	self.speedOverrideBase = t.speedOverrideBase
	self.speedOverrideMult = t.speedOverrideMult
	self.speedOverrideDecc = t.speedOverrideDecc
	self.speedOverrideTime = t.speedOverrideTime
	self.sphereGroups = {}
	self.generationAllowed = t.generationAllowed
	self.generationColor = t.generationColor

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
