local class = require "com/class"
local ColorManager = class:derive("ColorManager")

-- Counts spheres on the board
function ColorManager:new()
	self.sphereColorCounts = {}
	self.dangerSphereColorCounts = {}
	self.lastSphereColor = 1
	
	self:reset()
end



--- Returns a random sphere color that is on the board.
-- If no spheres are on the board, this function returns the last sphere color that appeared on the board.
-- @tparam boolean omitDangerCheck When it is set to true, gets just any random sphere color that is on board provided it is not special (e.g. wild).
-- Setting this to false searches only in colors that are in the danger colors list, and if nothing was found there,
-- it gets a random color from the entire board.
-- @treturn number A sphere color.
function ColorManager:pickColor(omitDangerCheck)
	local availableColors = {}
	if not omitDangerCheck then
		-- check the vises in danger first
		for i, count in ipairs(self.dangerSphereColorCounts) do
			if count > 0 then table.insert(availableColors, i) end
		end
		-- NEW GENERATION MECHANICS
		if #availableColors > 0 then
			-- Pick a random path
			local paths = game.session.level.map.paths
			local path = nil
			while not path or path:getEmpty() or not path:getDanger(path:getMaxOffset()) do
				-- if path empty or not in danger, try again
				path = paths:get(math.random(paths:size()))
			end
			-- Get a SphereChain nearest to the pyramid
			local sphereChain = path.sphereChains[1]
			-- Iterate through all groups and then spheres in each group
			local lastGoodColor = nil
			-- reverse iteration!!!
			for i = #sphereChain.sphereGroups, 1, -1 do
				local sphereGroup = sphereChain.sphereGroups[i]
				for j, sphere in ipairs(sphereGroup.spheres) do
					local color = sphere.color
					-- if this color is generatable, 25% chance to pass the check
					if game.spheres[color].generatable and math.random() < 0.25 then
						return color
					end
					-- else, next sphere comes but if no more further spheres are generatable we will use it anyway
					lastGoodColor = color
				end
			end
			-- no more spheres left, get the last good one
			return lastGoodColor
		end
	end
	for i, count in ipairs(self.sphereColorCounts) do
		if count > 0 then table.insert(availableColors, i) end
	end
	if #availableColors == 0 then return self.lastSphereColor end -- if no spheres present
	return availableColors[math.random(1, #availableColors)]
end



--- Resets the onboard color counters back to 0.
function ColorManager:reset()
	for i, sphere in pairs(game.spheres) do
		if sphere.generatable then
			self.sphereColorCounts[i] = 0
			self.dangerSphereColorCounts[i] = 0
		end
	end
end

--- Increments the given color counter by one.
function ColorManager:increment(color, danger)
	if danger then
		self.dangerSphereColorCounts[color] = self.dangerSphereColorCounts[color] + 1
	else
		self.sphereColorCounts[color] = self.sphereColorCounts[color] + 1
	end
end

--- Decrements the given color counter by one.
function ColorManager:decrement(color, danger)
	if danger then
		self.dangerSphereColorCounts[color] = self.dangerSphereColorCounts[color] - 1
	else
		self.sphereColorCounts[color] = self.sphereColorCounts[color] - 1
		self.lastSphereColor = color
	end
end



function ColorManager:isColorExistent(color)
	if not self.sphereColorCounts[color] then return true end
	return self.sphereColorCounts[color] > 0
end



function ColorManager:getDebugText()
	local s = ""
	
	for i, v in pairs(self.sphereColorCounts) do
		s = s .. string.format("%s:   N %s   D %s\n", i, self.sphereColorCounts[i], self.dangerSphereColorCounts[i])
	end
	
	return s
end



return ColorManager