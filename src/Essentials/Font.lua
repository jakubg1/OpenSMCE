local class = require "com.class"

---@class Font
---@overload fun(data, path):Font
local Font = class:derive("Font")

local Color = require("src.Essentials.Color")

---Constructs a new Font.
---@param config FontConfig The Config of this Font.
---@param path string A path to the font file.
function Font:new(config, path)
	self.path = path

	self.type = config.type

	if self.type == "image" then
		self.image = config.image
		self.height = self.image.size.y
		self.newlineAdjustment = config.newlineAdjustment
		---@alias CharacterData {quad: love.Quad, width: integer}
		---@type table<string, CharacterData>
		self.characters = {}
		for characterN, character in pairs(config.characters) do
			self.characters[characterN] = {
				quad = love.graphics.newQuad(character.offset, 0, character.width, self.image.size.y, self.image.size.x, self.image.size.y),
				width = character.width
			}
		end
		---@type table<string, boolean?>
		self.reportedCharacters = {}
	elseif self.type == "truetype" then
		self.font = config.file:makeFont(config.size)
		self.color = config.color or Color()
	elseif self.type == "bmfont" then
		self.font = love.graphics.newFont(_ParsePath(config.file))
		self.color = config.color or Color()
	end
end

---Returns size of the provided text written in this font.
---@param text string The text of which the size is going to be calculated.
---@return number, number
function Font:getTextSize(text)
	if self.type == "image" then
		local sizeX, sizeY = 0, self.height
		local lineWidth = 0
		for i = 1, text:len() do
			local character = text:sub(i, i)
			if character == "\n" then
				sizeX = math.max(sizeX, lineWidth)
				lineWidth = 0
				sizeY = sizeY + self.height
			else
				lineWidth = lineWidth + self:getCharacterData(character).width
			end
		end
		sizeX = math.max(sizeX, lineWidth)
		return sizeX, sizeY
	else
		local sizeX, sizeY = self.font:getWidth(text), self.font:getHeight()
		for i = 1, text:len() do
			local character = text:sub(i, i)
			if character == "\n" then
				sizeY = sizeY + self.font:getHeight()
			end
		end
		return sizeX, sizeY
	end
	error(string.format("%s: Incorrect Font type: %s", self.path, self.type))
end

---Draws text with this Font on the screen.
---@param text string The text to be drawn. Colored texts are not supported.
---@param x number The X coordinate on which the text should be drawn.
---@param y number The Y coordinate on which the text should be drawn.
---@param alignX number? Horizontal alignment of the text. `0` is left, `1` is right. Defaults to center `0.5`.
---@param alignY number? Vertical alignment of the text. `0` is top, `1` is bottom. Defaults to center `0.5`.
---@param color Color? The color to draw this text in, white by default.
---@param alpha number? Opacity of the text, fully opaque `1` by default.
function Font:draw(text, x, y, alignX, alignY, color, alpha)
	alignX, alignY = alignX or 0.5, alignY or 0.5
	color = color or Color()
	alpha = alpha or 1

	local sizeX, sizeY = self:getTextSize(text)
	if self.type == "image" then
		love.graphics.setColor(color.r, color.g, color.b, alpha)

		y = y - sizeY * alignY
		local line = ""
		for i = 1, text:len() do
			local character = text:sub(i, i)
			if character == "\n" then
				self:drawLine(line, x, y, alignX)
				line = ""
				y = y + self.height + self.newlineAdjustment
			else
				line = line .. character
			end
		end
		self:drawLine(line, x, y, alignX)
	else
		local oldFont = love.graphics.getFont()

		love.graphics.setColor(color.r * self.color.r, color.g * self.color.g, color.b * self.color.b, alpha)
		love.graphics.setFont(self.font)
		local px, py = x - sizeX * alignX, y - sizeY * alignY
		love.graphics.print(text, px, py)

		love.graphics.setFont(oldFont)
	end
end

---Draws a single line of text. Internally used for `image` type fonts.
---@private
---@param text string A single line of text. Must not contain `\n` characters.
---@param x number The X coordinate on which the line should be drawn.
---@param y number The Y coordinate on which the line should be drawn.
---@param align number The horizontal alignment of the line, `0` to left, `1` to right.
function Font:drawLine(text, x, y, align)
	local sizeX, sizeY = self:getTextSize(text)
	x = x - sizeX * align
	for i = 1, text:len() do
		local char = text:sub(i, i)
		local charData = self:getCharacterData(char)
		self.image:draw(charData.quad, math.floor(x), math.floor(y))
		x = x + charData.width
	end
end

---Returns data for the provided character.
---If the character is not found in the font, it is reported to the console and data for the character `0` is returned instead.
---Usable only for `image` type fonts.
---@private
---@param character string A single character.
---@return CharacterData
function Font:getCharacterData(character)
	local b = character:byte()
	local c = self.characters[character]
	if c then
		return c
	elseif b >= 97 and b <= 122 then
		-- if lowercase character does not exist, we try again with an uppercase character
		return self:getCharacterData(string.char(b - 32))
	else
		-- report only once
		if not self.reportedCharacters[character] then
			_Log:printt("Font", "ERROR: No character " .. tostring(character) .. " was found in font " .. self.path)
			self.reportedCharacters[character] = true
		end
		return self.characters["0"]
	end
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function Font.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a Font by a given path.
    ---@param path string The resource path.
    ---@return Font
    function ResourceManager:getFont(path)
        return self:getResourceAsset(path, "Font")
    end
end

return Font
