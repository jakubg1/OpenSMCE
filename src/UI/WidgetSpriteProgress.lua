local class = require "com.class"

---@class UIWidgetSpriteProgress
---@overload fun(parent, sprite, value, smooth):UIWidgetSpriteProgress
local UIWidgetSpriteProgress = class:derive("UIWidgetSpriteProgress")

local Vec2 = require("src.Essentials.Vector2")



function UIWidgetSpriteProgress:new(parent, sprite, value, smooth)
	self.type = "spriteProgress"

	self.parent = parent

	self.sprite = _Game.resourceManager:getSprite(sprite)
	self.size = self.sprite.img.size
	self.value = 0
	self.valueData = value
	self.smooth = smooth
end



function UIWidgetSpriteProgress:update(dt)
	local value = _ParseNumber(self.valueData)
	if self.smooth then
		if self.value < value then
			self.value = math.min(self.value * 0.95 + value * 0.0501, value)
		elseif self.value > value then
			self.value = math.max(self.value * 0.95 + value * 0.0501, 0)
		end
	else
		self.value = value
	end
end

function UIWidgetSpriteProgress:draw(variables)
	local pos = self.parent:getPos()
	local pos2 = _PosOnScreen(pos)
	love.graphics.setScissor(pos2.x, pos2.y, self.size.x * _GetResolutionScale() * self.value, self.size.y * _GetResolutionScale())
	self.sprite:draw(pos, nil, nil, nil, nil, nil, self.parent:getAlpha())
	love.graphics.setScissor()
end

return UIWidgetSpriteProgress
