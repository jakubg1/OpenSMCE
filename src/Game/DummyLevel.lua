local class = require "com.class"

---A variant of Level which is stripped from nearly all functionality, because it just loads and displays a Map. Used in Luxor's Main Menu.
---@class DummyLevel
---@overload fun(path):DummyLevel
local DummyLevel = class:derive("DummyLevel")

local Map = require("src.Game.Map")



---Constructs an instance of Dummy Level.
---@param path string A path to the level file.
function DummyLevel:new(path)
	-- data specified in level config file
	local data = assert(_Utils.loadJson(_ParsePath(path)), "Failed to load dummy level file: " .. path)
	self.map = Map(self, "maps/" .. data.map, data.pathsBehavior, true)
end



---Updates the Dummy Level.
---@param dt number The delta time in seconds.
function DummyLevel:update(dt)
	self.map:update(dt)
end



---Draws the Dummy Level.
function DummyLevel:draw()
	self.map:draw()
	self.map:drawSpheres()
end



return DummyLevel