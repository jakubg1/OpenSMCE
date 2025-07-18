local class = require "com.class"

---@class UIWidgetTextInput
---@overload fun(parent, font, align, cursorSprite, maxLength):UIWidgetTextInput
local UIWidgetTextInput = class:derive("UIWidgetTextInput")

local Vec2 = require("src.Essentials.Vector2")



function UIWidgetTextInput:new(parent, font, align, cursorSprite, maxLength)
	self.type = "textInput"

	self.parent = parent

	self.text = ""
	self.font = _Game.resourceManager:getFont(font)
	self.align = align and _ParseVec2(align) or Vec2(0.5, 0)
	self.cursorSprite = cursorSprite and _Game.resourceManager:getSprite(cursorSprite)
	self.cursorSpriteBlink = 0
	self.maxLength = maxLength
end



function UIWidgetTextInput:update(dt)
	self.cursorSpriteBlink = (self.cursorSpriteBlink + dt) % 1
end

function UIWidgetTextInput:keypressed(key)
	if key == "backspace" and self.text:len() > 0 then
		self.text = self.text:sub(1, self.text:len() - 1)
	end
end

function UIWidgetTextInput:textinput(t)
	local allowedChars = " 0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-.,:'!?/"
	for i = 1, allowedChars:len() do
		if t == allowedChars:sub(i, i) and self.text:len() < self.maxLength then
			self.text = self.text .. t
		end
	end
end

function UIWidgetTextInput:draw(variables)
	local pos = self.parent:getPos()
	local alpha = self.parent:getAlpha()
	self.font:draw(self.text, pos.x, pos.y, self.align.x, self.align.y, nil, alpha)
	if self.cursorSprite then
		local cpos = pos + Vec2(self:getSize().x * (1 - self.align.x), 0)
		local frame = math.floor(self.cursorSpriteBlink * 2) + 1
		self.cursorSprite:draw(cpos.x, cpos.y, nil, nil, nil, frame, nil, nil, alpha)
	end
end

function UIWidgetTextInput:getSize()
	return Vec2(self.font:getTextSize(self.text))
end

return UIWidgetTextInput
