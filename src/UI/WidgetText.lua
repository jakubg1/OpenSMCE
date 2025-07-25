local class = require "com.class"

---@class UIWidgetText
---@overload fun(parent, text, font, align):UIWidgetText
local UIWidgetText = class:derive("UIWidgetText")

local Vec2 = require("src.Essentials.Vector2")

function UIWidgetText:new(parent, text, font, align)
	self.type = "text"

	self.parent = parent

	self.text = text
	self.textTmp = ""
	self.font = _Game.resourceManager:getFont(font)
	self.align = align and _ParseVec2(align) or Vec2(0.5, 0)
	self.debugColor = {1.0, 0.5, 0.5}
end

function UIWidgetText:draw()
	local pos = self.parent:getPos()
	self.font:draw(self.textTmp, pos.x, pos.y, self.align.x, self.align.y, nil, self.parent:getAlpha())
end

function UIWidgetText:getSize()
	return Vec2(self.font:getTextSize(self.textTmp))
end

return UIWidgetText
