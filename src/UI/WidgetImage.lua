local class = require "com/class"
local UIWidgetImage = class:derive("UIWidgetImage")

function UIWidgetImage:new(parent, image)
	self.type = "image"

	self.parent = parent

	self.image = game.resourceManager:getImage(image)
end



function UIWidgetImage:draw()
	self.image:draw(self.parent:getPos(), nil, nil, nil, nil, self.parent:getAlpha())
end

return UIWidgetImage
