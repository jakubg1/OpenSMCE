local class = require "com.class"

---Counts spheres on the board.
---@class ColorManager
---@overload fun():ColorManager
local ColorManager = class:derive("ColorManager")



---Constructs a new ColorManager.
function ColorManager:new()
	self.sphereColorCounts = {}
	self.dangerColorCounts = {}
end



---Resets the onboard color counters back to 0.
function ColorManager:reset()
	self.sphereColorCounts = {}
	self.dangerColorCounts = {}
end



---Increments the given color counter by one.
---@param color integer The color ID of which counter is to be incremented.
---@param danger boolean? Whether we are changing the danger zone counter.
function ColorManager:increment(color, danger)
	if danger then
		self.dangerColorCounts[color] = (self.dangerColorCounts[color] or 0) + 1
	else
		self.sphereColorCounts[color] = (self.sphereColorCounts[color] or 0) + 1
	end
end



---Decrements the given color counter by one.
---@param color integer The color ID of which counter is to be decremented.
---@param danger boolean? Whether we are changing the danger zone counter.
function ColorManager:decrement(color, danger)
	if danger then
		self.dangerColorCounts[color] = self.dangerColorCounts[color] - 1
		if self.dangerColorCounts[color] == 0 then
			self.dangerColorCounts[color] = nil
		end
	else
		self.sphereColorCounts[color] = self.sphereColorCounts[color] - 1
		if self.sphereColorCounts[color] == 0 then
			self.sphereColorCounts[color] = nil
		end
	end
end



---Returns `true` if at least one sphere of a given color exists on the board.
---@param color integer The color ID to be checked against.
---@return boolean
function ColorManager:isColorExistent(color)
	return self.sphereColorCounts[color] ~= nil
end



---Returns the total number of spheres of a given color on the board.
---@param color integer The color ID to be checked against.
---@return integer
function ColorManager:getColorCount(color)
	return self.sphereColorCounts[color] or 0
end



---Returns the total number of spheres on the board.
---Excludes scarabs.
---@return integer
function ColorManager:getTotalSphereCount()
	local amount = 0
	for i, v in pairs(self.sphereColorCounts) do
		if i ~= 0 then
			amount = amount + v
		end
	end
	return amount
end



---Sets the Expression Variables in the `color` context.
--- - `color.#` - For each registered sphere color (`#`), the amount of spheres of that color currently on the board.
--- - `color.totalSpheres` - The total amount of spheres on the board, excluding scarabs.
--- - `color.mostFrequent` - The most frequently appearing color on the board, excluding the scarab (ID = 0). If there's a tie, selects a random color from this tie.
function ColorManager:dumpVariables()
	_Vars:unset("color")
	for i, v in pairs(self.sphereColorCounts) do
		_Vars:set("color." .. i, v)
	end
	_Vars:set("color.totalSpheres", self:getTotalSphereCount())
end



---Returns a debug text used by the debug screen.
---@return string
function ColorManager:getDebugText()
	local s = ""

	for i, v in pairs(self.sphereColorCounts) do
		s = s .. string.format("%s:   N %s   D %s\n", i, v, self.dangerColorCounts[i] or 0)
	end
	-- No color should ever be only in the danger counter.

	return s
end



return ColorManager
