local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")

---@class UIWidgetText
---@overload fun(parent, text, font, align):UIWidgetText
local UIWidgetText = class:derive("UIWidgetText")

function UIWidgetText:new(parent, text, font, align)
	self.type = "text"
	self.parent = parent
	self.text = text or ""
	self.font = _Res:getFont(font)
	self.align = align and Vec2(align.x, align.y) or Vec2(0.5, 0)
	self.debugColor = {1.0, 0.5, 0.5}
end

function UIWidgetText:draw()
	local pos = self.parent:getPos()
	_Renderer:setLayer(self.parent.layer)
	self.font:draw(self.text, pos.x, pos.y, self.align.x, self.align.y, nil, self.parent:getAlpha())
end

function UIWidgetText:getSize()
	return Vec2(self.font:getTextSize(self.text))
end

return UIWidgetText
