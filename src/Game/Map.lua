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
	-- whether it's just a decorative map, if false then it's meant to be playable
	self.isDummy = isDummy

	local mapFolderName = _Utils.strSplit(path, "/")
	_Res:setNamespace(mapFolderName[#mapFolderName])
	_Res:setBatches({"map"})
	self.config = _Res:getMapConfig(path .. "/config.json")
	_Res:setNamespace()
	_Res:setBatches()
	self.name = self.config.name

	---@type Path[]
	self.paths = {}


	for i, pathData in ipairs(self.config.paths) do
		-- Loop around the path behavior list if not sufficient enough.
		-- Useful if all paths should share the same behavior; you don't have to clone it.
		local pathBehavior = pathsBehavior[(i - 1) % #pathsBehavior + 1]
		table.insert(self.paths, Path(self, pathData, pathBehavior))
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
			local x, y = path:getPos(path.length)
			_Game:spawnParticle(path.dangerParticle, x, y)
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
	for i, sprite in ipairs(self.config.sprites) do
		if sprite.background then
			_Display:setLayer("GameBackground")
		elseif sprite.foreground or _Debug.mapDebugVisible then
			_Display:setLayer("GameScores")
		else
			_Display:setLayer("GameBackgroundSprites")
		end
		sprite.sprite:draw(sprite.x, sprite.y)
	end

	-- Draw paths.
	for i, path in ipairs(self.paths) do
		path:draw()
	end

	-- Draw particles for hidden spheres before the map's foreground sprites.
	-- In order to accomplish that, Sphere.lua dispatches four quasi-layers called "(_DUMMY)_SPHERES(_H)".
	-- Particles are drawn directly after the corresponding spheres, and none of the particles are drawn twice,
	-- so we need to separate the layers for them into hidden and non-hidden.
	_Game.particleManager:draw(self.isDummy and "_DUMMY_SPHERES_H" or "_SPHERES_H")
	_Game.particleManager:draw(self.isDummy and "_DUMMY_SPHERES" or "_SPHERES")
end

---Unloads resources loaded by this map.
function Map:destroy()
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
