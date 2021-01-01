local class = require "com/class"
local ColorPalette = class:derive("ColorPalette")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")

function ColorPalette:new(path)
	self.data = loadImageData(path)
	if not self.data then error("Failed to load image data: " .. path) end
	self.size = Vec2(self.data:getDimensions())
end

function ColorPalette:getColor(t)
	return Color(self.data:getPixel((t % 1) * self.size.x, 1))
end

return ColorPalette