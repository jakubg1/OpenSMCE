local class = require "com/class"
local ColorManager = class:derive("ColorManager")

-- Counts spheres on the board
function ColorManager:new()
	self.sphereColorCounts = {}
	self.lastSphereColor = 1

	self:reset()
end



-- Resets the onboard color counters back to 0.
function ColorManager:reset()
	for i, sphere in pairs(_Game.configManager.spheres) do
		self.sphereColorCounts[i] = {
			normal = 0,
			danger = 0
		}
	end
end

-- Increments the given color counter by one.
function ColorManager:increment(color, danger)
	if danger then
		self.sphereColorCounts[color].danger = self.sphereColorCounts[color].danger + 1
	else
		self.sphereColorCounts[color].normal = self.sphereColorCounts[color].normal + 1
	end
end

-- Decrements the given color counter by one.
function ColorManager:decrement(color, danger)
	if danger then
		self.sphereColorCounts[color].danger = self.sphereColorCounts[color].danger - 1
	else
		self.sphereColorCounts[color].normal = self.sphereColorCounts[color].normal - 1
	end
	self.lastSphereColor = color
end



function ColorManager:isColorExistent(color)
	return self.sphereColorCounts[color].normal > 0
end



function ColorManager:getDebugText()
	local s = ""

	for i, v in pairs(self.sphereColorCounts) do
		s = s .. string.format("%s:   N %s   D %s\n", i, v.normal, v.danger)
	end

	return s
end



return ColorManager
