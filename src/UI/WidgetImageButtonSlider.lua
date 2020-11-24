local class = require "com/class"
local UIWidgetImageButtonSlider = class:derive("UIWidgetImageButtonSlider")

local Vec2 = require("src/Essentials/Vector2")
local UIWidgetImageButton = require("src/UI/WidgetImageButton")

function UIWidgetImageButtonSlider:new(parent, image, bounds)
	self.type = "imageButton"
	
	self.parent = parent
	self.button = UIWidgetImageButton(parent, image)
	
	self.value = 0
	self.bounds = bounds
	self.catchX = 0
end

function UIWidgetImageButtonSlider:click()
	if not self.parent:getVisible() or not self.button.hovered or self.button.clicked then return end
	self.button:click()
	self.catchX = mousePos.x - self.parent.pos.x
end

function UIWidgetImageButtonSlider:unclick()
	self.button:unclick()
end

-- this is pointless:
-- function UIWidgetImageButtonSlider:keypressed(key)
	-- self.button:keypressed(key)
-- end

function UIWidgetImageButtonSlider:setEnabled(enabled)
	self.button:setEnabled(enabled)
end

function UIWidgetImageButtonSlider:setValue(value)
	self.value = value
	self.parent.pos.x = self.bounds[1] + ((self.bounds[2] - self.bounds[1]) * value)
end



function UIWidgetImageButtonSlider:draw()
	if self.button.clicked then
		self.parent.pos.x = math.min(math.max(mousePos.x - self.catchX, self.bounds[1]), self.bounds[2])
		self.value = (self.parent.pos.x - self.bounds[1]) / (self.bounds[2] - self.bounds[1])
	end
	self.button:draw()
end

return UIWidgetImageButtonSlider