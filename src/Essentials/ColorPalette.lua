local class = require "com/class"

---@class ColorPalette
---@overload fun(path):ColorPalette
local ColorPalette = class:derive("ColorPalette")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")



function ColorPalette:new(path)
	self.data = _LoadImageData(path)
	if not self.data then error("Failed to load image data: " .. path) end
---@diagnostic disable-next-line: undefined-field
	self.size = Vec2(self.data:getDimensions())
end

function ColorPalette:getColor(t)
---@diagnostic disable-next-line: undefined-field
	return Color(self.data:getPixel(t % self.size.x, 1))
end

return ColorPalette