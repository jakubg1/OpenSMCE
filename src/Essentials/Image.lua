local class = require "com.class"

---@class Image
---@overload fun(path):Image
local Image = class:derive("Image")

local Vec2 = require("src.Essentials.Vector2")



function Image:new(path)
	self.img = _Utils.loadImage(path)
	if not self.img then error("Failed to load image: " .. path) end
	self.size = Vec2(self.img:getDimensions())
end

function Image:draw(...)
	love.graphics.draw(self.img, ...)
end

return Image
