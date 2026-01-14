local class = require "com.class"
local Path = require("src.Game.Path")

---Represents a Map, which houses Paths. In the future, this may extend to particle effects, other visuals and other things which affect spheres like reflectors.
---@class Map
---@overload fun(level, path, pathsBehavior, isDummy):Map
local Map = class:derive("Map")

---Constructs a new Map.
---@param level Level The level which is tied to this Map.
---@param path string Path to the Map's folder.
---@param pathsBehavior table A table of Path Behaviors.
---@param isDummy boolean Whether this Map corresponds to a Dummy Level.
function Map:new(level, path, pathsBehavior, isDummy)
	self.level = level
	self.isDummy = isDummy -- Whether it's just a decorative map. If `false`, then it's meant to be playable.

	_Res:setBatches({"map"})
	self.config = _Res:getMapConfig(path .. "/config.json")
	_Res:setBatches()

	---@type Path[]
	self.paths = {}
	for i, pathData in ipairs(self.config.paths) do
		-- Loop around the path behavior list if not sufficient enough.
		-- Useful if all paths should share the same behavior; you don't have to clone it.
		local pathBehavior = pathsBehavior[(i - 1) % #pathsBehavior + 1]
		table.insert(self.paths, Path(self, pathData, pathBehavior))
	end
	---@type ParticlePacket[]
	self.particles = {}
	for i, object in ipairs(self.config.objects) do
		if object.type == "particle" then
			table.insert(self.particles, _Game:spawnParticle(object.particle, object.x, object.y, object.layer))
		end
	end
end

---Updates this Map.
---@param dt number Delta time in seconds.
function Map:update(dt)
	for i, path in ipairs(self.paths) do
		path:update(dt)
	end
end

---Spawns danger particles configured for this map for all paths which are currently in danger.
function Map:spawnDangerParticles()
	for i, path in ipairs(self.paths) do
		if path:isInDanger() then
			path:spawnDangerParticles()
		end
	end
end

---Returns the ID of a given Path, or `nil` if not found.
---@param path Path The Path of which ID is to be obtained.
---@return integer?
function Map:getPathID(path)
	return _Utils.iTableGetValueIndex(self.paths, path)
end

---Draws this Map.
function Map:draw()
	-- Draw sprites.
	for i, object in ipairs(self.config.objects) do
		if object.type == "sprite" then
			_Renderer:setLayer(object.layer)
			object.sprite:draw(object.x, object.y)
		end
	end

	-- Draw paths.
	for i, path in ipairs(self.paths) do
		path:draw()
	end
end

---Unloads resources loaded by this map.
function Map:destroy()
	-- Destroy the particles.
	for i, particle in ipairs(self.particles) do
		particle:destroy()
		particle:clean()
	end
	for i, path in ipairs(self.paths) do
		path:destroy()
	end
	_Res:unloadResourceBatch("map")
end

---Serializes the Map's data to be saved.
---@return table
function Map:serialize()
	local t = {}
	for i, path in ipairs(self.paths) do
		table.insert(t, path:serialize())
	end
	return t
end

---Deserializes the Map's data.
---@param t table The data to be loaded.
function Map:deserialize(t)
	for i, path in ipairs(t) do
		self.paths[i]:deserialize(path)
	end
end

return Map
