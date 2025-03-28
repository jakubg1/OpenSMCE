local class = require "com.class"

---@class UIWidgetRectangle
---@overload fun(parent, size, color):UIWidgetRectangle
local UIWidgetRectangle = class:derive("UIWidgetRectangle")



function UIWidgetRectangle:new(parent, size, color)
	self.type = "rectangle"
	
	self.parent = parent
	
	self.size = _ParseVec2(size)
	self.color = _ParseColor(color)
	self.debugColor = {1.0, 1.0, 0.0}
end



function UIWidgetRectangle:draw()
	love.graphics.setColor(self.color.r, self.color.g, self.color.b, self.parent:getAlpha())
	local pos = self.parent:getPos()
	love.graphics.rectangle("fill", pos.x, pos.y, self.size.x, self.size.y)
end

function UIWidgetRectangle:getSize()
	return self.size
end

return UIWidgetRectangle