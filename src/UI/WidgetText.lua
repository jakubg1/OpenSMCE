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
end



function UIWidgetText:draw(variables)
	self.font:draw(self.textTmp, self.parent:getPos(), self.align, nil, self.parent:getAlpha())
end

function UIWidgetText:getSize()
	return self.font:getTextSize(self.textTmp)
end

return UIWidgetText
