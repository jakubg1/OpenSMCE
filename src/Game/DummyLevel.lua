local class = require "com.class"
local Map = require("src.Game.Map")

---A variant of Level which is stripped from nearly all functionality, because it just loads and displays a Map. Used in Luxor's Main Menu.
---@class DummyLevel
---@overload fun(path):DummyLevel
local DummyLevel = class:derive("DummyLevel")

---Constructs an instance of Dummy Level.
---@param path string A path to the level file.
function DummyLevel:new(path)
	local data = _Res:getLevelConfig(path)
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
end

---Activates all particles which are a part of this Dummy Level's Map.
function DummyLevel:activateParticles()
	self.map:activateParticles()
end

---Despawns all particles which are a part of this Dummy Level's Map.
function DummyLevel:deactivateParticles()
	self.map:deactivateParticles()
end

return DummyLevel