local class = require "com/class"

---Counts spheres on the board.
---@class ColorManager
---@overload fun():ColorManager
local ColorManager = class:derive("ColorManager")



---Constructs a new ColorManager.
function ColorManager:new()
	self.sphereColorCounts = {}
	self.lastSphereColor = 1

	self:reset()
end



---Resets the onboard color counters back to 0.
function ColorManager:reset()
	for i, sphere in pairs(_Game.configManager.spheres) do
		self.sphereColorCounts[i] = {
			normal = 0,
			danger = 0
		}
	end
end



---Increments the given color counter by one.
---@param color integer The color ID of which counter is to be incremented.
---@param danger boolean? Whether we are changing the danger zone counter.
function ColorManager:increment(color, danger)
	if danger then
		self.sphereColorCounts[color].danger = self.sphereColorCounts[color].danger + 1
	else
		self.sphereColorCounts[color].normal = self.sphereColorCounts[color].normal + 1
	end
end



---Decrements the given color counter by one.
---@param color integer The color ID of which counter is to be decremented.
---@param danger boolean? Whether we are changing the danger zone counter.
function ColorManager:decrement(color, danger)
	if danger then
		self.sphereColorCounts[color].danger = self.sphereColorCounts[color].danger - 1
	else
		self.sphereColorCounts[color].normal = self.sphereColorCounts[color].normal - 1
	end
	self.lastSphereColor = color
end



---Returns `true` if at least one sphere of a given color exists on the board.
---@param color integer The color ID to be checked against.
---@return boolean
function ColorManager:isColorExistent(color)
	return self.sphereColorCounts[color].normal > 0
end



---Returns a debug text used by the debug screen.
---@return string
function ColorManager:getDebugText()
	local s = ""

	for i, v in pairs(self.sphereColorCounts) do
		if v.normal ~= 0 or v.danger ~= 0 then
			s = s .. string.format("%s:   N %s   D %s\n", i, v.normal, v.danger)
		end
	end

	return s
end



return ColorManager
