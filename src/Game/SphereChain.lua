local class = require "com.class"
local SphereGroup = require("src.Game.SphereGroup")

---Represents a Sphere Chain, which is a single train of spheres, usually with a pusher (Scarab) at the end.
---@class SphereChain
---@overload fun(path, data):SphereChain
local SphereChain = class:derive("SphereChain")

---Constructs a new Sphere Chain.
---@param path Path The path this Sphere Chain is on.
---@param data table? Saved data if this Sphere Chain is loaded from a saved game.
function SphereChain:new(path, data)
	self.path = path
	self.map = path.map

	self.config = _Game.configManager.gameplay.sphereBehavior

	if data then
		self:deserialize(data)
	else
		self.cascade = 0
		self.cascadeScore = 0

		self.speedOverrideBase = 0
		self.speedOverrideMult = 1
		self.speedOverrideDecc = 0
		self.speedOverrideTime = 0

		self.colorSortType = nil
		self.colorSortDelay = nil
		self.colorSortTime = nil
		self.colorSortStopWhenTampered = nil

		---@type SphereGroup[]
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
					for j = 1, tonumber(spl[1]) do
						table.insert(blocks, block)
					end
				end
				-- Generate the preset from blocks.
				-- We need to make sure the same color (letter/key, colors are dispatched later) is not appearing in any two neighboring groups.
				--
				-- Key insights: (note that whenever "color" is said that actually means "key" in this context)
				-- - Group sizes can be disregarded altogether, because their neighborhood doesn't change at all no matter how big or small
				--    the groups are (we assume n>0).
				-- - All generators with only groups of colors>=3 are possible, because at any possible insertion point inside the built train
				--    there are at most 2 blocked colors, so for 3 or more colors there's always at least one good color which can be used.
				-- - All generators with groups of colors>=2 are possible, because at the beginning and end of the built train
				--    there's always exactly one blocked color, so the group can always pick the other one.
				-- - If there is at least one single color group, all generators are possible as long as there is no color for which the amount of
				--    single color groups is greater than N/2 rounded up, where N is the total number of groups.
				-- - If so, you could always place them next to each other and fill the gaps inside with a different color; this is also an exclusive
				--    condition for impossibility if we disregard blatant errors like groups of size = 0 or amount of colors = 0.
				-- - Because the groups which have 2 or more colors are always going to have at least two valid places (the edges) to be inserted,
				--    the generation should always start by picking a random single color group and only if none of them can be inserted at any
				--    position, then place one group of the next smallest number of colors.
				-- - Placing any of these groups will automatically enable at least one of the single color groups to be placed next to the previously
				--    inserted group regardless of that group's position, and if we run out of everything while still having single color groups left
				--    which cannot be dispatched, we've basically hit the impossibility condition.
				--    (we've started with a single, then we've dispatched all X multi-color groups, and as such another X single color groups,
				--    hence we've dispatched 2X+1 groups out of which X+1 were single color and only single color groups are left,
				--    and as such we've proven no valid combination is possible).
				local genBlocks = {} -- ex: {{key = "X", size = 3}, {key = "Y", size = 1}, ...}
				while #blocks > 0 do
					-- Each iteration = one inserted block (or crash if no valid combination is possible).
					-- Compose the block order and iterate through it here.
					-- #pool=1 blocks in random order, then #pool=2 blocks in random order, then #pool=3 blocks in random order, and so on.
					local blockPools = {} -- ex: {[1] = {<block>, <block>}, [3] = {<block>}, [7] = {<block>}}, where <block> is ex: {pool = {"X", "Y", "Z"}, size = 3}
					local blockPoolSizes = {}
					for i, block in ipairs(blocks) do
						if not blockPools[#block.pool] then
							blockPools[#block.pool] = {}
							table.insert(blockPoolSizes, #block.pool)
						end
						table.insert(blockPools[#block.pool], block)
					end
					-- Flatten the pools by shuffling all blocks within their pools and combining them together into one table with increasing pool size.
					local blocksIter = {} -- ex: {<block #pool=1>, <block #pool=1>, <block #pool=3>, <block #pool=7>, <block #pool=7>}
					for i, index in ipairs(blockPoolSizes) do
						local pool = blockPools[index]
						_Utils.tableShuffle(pool)
						for j, block in ipairs(pool) do
							table.insert(blocksIter, block)
						end
					end
					local success = false
					for i, block in ipairs(blocksIter) do
						local gapInfo = {}
						local validGaps = {}
						for j = 1, #genBlocks + 1 do
							-- For each position we can insert this group to, check which keys it can have.
							local prevBlock = genBlocks[j - 1]
							local nextBlock = genBlocks[j]
							local validKeys = _Utils.copyTable(block.pool)
							if prevBlock then
								_Utils.iTableRemoveValue(validKeys, prevBlock.key)
							end
							if nextBlock then
								_Utils.iTableRemoveValue(validKeys, nextBlock.key)
							end
							gapInfo[j] = validKeys
							if #validKeys > 0 then
								table.insert(validGaps, j)
							end
						end
						if #validGaps > 0 then
							-- Success! Roll the key out of valid ones, and add the block to the list.
							local index = validGaps[math.random(#validGaps)]
							local keys = gapInfo[index]
							local key = keys[math.random(#keys)]
							table.insert(genBlocks, index, {key = key, size = block.size})
							_Utils.iTableRemoveFirstValue(blocks, block)
							success = true
							break
						end
					end
					-- If `success` is `false`, we've exhausted all possibilities.
					assert(success, string.format("Level error: Impossible combination of blocks for the wave `%s`! If there is at least one possible combination without repeat keys next to each other, let me know!", preset))
				end
				-- Generate the string from blocks.
				for i, block in ipairs(genBlocks) do
					self.generationPreset = self.generationPreset .. block.key:rep(block.size)
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
					keyData.chainChances = key.chainChances
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
						keyData.chainChances = key.chainChances
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
				if self.config.invincibleScarabs then
					if self.config.invincibleScarabFrontMatters then
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

	-- Reset the cascade combo if necessary.
	if self.config.cascadeScope == "chain" and not self:isMatchPredicted() then
		self:endCascade()
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
			sphereGroup:hasKeepCascadeSpheres() or
			sphereGroup:hasGhostSpheres() or
			(self.config.luxorized and sphereGroup.speed < 0)
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

---Resets the cascade combo value for this Sphere Chain to 0 and emits a `cascadeEnded` UI callback if the values were greater than 0.
function SphereChain:endCascade()
	if self.cascade == 0 and self.cascadeScore == 0 then
		return
	end
	--_Debug:print("chain " .. self.cascadeScore)
	_Game.uiManager:executeCallback({
		name = "cascadeEnded",
		parameters = {self.cascade, self.cascadeScore}
	})
	self.cascade = 0
	self.cascadeScore = 0
end

function SphereChain:join()
	-- Joins with the previous group and deletes a vise from this group.
	local prevChain = self.path.sphereChains[self.path:getSphereChainID(self) + 1]
	if not self.config.noScarabs then
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
	prevChain.cascade = prevChain.cascade + self.cascade
	prevChain.cascadeScore = prevChain.cascadeScore + self.cascadeScore
	self:delete(true)
end

---Returns the next sphere data (`{color = <integer>, chainLevel = <integer>}`) to spawn in this Sphere Chain. Alters the generator's state.
---@return table
function SphereChain:newSphereData()
	local rules = self.path.trainRules
	if rules.type == "random" then
		local color = self.generationColor
		-- `1 - colorStreak` chance to change the currently generated color.
		if math.random() < 1 - rules.colorStreak then
			local oldColor = self.generationColor
			repeat
				-- Reroll if we've got the same color and the config doesn't allow that.
				self.generationColor = rules.colors[math.random(#rules.colors)]
			until oldColor ~= self.generationColor or not rules.forceDifferentColor
		end
		-- Generate the chain level.
		local chainLevel = 0
		if rules.chainChances then
			for i, chance in ipairs(rules.chainChances) do
				if math.random() < chance then
					chainLevel = i
					break
				end
			end
		end
		return {color = color, chainLevel = chainLevel}
	elseif rules.type == "pattern" then
		local color = rules.pattern[self.generationIndex]
		-- Generate the chain level.
		local chainLevel = 0
		if rules.chainChances then
			for i, chance in ipairs(rules.chainChances) do
				if math.random() < chance then
					chainLevel = i
					break
				end
			end
		end
		self.generationIndex = self.generationIndex % #rules.pattern + 1
		return {color = color, chainLevel = chainLevel}
	elseif rules.type == "waves" then
		local key = self.generationPreset:sub(self.generationIndex, self.generationIndex)
		local keyData = self.generationKeys[key]
		-- Generate the color.
		local color = keyData.color
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
		-- Generate the chain level.
		local chainLevel = 0
		if keyData.chainChances then
			for i, chance in ipairs(keyData.chainChances) do
				if math.random() < chance then
					chainLevel = i
					break
				end
			end
		end
		self.generationIndex = self.generationIndex + 1
		return {color = color, chainLevel = chainLevel}
	end
	-- This shouldn't happen.
	error(string.format("Invalid train rule type: %s", rules.type))
end

function SphereChain:generateSphere()
	-- Add a new sphere.
	local data = self:newSphereData()
	self:getLastSphereGroup():pushSphereBack(data.color, data.chainLevel)
end

function SphereChain:concludeGeneration()
	-- Spawns a vise. Now eliminating a chain via removing all spheres contained is allowed.
	local group = self:getLastSphereGroup()

	-- Spawn a vise.
	if not self.config.noScarabs then
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

---Draws the Sphere Chain on the screen.
function SphereChain:draw()
	--love.graphics.print(self:getDebugText(), 10, 10)
	for i, sphereGroup in ipairs(self.sphereGroups) do
		sphereGroup:draw()
	end
	--local x, y = self.path:getPos(self.sphereGroups[1]:getLastSphereOffset())
	--love.graphics.circle("fill", x, y, 8)
	--love.graphics.setColor(0, 0, 0)
	--love.graphics.print(self:getDebugText(), 40, 40 + self.path:getSphereChainID(self) * 100)
end

---Returns the ID of the provided Sphere Group in this Sphere Chain, or `nil` if it's not here.
---@param sphereGroup SphereGroup The sphere group to be looked after.
---@return integer?
function SphereChain:getSphereGroupID(sphereGroup)
	return _Utils.iTableGetValueIndex(self.sphereGroups, sphereGroup)
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

---Returns whether any portion of this Sphere Chain is in its path's danger area.
---@return boolean
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
		cascade = self.cascade,
		cascadeScore = self.cascadeScore,
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
	self.cascade = t.cascade
	self.cascadeScore = t.cascadeScore
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
