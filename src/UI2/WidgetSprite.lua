local class = require "com.class"

---@class UI2WidgetSprite
---@overload fun(node, align, sprite):UI2WidgetSprite
local UI2WidgetSprite = class:derive("UI2WidgetSprite")



---Constructs a new UI2 Sprite widget.
---@param node UI2Node The Node this Widget is bound to.
---@param align Vector2 The Widget's alignment.
---@param sprite Sprite The Sprite to be drawn as this Widget.
function UI2WidgetSprite:new(node, align, sprite)
	self.type = "sprite"

	self.node = node
	self.align = align

	self.sprite = sprite
end



---Returns the current Widget's position.
---@return Vector2
function UI2WidgetSprite:getPos()
	return self.node:getGlobalPos() - self:getSize() * self.align
end

---Returns the current Widget's size.
---@return Vector2
function UI2WidgetSprite:getSize()
	return self.sprite.frameSize * self.node:getGlobalScale()
end



---Draws this Widget on the screen.
function UI2WidgetSprite:draw()
	self.sprite:draw(self:getPos(), nil, nil, nil, nil, nil, self.node:getGlobalAlpha(), self.node:getGlobalScale())
end



return UI2WidgetSprite
