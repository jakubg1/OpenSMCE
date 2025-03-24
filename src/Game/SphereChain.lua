local class = require "com.class"

---Represents a Sphere Chain, which is a single train of spheres, usually with a pusher (Scarab) at the end.
---@class SphereChain
---@overload fun(path, deserializationTable):SphereChain
local SphereChain = class:derive("SphereChain")

local json = require("com.json")
local SphereGroup = require("src.Game.SphereGroup")



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

		self.colorSortType = nil
		self.colorSortDelay = nil
		self.colorSortTime = nil
		self.colorSortStopWhenTampered = nil

		self.sphereGroups = {}

		local length = self.path:getCurrentTrainLength()
		self.generationAllowed = length == nil
		-- Set the initial state for the color generation.
		if self.path.trainRules.type == "random" then
			self.generationColor = self.path.trainRules.colors[math.random(#self.path.trainRules.colors)]
		elseif self.path.trainRules.type == "pattern" then
			self.generationIndex = 1
		elseif self.path.trainRules.type == "waves" then
			self.generationIndex = 1
			self.generationPreset = ""
			-- Generate a preset if the provided value is a preset generator.
			local preset = self.path:getCurrentTrainPreset()
			if not tonumber(preset:sub(1, 1)) then
				self.generationPreset = preset
			else
				local blocks = {}
				local blockIDs = {}
				-- Parse the preset generator into blocks.
				local strBlocks = _Utils.strSplit(preset, ",")
				for i, strBlock in ipairs(strBlocks) do
					local block = {pool = {}, size = 0} -- ex: {pool = {"X", "Y", "Z"}, size = 3}
					local spl = _Utils.strSplit(strBlock, ":")
					for j = 1, spl[2]:len() do
						table.insert(block.pool, spl[2]:sub(j, j))
					end
					spl = _Utils.strSplit(spl[1], "*")
					block.size = tonumber(spl[2])
					table.insert(blocks, block)
					for j = 1, tonumber(spl[1]) do
						table.insert(blockIDs, #blocks)
					end
				end
				-- Generate the preset from blocks.
				_Utils.tableShuffle(blockIDs)
				local lastKey = nil
				for i, blockID in ipairs(blockIDs) do
					local block = blocks[blockID]
					local pool = _Utils.copyTable(block.pool)
					if lastKey then
						_Utils.iTableRemoveValue(pool, lastKey)
					end
					assert(#pool > 0, "Level error: Could not generate the train because there are insufficient colors to ensure duplicates don't happen!")
					local key = pool[math.random(#pool)]
					self.generationPreset = self.generationPreset .. key:rep(block.size)
					lastKey = key
				end
			end
			-- Generate the set of colors for each key.
			self.generationKeys = {}
			for i, key in ipairs(self.path.trainRules.key) do
				if key.key then
					-- A single key.
					local keyData = {}
					keyData.color = key.colors[math.random(#key.colors)]
					if not key.homogenous and key.colorStreak then
						keyData.streak = key.colorStreak
						keyData.colors = key.colors
					end
					self.generationKeys[key.key] = keyData
				elseif key.keys then
					-- Multiple keys.
					local colorPool = _Utils.copyTable(key.colors)
					for j, keyName in ipairs(key.keys) do
						local keyData = {}
						local colorIdx = math.random(#colorPool)
						keyData.color = colorPool[colorIdx]
						if key.noColorRepeats then
							if #colorPool == 0 then
								error("Level error: Insufficient color amount for the `noColorRepeats` field. Must provide at least as many colors as there are keys!")
							end
							table.remove(colorPool, colorIdx)
						end
						if not key.homogenous and key.colorStreak then
							keyData.streak = key.colorStreak
							keyData.colors = key.colors
							keyData.forceDifferentColor = key.forceDifferentColor
						end
						self.generationKeys[keyName] = keyData
					end
				end
			end
		end

		-- Generate the first group.
		self.sphereGroups[1] = SphereGroup(self)

		-- Pre-generate spheres if the level spawning rules allow doing so.
		if length then
			for i = 1, length do
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
			local dist = prevChain:getLastSphereGroup():getBackPos() - self:getFirstSphereGroup():getFrontPos()
			if dist < 0 then
				-- If so, either destroy the scarab or move the frontmost chain (or slow down the one behind it).
				if _Game.configManager.gameplay.sphereBehavior.invincibleScarabs then
					if _Game.configManager.gameplay.sphereBehavior.invincibleScarabFrontMatters then
						self:getFirstSphereGroup():move(dist)
					else
						prevChain:getLastSphereGroup():move(-dist)
					end
				else
					prevChain:join()
				end
			end
		end
	end

	-- Update sorting.
	if self.colorSortTime then
		self.colorSortTime = self.colorSortTime - dt
		if self.colorSortTime <= 0 then
			self.colorSortTime = self.colorSortTime + self.colorSortDelay
			self:performColorSortStep()
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
			if not self.map.isDummy and (self.map.level:areAllObjectivesReached() or self.map.level.lost) then
				self:concludeGeneration()
			end
		end

		self.maxOffset = self.sphereGroups[1]:getLastSphereOffset()
	end

	-- Reset combo if necessary.
	if not self:isMatchPredicted() then
		self:endCombo()
	end

	-- Destroy itself if holds only non-generatable spheres.
	--[[
	if not self:hasGeneratableSpheres() then
		for i, sphereGroup in ipairs(self.sphereGroups) do
			local n = 1
			-- Avoid the vise. It has its own destruction routine.
			if i == #self.sphereGroups then
				n = 2
			end
			sphereGroup:destroySpheres(n, #sphereGroup.spheres)
		end
	end
	]]
end

function SphereChain:move(offset)
	self.pos = self.pos + offset
	self:getFirstSphereGroup():move(-offset)
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
		if not sphereGroup.delQueue and (
			sphereGroup:isMagnetizing() or
			sphereGroup:hasShotSpheres() or
			sphereGroup:hasKeepComboSpheres() or
			sphereGroup:hasGhostSpheres() or
			(_Game.configManager.gameplay.sphereBehavior.luxorized and sphereGroup.speed < 0)
		) then
			return true
		end
	end
end

-- FUNCTION UNUSED; DON'T USE
function SphereChain:hasGeneratableSpheres()
	for i, sphereGroup in ipairs(self.sphereGroups) do
		local remTable = self.map.level:getCurrentColorGenerator().colors
		for j, sphere in ipairs(sphereGroup.spheres) do
			if _Utils.isValueInTable(remTable, sphere.color) then
				return true
			end
		end
	end
	return false
end

function SphereChain:isPushingFrontTrain()
	if self.delQueue then
		return false
	end
	-- The previous chain (in front of this one) must exist.
	local prevChain = self:getPreviousChain()
	if prevChain and not prevChain.delQueue then
		-- Check whether this sphere chain collides with a front one. If so, return true.
		return self.sphereGroups[1]:getFrontPos() > prevChain:getLastSphereGroup():getBackPos()
	end
end

function SphereChain:endCombo()
	if self.combo == 0 and self.comboScore == 0 then
		return
	end
	--_Debug.console:print(self.comboScore)
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
	if not _Game.configManager.gameplay.sphereBehavior.noScarabs then
		self:getLastSphereGroup():destroySphere(1, true)
	end
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

---Returns the next color to spawn in this Sphere Chain. Alters the generator's state.
---@return integer
function SphereChain:newSphereColor()
	local rules = self.path.trainRules
	if rules.type == "random" then
		local result = self.generationColor
		-- `1 - colorStreak` chance to change the currently generated color.
		if math.random() < 1 - rules.colorStreak then
			local oldColor = self.generationColor
			repeat
				-- Reroll if we've got the same color and the config doesn't allow that.
				self.generationColor = rules.colors[math.random(#rules.colors)]
			until oldColor ~= self.generationColor or not rules.forceDifferentColor
		end
		return result
	elseif rules.type == "pattern" then
		local result = rules.pattern[self.generationIndex]
		self.generationIndex = self.generationIndex % #rules.pattern + 1
		return result
	elseif rules.type == "waves" then
		local key = self.generationPreset:sub(self.generationIndex, self.generationIndex)
		local keyData = self.generationKeys[key]
		local result = keyData.color
		if keyData.streak then
			-- `1 - colorStreak` chance to change the currently generated color.
			if math.random() < 1 - keyData.streak then
				local oldColor = keyData.color
				repeat
					-- Reroll if we've got the same color and the config doesn't allow that.
					keyData.color = keyData.colors[math.random(#keyData.colors)]
				until oldColor ~= keyData.color or not keyData.forceDifferentColor
			end
		end
		self.generationIndex = self.generationIndex + 1
		return result
	end
	-- This shouldn't happen.
	error(string.format("Invalid train rule type: %s", rules.type))
end

function SphereChain:generateSphere()
	-- Add a new sphere.
	self:getLastSphereGroup():pushSphereBack(self:newSphereColor())
end

function SphereChain:concludeGeneration()
	-- Spawns a vise. Now eliminating a chain via removing all spheres contained is allowed.
	local group = self:getLastSphereGroup()

	-- Spawn a vise.
	if not _Game.configManager.gameplay.sphereBehavior.noScarabs then
		group:pushSphereBack(0)
	end

	self.generationAllowed = false
end



---Initiates the process of sorting the colors in this Sphere Chain.
---@param sortType "instant"|"bubble" The sorting type.
---@param delay number The delay between consecutive sorts, or for `"instant"` type, the delay until the sort will happen.
---@param stopWhenTampered boolean If set, the sorting process will stop when this Sphere Chain is tampered with.
function SphereChain:sortColors(sortType, delay, stopWhenTampered)
	self.colorSortType = sortType
	self.colorSortDelay = delay
	self.colorSortTime = delay
	self.colorSortStopWhenTampered = stopWhenTampered
end

---Performs a Color Sort step on this Sphere Chain.
function SphereChain:performColorSortStep()
	local sphereList = self:getSphereList()
	local checkedColors = {0} -- The scarab is always banned from sorting.
	-- Search for a sphere which could be sorted.
	for i, sphere in ipairs(sphereList) do
		if not _Utils.isValueInTable(checkedColors, sphere.color) then
			-- Found a new color. Let's see if we can find a sphere which we could move back by one.
			local swapSphereIndex = nil
			for j = i + 1, #sphereList do
				if not swapSphereIndex and sphereList[j].color ~= sphere.color then
					-- We've moved past the first clump of the current color. The next sphere of that color can be moved back.
					swapSphereIndex = j
				elseif swapSphereIndex and sphereList[j].color == sphere.color then
					if self.colorSortType == "bubble" then
						swapSphereIndex = j - 1
					end
					-- We've found our prey! Move it back [by one and return only when bubble sorting].
					local colorTmp = sphereList[j].color
					sphereList[j]:changeColor(sphereList[swapSphereIndex].color)
					sphereList[swapSphereIndex]:changeColor(colorTmp)
					if self.colorSortType == "bubble" then
						return
					else
						-- Now we will need to swap the next sphere.
						swapSphereIndex = swapSphereIndex + 1
					end
				end
			end
			-- If we've come here, this color is sorted. No need to look for that one.
			table.insert(checkedColors, sphere.color)
		end
	end
	-- We went through all spheres and did not find anything to sort. The sorting is complete!
	self:stopColorSort()
end

---Stops the color sorting process for this Sphere Chain.
function SphereChain:stopColorSort()
	self.colorSortType = nil
	self.colorSortDelay = nil
	self.colorSortTime = nil
	self.colorSortStopWhenTampered = nil
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

---Returns the first (frontmost) Sphere Group in this Sphere Chain.
---@return SphereGroup
function SphereChain:getFirstSphereGroup()
	return self.sphereGroups[1]
end

---Returns the last (backmost) Sphere Group in this Sphere Chain.
---@return SphereGroup
function SphereChain:getLastSphereGroup()
	return self.sphereGroups[#self.sphereGroups]
end

---Returns a list of all Spheres in this Sphere Chain, bypassing Sphere Groups.
---The list starts from the tail. Last element is the frontmost one.
---@return table
function SphereChain:getSphereList()
	local spheres = {}
	for i = #self.sphereGroups, 1, -1 do
		for j, sphere in ipairs(self.sphereGroups[i].spheres) do
			table.insert(spheres, sphere)
		end
	end
	return spheres
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
		colorSortType = self.colorSortType,
		colorSortDelay = self.colorSortDelay,
		colorSortTime = self.colorSortTime,
		colorSortStopWhenTampered = self.colorSortStopWhenTampered,
		sphereGroups = {},
		generationAllowed = self.generationAllowed,
		generationColor = self.generationColor,
		generationIndex = self.generationIndex,
		generationPreset = self.generationPreset,
		generationKeys = self.generationKeys
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
	self.colorSortType = t.colorSortType
	self.colorSortDelay = t.colorSortDelay
	self.colorSortTime = t.colorSortTime
	self.colorSortStopWhenTampered = t.colorSortStopWhenTampered
	self.sphereGroups = {}
	self.generationAllowed = t.generationAllowed
	self.generationColor = t.generationColor
	self.generationIndex = t.generationIndex
	self.generationPreset = t.generationPreset
	self.generationKeys = t.generationKeys

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
