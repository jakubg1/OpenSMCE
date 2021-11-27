local class = require "com/class"
local Map = class:derive("Map")

local Vec2 = require("src/Essentials/Vector2")
local List1 = require("src/Essentials/List1")
local Sprite = require("src/Essentials/Sprite")

local Path = require("src/Path")

function Map:new(level, path, isDummy)
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
		self.paths:append(Path(self, pathData))
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
	for i, path in ipairs(self.paths.objects) do
		for sphereID, sphere in pairs(_Game.configManager.spheres) do
			path:drawSpheres(sphereID, true)
		end
		path:draw(true)
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
	for i, path in ipairs(self.paths.objects) do
		for sphereID, sphere in pairs(_Game.configManager.spheres) do
			path:drawSpheres(sphereID, false)
		end
		path:draw(false)
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
