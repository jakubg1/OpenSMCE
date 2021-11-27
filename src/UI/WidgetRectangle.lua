local class = require "com/class"
local UIWidgetRectangle = class:derive("UIWidgetRectangle")

function UIWidgetRectangle:new(parent, size, color)
	self.type = "rectangle"
	
	self.parent = parent
	
	self.size = _ParseVec2(size)
	self.color = _ParseColor(color)
end



function UIWidgetRectangle:draw()
	love.graphics.setColor(self.color.r, self.color.g, self.color.b, self.parent:getAlpha())
	local pos = _PosOnScreen(self.parent:getPos())
	local size = self.size * _GetResolutionScale()
	love.graphics.rectangle("fill", pos.x, pos.y, size.x, size.y)
end

return UIWidgetRectangle