local class = require "class"
local Font = class:derive("Font")

local Vec2 = require("Essentials/Vector2")
local Color = require("Essentials/Color")

function Font:new(path)
	print("Loading font from " .. path .. "...")
	self.path = path
	local data = loadJson(path)
	
	self.img = love.graphics.newImage(parsePath(data.image))
	self.size = Vec2(self.img:getDimensions())
	self.characters = {}
	for characterN, character in pairs(data.characters) do
		self.characters[characterN] = {quad = love.graphics.newQuad(character.offset, 0, character.width, self.size.y, self.size.x, self.size.y), width = character.width}
	end
end

function Font:getCharacter(character)
	local c = self.characters[character]
	if c then
		return c
	else
		print("ERROR: No character " .. tostring(character) .. " was found in font " .. self.path)
		return self.characters["0"]
	end
end

function Font:getTextSize(text)
	local size = Vec2(0, self.size.y)
	for i = 1, text:len() do
		local character = text:sub(i, i)
		if character == "\n" then
			size.y = size.y + self.size.y
		else
			size.x = size.x + self:getCharacter(character).width
		end
	end
	return size
end

function Font:draw(text, pos, align, color, alpha)
	align = align or Vec2(0.5)
	color = color or Color()
	alpha = alpha or 1
	love.graphics.setColor(color.r, color.g, color.b, alpha)
	
	local y = pos.y - self:getTextSize(text).y * align.y
	local line = ""
	for i = 1, text:len() do
		local character = text:sub(i, i)
		if character == "\n" then
			self:drawLine(line, Vec2(pos.x, y), align.x)
			line = ""
			y = y + self.size.y
		else
			line = line .. character
		end
	end
	self:drawLine(line, Vec2(pos.x, y), align.x)
end

function Font:drawLine(text, pos, align)
	pos.x = pos.x - self:getTextSize(text).x * align
	for i = 1, text:len() do
		local character = text:sub(i, i)
		self:drawCharacter(character, pos)
		pos.x = pos.x + self:getCharacter(character).width
	end
end

function Font:drawCharacter(character, pos)
	pos = posOnScreen(pos)
	--if self.characters[character] then
	love.graphics.draw(self.img, self:getCharacter(character).quad, pos.x, pos.y, 0, getResolutionScale())
	--else
	--	print("ERROR: Unexpected character: " .. character)
	--end
end

return Font