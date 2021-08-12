local class = require "com/class"
local UIWidgetSprite = class:derive("UIWidgetSprite")

function UIWidgetSprite:new(parent, sprite)
	self.type = "sprite"

	self.parent = parent

	self.sprite = game.resourceManager:getSprite(sprite)
end



function UIWidgetSprite:draw()
	self.sprite:draw(self.parent:getPos(), nil, nil, nil, nil, self.parent:getAlpha())
end

return UIWidgetSprite
