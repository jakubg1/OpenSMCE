local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")

---@class UIWidgetRectangle
---@overload fun(parent, size, color):UIWidgetRectangle
local UIWidgetRectangle = class:derive("UIWidgetRectangle")

function UIWidgetRectangle:new(parent, size, color)
	self.type = "rectangle"
	self.parent = parent
	self.size = Vec2(size.x, size.y)
	self.color = color
	self.debugColor = {1.0, 1.0, 0.0}
end

function UIWidgetRectangle:draw()
	local x, y = self.parent:getPos()
	_Renderer:setLayer(self.parent.layer)
	_Renderer:setColor(self.color, self.parent:getAlpha())
	_Renderer:drawRectangle("fill", x, y, self.size.x, self.size.y)
end

function UIWidgetRectangle:getSize()
	return self.size
end

return UIWidgetRectangle