local class = require "com/class"

---@class UI2WidgetText
---@overload fun(node, align, font, text, color):UI2WidgetText
local UI2WidgetText = class:derive("UI2WidgetText")



---Constructs a new UI2 Text widget.
---@param node UI2Node The Node this Widget is bound to.
---@param align Vector2 The Widget's alignment.
---@param font Font The Font to be used for this Text.
---@param text string The text to be written in this Widget.
---@param color Color The Color to be used for the Font.
function UI2WidgetText:new(node, align, font, text, color)
	self.type = "text"

	self.node = node
	self.align = align

	self.font = font
	self.text = text
	self.color = color
end



---Returns the current Widget's position.
---@return Vector2
function UI2WidgetText:getPos()
	return self.node:getGlobalPos() - self:getSize() * self.align
end

---Returns the current Widget's size.
---@return Vector2
function UI2WidgetText:getSize()
	return self.font:getTextSize(self.text) * self.node:getGlobalScale()
end



---Draws this Widget on the screen.
function UI2WidgetText:draw()
	self.font:draw(self.text, self:getPos(), nil, self.color, self.node:getGlobalAlpha(), self.node:getGlobalScale())
end



return UI2WidgetText
