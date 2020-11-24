local class = require "com/class"
local UIWidgetRectangle = class:derive("UIWidgetRectangle")

function UIWidgetRectangle:new(parent, size, color)
	self.type = "rectangle"
	
	self.parent = parent
	
	self.size = parseVec2(size)
	self.color = parseColor(color)
end



function UIWidgetRectangle:draw()
	love.graphics.setColor(self.color.r, self.color.g, self.color.b, self.parent:getAlpha())
	local pos = posOnScreen(self.parent:getPos())
	local size = self.size * getResolutionScale()
	love.graphics.rectangle("fill", pos.x, pos.y, size.x, size.y)
end

return UIWidgetRectangle