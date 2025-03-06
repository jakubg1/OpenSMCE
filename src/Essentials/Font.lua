local class = require "com.class"

---@class Font
---@overload fun(data, path):Font
local Font = class:derive("Font")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")



function Font:new(data, path)
	self.path = path

	self.type = data.type

	if self.type == "image" then
		self.image = _Game.resourceManager:getImage(data.image)
		self.height = self.image.size.y
		self.newlineAdjustment = data.newlineAdjustment or 0
		self.characters = {}
		for characterN, character in pairs(data.characters) do
			self.characters[characterN] = {
				quad = love.graphics.newQuad(character.offset, 0, character.width, self.image.size.y, self.image.size.x, self.image.size.y),
				width = character.width
			}
		end

		self.reportedCharacters = {}
	elseif self.type == "truetype" then
		self.font = _Utils.loadFont(_ParsePath(data.path), data.size)
		self.color = _ParseColor(data.color)
	end
end

-- Image type only
function Font:getCharacter(character)
	local b = character:byte()
	local c = self.characters[character]
	if c then
		return c
	elseif b >= 97 and b <= 122 then
		-- if lowercase character does not exist, we try again with an uppercase character
		return self:getCharacter(string.char(b - 32))
	else
		-- report only once
		if not self.reportedCharacters[character] then
			_Log:printt("Font", "ERROR: No character " .. tostring(character) .. " was found in font " .. self.path)
			self.reportedCharacters[character] = true
		end
		return self.characters["0"]
	end
end

function Font:getTextSize(text)
	if self.type == "image" then
		local size = Vec2(0, self.height)
		local lineWidth = 0
		for i = 1, text:len() do
			local character = text:sub(i, i)
			if character == "\n" then
				size.x = math.max(size.x, lineWidth)
				lineWidth = 0
				size.y = size.y + self.height
			else
				lineWidth = lineWidth + self:getCharacter(character).width
			end
		end
		size.x = math.max(size.x, lineWidth)
		return size
	elseif self.type == "truetype" then
		local size = Vec2(self.font:getWidth(text), self.font:getHeight())
		for i = 1, text:len() do
			local character = text:sub(i, i)
			if character == "\n" then
				size.y = size.y + self.font:getHeight()
			end
		end
		return size
	end
end

function Font:draw(text, pos, align, color, alpha)
	align = align or Vec2(0.5)
	color = color or Color()
	alpha = alpha or 1

	if self.type == "image" then
		love.graphics.setColor(color.r, color.g, color.b, alpha)

		local y = pos.y - self:getTextSize(text).y * align.y
		local line = ""
		for i = 1, text:len() do
			local character = text:sub(i, i)
			if character == "\n" then
				self:drawLine(line, Vec2(pos.x, y), align.x)
				line = ""
				y = y + self.height + self.newlineAdjustment
			else
				line = line .. character
			end
		end
		self:drawLine(line, Vec2(pos.x, y), align.x)
	elseif self.type == "truetype" then
		local oldFont = love.graphics.getFont()

		love.graphics.setColor(color.r * self.color.r, color.g * self.color.g, color.b * self.color.b, alpha)
		love.graphics.setFont(self.font)
		local p = pos - self:getTextSize(text) * align
		love.graphics.print(text, p.x, p.y)

		love.graphics.setFont(oldFont)
	end
end

-- Image type only
function Font:drawLine(text, pos, align)
	pos.x = pos.x - self:getTextSize(text).x * align
	for i = 1, text:len() do
		local character = text:sub(i, i)
		self:drawCharacter(character, pos)
		pos.x = pos.x + self:getCharacter(character).width
	end
end

-- Image type only
function Font:drawCharacter(character, pos)
	self.image:draw(self:getCharacter(character).quad, math.floor(pos.x), math.floor(pos.y))
end

return Font
