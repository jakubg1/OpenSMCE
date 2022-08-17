local class = require "com/class"

---@class Map
---@overload fun(level, path, pathsBehavior, isDummy):Map
local Map = class:derive("Map")

local Vec2 = require("src/Essentials/Vector2")
local List1 = require("src/Essentials/List1")
local Sprite = require("src/Essentials/Sprite")

local Path = require("src/Path")



function Map:new(level, path, pathsBehavior, isDummy)
	self.level = level
	-- whether it's just a decorative map, if false then it's meant to be playable
	self.isDummy = isDummy

	self.paths = List1()
	self.sprites = List1()

	local data = _LoadJson(_ParsePath(path .. "/config.json"))
	self.name = data.name
	for i, spriteData in ipairs(data.sprites) do
		local spritePath = spriteData.path
		if spriteData.internal then
			spritePath = path .. "/" .. spritePath
		end
		self.sprites:append({pos = Vec2(spriteData.x, spriteData.y), sprite = Sprite(_ParsePath(spritePath)), background = spriteData.background})
	end
	for i, pathData in ipairs(data.paths) do
		-- Loop around the path behavior list if not sufficient enough.
		-- Useful if all paths should share the same behavior; you don't have to clone it.
		local pathBehavior = pathsBehavior[(i - 1) % #pathsBehavior + 1]
		self.paths:append(Path(self, pathData, pathBehavior))
	end
end

function Map:update(dt)
	for i, path in ipairs(self.paths.objects) do path:update(dt) end
end

function Map:getPathID(path)
	for i, pathT in ipairs(self.paths.objects) do if pathT == path then return i end end
end



function Map:draw()
	-- Background
	for i, sprite in ipairs(self.sprites.objects) do
		if sprite.background then
			sprite.sprite:draw(sprite.pos)
		end
	end

	-- Objects drawn before hidden spheres (background cheat mode)
	if _Debug.e then
		for i, sprite in ipairs(self.sprites.objects) do
			if not sprite.background then
				sprite.sprite:draw(sprite.pos)
			end
		end
	end

	-- Draw hidden spheres and other hidden path stuff
	for x = 1, 2 do
		for i, path in ipairs(self.paths.objects) do
			for sphereID, sphere in pairs(_Game.configManager.spheres) do
				path:drawSpheres(sphereID, true, x == 1)
			end
			path:draw(true)
		end
	end

	-- Objects that will be drown when the BCM is off
	if not _Debug.e then
		for i, sprite in ipairs(self.sprites.objects) do
			if not sprite.background then
				sprite.sprite:draw(sprite.pos)
			end
		end
	end
end

function Map:drawSpheres()
	for x = 1, 2 do
		for i, path in ipairs(self.paths.objects) do
			for sphereID, sphere in pairs(_Game.configManager.spheres) do
				path:drawSpheres(sphereID, false, x == 1)
			end
			path:draw(false)
		end
	end
end



function Map:serialize()
	local t = {}
	self.paths:iterate(function(i, o)
		table.insert(t, o:serialize())
	end)
	return t
end

function Map:deserialize(t)
	for i, path in ipairs(t) do
		self.paths:get(i):deserialize(path)
	end
end

return Map
