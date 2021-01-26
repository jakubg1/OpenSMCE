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
	local path = nil
	if not omitDangerCheck then
		-- Pick a random path
		local paths = game.session.level.map.paths
		local pathsPool = {}
		for i = 1, paths:size() do
			table.insert(pathsPool, paths:get(i))
		end
		while not path and #pathsPool > 0 do
			-- pick a random path
			local id = math.random(#pathsPool)
			path = pathsPool[id]
			-- remove it from the list
			table.remove(pathsPool, id)
			-- if it does not meet the requirements, abandon it
			if path:getEmpty() or not path:getDanger(path:getMaxOffset()) then
				path = nil
			end
		end
	end
	-- If a path is in danger and omitDangerCheck is false, then time to draw from it, else, use a standard generation
	if path then
		-- Get a SphereChain nearest to the pyramid
		local sphereChain = path.sphereChains[1]
		-- Iterate through all groups and then spheres in each group
		local lastGoodColor = nil
		-- reverse iteration!!!
		for i, sphereGroup in ipairs(sphereChain.sphereGroups) do
			local sphereGroup = sphereChain.sphereGroups[i]
			for j = #sphereGroup.spheres, 1, -1 do
				local sphere = sphereGroup.spheres[j]
				local color = sphere.color
				-- if this color is generatable, 25% chance to pass the check
				if game.spheres[color].generatable and math.random() < 0.25 then
					return color
				end
				-- else, next sphere comes but if no more further spheres are generatable we will use it anyway
				if game.spheres[color].generatable then
					lastGoodColor = color
				end
			end
		end
		-- no more spheres left, get the last good one if exists
		if lastGoodColor then
			return lastGoodColor
		else
			-- else, use a fallback algorithm
			path = nil
		end
	end
	if not path then
		for i, count in ipairs(self.sphereColorCounts) do
			if count > 0 then table.insert(availableColors, i) end
		end
		if #availableColors == 0 then return self.lastSphereColor end -- if no spheres present
		return availableColors[math.random(1, #availableColors)]
	end
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
	if not self.sphereColorCounts[color] then return end
	if danger then
		self.dangerSphereColorCounts[color] = self.dangerSphereColorCounts[color] + 1
	else
		self.sphereColorCounts[color] = self.sphereColorCounts[color] + 1
	end
end

--- Decrements the given color counter by one.
function ColorManager:decrement(color, danger)
	if not self.sphereColorCounts[color] then return end
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