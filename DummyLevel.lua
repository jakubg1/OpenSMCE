local class = require "class"
local DummyLevel = class:derive("DummyLevel")

local Map = require("Map")

function DummyLevel:new(path)
	-- data specified in level config file
	local data = loadJson(parsePath(path))
	
	self.map = Map(self, "maps/" .. data.map, true)
	
	self.colors = data.colors
	self.colorStreak = data.colorStreak
	self.powerups = data.powerups
	self.gemColors = data.gems
	self.target = data.target
	self.spawnAmount = data.spawnAmount
	self.spawnDistance = data.spawnDistance
	self.speeds = data.speeds
end

function DummyLevel:update(dt)
	self.map:update(dt)
end

function DummyLevel:newSphereColor()
	return self.colors[math.random(1, #self.colors)]
end

function DummyLevel:getMaxDistance()
	local distance = 0
	for i, path in ipairs(self.map.paths.objects) do
		distance = math.max(distance, path:getMaxOffset() / path.length)
	end
	return distance
end



function DummyLevel:draw()
	self.map:draw()
	self.map:drawSpheres()
end



return DummyLevel