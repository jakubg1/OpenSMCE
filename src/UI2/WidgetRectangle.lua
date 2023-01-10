local class = require "com/class"

---@class UI2WidgetRectangle
---@overload fun(node, align, size, color):UI2WidgetRectangle
local UI2WidgetRectangle = class:derive("UI2WidgetRectangle")



---Constructs a new Rectangle Widget.
---@param node UI2Node The Node this Widget is bound to.
---@param align Vector2 The Widget's alignment.
---@param size Vector2 This Rectangle's size.
---@param color Color This Rectangle's color.
function UI2WidgetRectangle:new(node, align, size, color)
	self.type = "rectangle"

	self.node = node

	self.align = align
	self.size = size
	self.color = color
end



---Returns the current Widget's position.
---@return Vector2
function UI2WidgetRectangle:getPos()
	return self.node:getGlobalPos() - self:getSize() * self.align
end

---Returns the current Widget's size.
---@return Vector2
function UI2WidgetRectangle:getSize()
	return self.size * self.node:getGlobalScale()
end



---Draws this Widget on the screen.
function UI2WidgetRectangle:draw()
	love.graphics.setColor(self.color.r, self.color.g, self.color.b, self.node:getGlobalAlpha())
	local pos = _PosOnScreen(self:getPos())
	local size = self:getSize() * _GetResolutionScale()
	love.graphics.rectangle("fill", pos.x, pos.y, size.x, size.y)
end



return UI2WidgetRectangle