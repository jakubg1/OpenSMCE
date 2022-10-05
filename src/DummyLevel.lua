local class = require "com/class"

---@class DummyLevel
---@overload fun(path):DummyLevel
local DummyLevel = class:derive("DummyLevel")

local Map = require("src/Map")



---Constructs an instance of Dummy Level.
---@param path string A path to the level file.
function DummyLevel:new(path)
	-- data specified in level config file
	local data = _LoadJson(_ParsePath(path))
	
	self.map = Map(self, "maps/" .. data.map, data.pathsBehavior, true)
end



---Updates the Dummy Level.
---@param dt number The delta time in seconds.
function DummyLevel:update(dt)
	self.map:update(dt)
end



---Generates a new sphere color.
---@return integer
function DummyLevel:newSphereColor()
	return self.colors[math.random(1, #self.colors)]
end



---Returns the maximum percentage distance which is occupied by spheres on all paths.
---@return number
function DummyLevel:getMaxDistance()
	local distance = 0
	for i, path in ipairs(self.map.paths.objects) do
		distance = math.max(distance, path:getMaxOffset() / path.length)
	end
	return distance
end



---Draws the Dummy Level.
function DummyLevel:draw()
	self.map:draw()
	self.map:drawSpheres()
end



return DummyLevel