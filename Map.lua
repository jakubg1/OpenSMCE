local class = require "class"
local Map = class:derive("Map")

local Vec2 = require("Essentials/Vector2")
local List1 = require("Essentials/List1")
local Image = require("Essentials/Image")

local Path = require("Path")

function Map:new(path)
	self.paths = List1()
	self.images = List1()
	
	local data = loadJson(parsePath(path .. "/config.json"))
	self.name = data.name
	for i, imageData in ipairs(data.images) do
		local imageGlobal = imageData.path:sub(1, 1) == "/"
		local imagePath = imageGlobal and imageData.path:sub(2, -1) or (path .. "/" .. imageData.path)
		self.images:append({pos = Vec2(imageData.x, imageData.y), image = Image(parsePath(imagePath)), background = imageData.background})
	end
	for i, pathData in ipairs(data.paths) do
		self.paths:append(Path(self, pathData, false))
	end
end

function Map:update(dt)
	self.paths:iterate(function(i, o) o:update(dt) end)
end



function Map:draw()
	self.images:iterate(function(i, o)
		if o.background then o.image:draw(o.pos) end
	end)
	if e then
		self.images:iterate(function(i, o)
			if not o.background then o.image:draw(o.pos) end
		end)
	end
	self.paths:iterate(function(i, o)
		o:draw(true)
	end)
	if not e then
		self.images:iterate(function(i, o)
			if not o.background then o.image:draw(o.pos) end
		end)
	end
	
	--for i, image in ipairs(self.images) do if image.background then image.image:draw(image.pos) end end
	--if e then for i, image in ipairs(self.images) do if not image.background then image.image:draw(image.pos) end end end
	--for i, path in pairs(self.paths) do path:draw(true) end
	--if not e then for i, image in ipairs(self.images) do if not image.background then image.image:draw(image.pos) end end end
end

function Map:drawSpheres()
	self.paths:iterate(function(i, o)
		o:draw(false)
	end)
	
	--for i, path in pairs(self.paths) do path:draw(false) end
end



function Map:serialize()
	local t = {}
	self.paths:iterate(function(i, o)
		table.insert(t, o:serialize())
	end)
	return t
end

return Map