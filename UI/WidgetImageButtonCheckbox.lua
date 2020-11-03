local class = require "class"
local UIWidgetImageButtonCheckbox = class:derive("UIWidgetImageButtonCheckbox")

local Vec2 = require("Essentials/Vector2")
local UIWidgetImageButton = require("UI/WidgetImageButton")

function UIWidgetImageButtonCheckbox:new(parent, images)
	self.type = "imageButtonCheckbox"
	
	self.parent = parent
	self.button = UIWidgetImageButton(parent, images[1])
	
	self.state = false
	
	self.images = {game.resourceBank:getImage(images[1]), game.resourceBank:getImage(images[2])}
end

function UIWidgetImageButtonCheckbox:click()
	self.button:click()
end

function UIWidgetImageButtonCheckbox:unclick()
	if not self.button.clicked then return end
	self.button:unclick()
	self:setState(not self.state)
end

function UIWidgetImageButtonCheckbox:keypressed(key)
	self.button:keypressed(key)
end

function UIWidgetImageButtonCheckbox:setEnabled(enabled)
	self.button:setEnabled(enabled)
end

function UIWidgetImageButtonCheckbox:setState(state)
	self.state = state
	self.button.image = self.images[state and 2 or 1]
end



function UIWidgetImageButtonCheckbox:draw()
	self.button:draw()
end

return UIWidgetImageButtonCheckbox