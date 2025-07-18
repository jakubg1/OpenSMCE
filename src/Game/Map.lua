local class = require "com.class"

---Represents a Map, which houses Paths. In the future, this may extend to particle effects, other visuals and other things which affect spheres like reflectors.
---@class Map
---@overload fun(level, path, pathsBehavior, isDummy):Map
local Map = class:derive("Map")

local Vec2 = require("src.Essentials.Vector2")
local Path = require("src.Game.Path")

---Constructs a new Map.
---@param level Level The level which is tied to this Map.
---@param path string Path to the Map's folder.
---@param pathsBehavior table A table of Path Behaviors.
---@param isDummy boolean Whether this Map corresponds to a Dummy Level.
function Map:new(level, path, pathsBehavior, isDummy)
	self.level = level
	-- whether it's just a decorative map, if false then it's meant to be playable
	self.isDummy = isDummy

	local data = _Utils.loadJson(_ParsePath(path .. "/config.json"))
	assert(data, string.format("Failed to load map file %s", path))
	self.name = data.name

	self.paths = {}
	self.sprites = {}

	local mapFolderName = _Utils.strSplit(path, "/")
	_Game.resourceManager:setNamespace(mapFolderName[#mapFolderName])
	_Game.resourceManager:setBatches({"map"})
	for i, spriteData in ipairs(data.sprites) do
		local sprite = {
			pos = Vec2(spriteData.x, spriteData.y),
			sprite = _Game.resourceManager:getSprite(spriteData.path),
			background = spriteData.background,
			foreground = spriteData.foreground
		}
		table.insert(self.sprites, sprite)
	end
	_Game.resourceManager:setNamespace()
	_Game.resourceManager:setBatches()

	for i, pathData in ipairs(data.paths) do
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
	-- Background
	for i, sprite in ipairs(self.sprites) do
		if sprite.background then
			sprite.sprite:draw(sprite.pos.x, sprite.pos.y)
		end
	end

	-- Objects drawn before hidden spheres (map debugging)
	if _Debug.mapDebugVisible then
		for i, sprite in ipairs(self.sprites) do
			if not sprite.background and not sprite.foreground then
				sprite.sprite:draw(sprite.pos.x, sprite.pos.y)
			end
		end
	end

	-- Draw hidden spheres and other hidden path stuff
	for x = 1, 2 do
		for i, path in ipairs(self.paths) do
			path:drawSpheres(true, x == 1)
			path:draw(true)
		end
	end

	-- Draw particles for hidden spheres before the map's foreground sprites.
	-- In order to accomplish that, Sphere.lua dispatches four quasi-layers called "(_DUMMY)_SPHERES(_H)".
	-- Particles are drawn directly after the corresponding spheres, and none of the particles are drawn twice,
	-- so we need to separate the layers for them into hidden and non-hidden.
	_Game.particleManager:draw(self.isDummy and "_DUMMY_SPHERES_H" or "_SPHERES_H")

	-- Objects that will be drawn when the map debugging is off (foreground sprites)
	if not _Debug.mapDebugVisible then
		for i, sprite in ipairs(self.sprites) do
			if not sprite.background and not sprite.foreground then
				sprite.sprite:draw(sprite.pos.x, sprite.pos.y)
			end
		end
	end
end

---Draws spheres, their particles, and foreground sprites which appear on this map.
function Map:drawSpheres()
	for x = 1, 2 do
		for i, path in ipairs(self.paths) do
			path:drawSpheres(false, x == 1)
			path:draw(false)
		end
	end

	_Game.particleManager:draw(self.isDummy and "_DUMMY_SPHERES" or "_SPHERES")

	for i, sprite in ipairs(self.sprites) do
		if not sprite.background and sprite.foreground then
			sprite.sprite:draw(sprite.pos.x, sprite.pos.y)
		end
	end
end

---Unloads resources loaded by this map.
function Map:destroy()
	for i, path in ipairs(self.paths) do
		path:destroy()
	end
	_Game.resourceManager:unloadResourceBatch("map")
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
