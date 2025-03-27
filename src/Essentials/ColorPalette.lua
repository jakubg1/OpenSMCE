local class = require "com.class"

---@class ColorPalette
---@overload fun(data, path):ColorPalette
local ColorPalette = class:derive("ColorPalette")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")



function ColorPalette:new(data, path)
	self.path = path

	self.image = _Utils.loadImageData(_ParsePath(data.image))
	if not self.image then
		error("Failed to load image data: " .. data.image .. " from " .. path)
	end
	self.size = Vec2(self.image:getDimensions())
end

function ColorPalette:getColor(t)
	return Color(self.image:getPixel(t % self.size.x, 1))
end

return ColorPalette