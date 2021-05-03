local class = require "com/class"
local UIWidgetImageProgress = class:derive("UIWidgetImageProgress")

local Vec2 = require("src/Essentials/Vector2")

function UIWidgetImageProgress:new(parent, image, value, smooth)
	self.type = "imageProgress"

	self.parent = parent

	self.image = game.resourceManager:getImage(image)
	self.value = 0
	self.valueData = value
	self.smooth = smooth
end



function UIWidgetImageProgress:draw(variables)
	local value = parseNumber(self.valueData, variables)
	if self.smooth then
		if self.value < value then
			self.value = math.min(self.value * 0.95 + value * 0.0501, value)
		elseif self.value > value then
			self.value = math.max(self.value * 0.95 + value * 0.0501, 0)
		end
	else
		self.value = value
	end

	local pos = self.parent:getPos()
	local pos2 = posOnScreen(pos)
	love.graphics.setScissor(pos2.x, pos2.y, self.image.size.x * getResolutionScale() * self.value, self.image.size.y * getResolutionScale())
	self.image:draw(pos, nil, nil, nil, nil, self.parent:getAlpha())
	love.graphics.setScissor()
end

return UIWidgetImageProgress
