local class = require "com.class"

---Represents a Map, which houses Paths. In the future, this may extend to particle effects, other visuals and other things which affect spheres like reflectors.
---@class Map
---@overload fun(level, path, pathsBehavior, isDummy):Map
local Map = class:derive("Map")

local Vec2 = require("src.Essentials.Vector2")
local Sprite = require("src.Essentials.Sprite")

local Path = require("src.Path")



---Constructs a new Map.
---@param level Level The level which is tied to this Map.
---@param path string Path to the Map's folder.
---@param pathsBehavior table A table of Path Behaviors.
---@param isDummy boolean Whether this Map corresponds to a Dummy Level.
function Map:new(level, path, pathsBehavior, isDummy)
	self.level = level
	-- whether it's just a decorative map, if false then it's meant to be playable
	self.isDummy = isDummy

	self.paths = {}
	self.sprites = {}

	local data = _Utils.loadJson(_ParsePath(path .. "/config.json"))
	self.name = data.name
	for i, spriteData in ipairs(data.sprites) do
		local spritePath = spriteData.path
		if spriteData.internal then
			spritePath = path .. "/" .. spritePath
		end
		table.insert(self.sprites, {pos = Vec2(spriteData.x, spriteData.y), sprite = Sprite(_ParsePath(spritePath)), background = spriteData.background})
	end
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



---Returns the ID of a given Path, or `nil` if not found.
---@param path Path The Path of which ID is to be obtained.
---@return integer|nil
function Map:getPathID(path)
	for i, pathT in ipairs(self.paths) do
		if pathT == path then
			return i
		end
	end
end



---Draws this Map.
function Map:draw()
	-- Background
	for i, sprite in ipairs(self.sprites) do
		if sprite.background then
			sprite.sprite:draw(sprite.pos)
		end
	end

	-- Objects drawn before hidden spheres (background cheat mode)
	if _Debug.e then
		for i, sprite in ipairs(self.sprites) do
			if not sprite.background then
				sprite.sprite:draw(sprite.pos)
			end
		end
	end

	-- Draw hidden spheres and other hidden path stuff
	for x = 1, 2 do
		for i, path in ipairs(self.paths) do
			for sphereID, sphere in pairs(_Game.configManager.spheres) do
				path:drawSpheres(sphereID, true, x == 1)
			end
			path:draw(true)
		end
	end

	-- Objects that will be drown when the BCM is off
	if not _Debug.e then
		for i, sprite in ipairs(self.sprites) do
			if not sprite.background then
				sprite.sprite:draw(sprite.pos)
			end
		end
	end
end



---Draws spheres on this map.
function Map:drawSpheres()
	for x = 1, 2 do
		for i, path in ipairs(self.paths) do
			for sphereID, sphere in pairs(_Game.configManager.spheres) do
				path:drawSpheres(sphereID, false, x == 1)
			end
			path:draw(false)
		end
	end
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
