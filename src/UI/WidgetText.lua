local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")

---@class UIWidgetText
---@overload fun(parent, text, font, align):UIWidgetText
local UIWidgetText = class:derive("UIWidgetText")

function UIWidgetText:new(parent, text, font, align)
	self.type = "text"
	self.parent = parent
	self.text = _Game.configManager:translate(text or "")
	local success
	success, self.font = pcall(function() return _Res:getFont(font) end)
	if not success then
		-- TODO: Add a checkbox in the Boot Screen to toggle these errors in the visible console.
		_Log:print(string.format("WIDGET ERROR: Could not load font %s for widget %s", font, parent:getFullName()))
		self.font = nil
	end
	self.align = align and Vec2(align.x, align.y) or Vec2(0.5, 0)
	self.debugColor = {1.0, 0.5, 0.5}
end

function UIWidgetText:draw()
	if not self.font then
		return
	end
	local x, y = self.parent:getPos()
	_Renderer:setLayer(self.parent.layer)
	_Renderer:setPriority(1)
	self.font:draw(self.text, x, y, self.align.x, self.align.y, nil, self.parent:getAlpha())
	_Renderer:setPriority()
end

function UIWidgetText:getSize()
	if not self.font then
		return Vec2()
	end
	return Vec2(self.font:getTextSize(self.text))
end

return UIWidgetText
