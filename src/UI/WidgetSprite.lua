local class = require "com.class"

---@class UIWidgetSprite
---@overload fun(parent, sprite):UIWidgetSprite
local UIWidgetSprite = class:derive("UIWidgetSprite")



function UIWidgetSprite:new(parent, sprite)
	self.type = "sprite"

	self.parent = parent

	self.sprite = _Game.resourceManager:getSprite(sprite)
end



function UIWidgetSprite:draw()
	self.sprite:draw(self.parent:getPos(), nil, nil, nil, nil, nil, self.parent:getAlpha())
end

return UIWidgetSprite
