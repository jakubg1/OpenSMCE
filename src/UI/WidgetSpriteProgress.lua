local class = require "com.class"

---@class UIWidgetSpriteProgress
---@overload fun(parent, sprite, value, smooth):UIWidgetSpriteProgress
local UIWidgetSpriteProgress = class:derive("UIWidgetSpriteProgress")

function UIWidgetSpriteProgress:new(parent, sprite, value, smooth)
	self.type = "spriteProgress"
	self.parent = parent
	self.sprite = _Res:getSprite(sprite)
	self.size = self.sprite.imageSize
	self.value = 0
	self.valueData = value or 0
	self.smooth = smooth
end

function UIWidgetSpriteProgress:update(dt)
	local value = self.valueData
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

function UIWidgetSpriteProgress:draw()
	local pos = self.parent:getPos()
	_Renderer:setLayer(self.parent.layer)
	_Renderer:setScissor(pos.x, pos.y, self.size.x * self.value, self.size.y)
	self.sprite:draw(pos.x, pos.y, nil, nil, nil, nil, nil, nil, self.parent:getAlpha())
	_Renderer:setScissor()
end

function UIWidgetSpriteProgress:getSize()
	return self.size
end

return UIWidgetSpriteProgress
