local class = require "class"
local UIWidgetImage = class:derive("UIWidgetImage")

local Vec2 = require("Essentials/Vector2")

function UIWidgetImage:new(parent, image)
	self.type = "imageButton"
	
	self.parent = parent
	
	self.hovered = false
	self.clicked = false
	self.enabled = true
	
	self.image = game.resourceBank:getImage(image)
end

function UIWidgetImage:click()
	if not self.parent:getVisible() or not self.hovered or self.clicked then return end
	self.clicked = true
	game:playSound("button_click")
	print("Button clicked: " .. self.parent:getFullName())
end

function UIWidgetImage:unclick()
	if not self.clicked then return end
	self.parent:executeAction("buttonClick")
	self.clicked = false
end



function UIWidgetImage:draw()
	local pos = self.parent:getPos()
	local pos2 = pos + self.image.size * Vec2(1, 0.25)
	local alpha = self.parent:getAlpha()
	
	self.enabled = alpha == 1
	local hovered = self.enabled and mousePos.x >= pos.x and mousePos.y >= pos.y and mousePos.x <= pos2.x and mousePos.y <= pos2.y
	if hovered ~= self.hovered then
		self.hovered = hovered
		--if not self.hovered and self.clicked then self:unclick() end
		--SOUNDS.buttonHover:play()
	end
	
	self.image:draw(pos, nil, Vec2(1, self:getFrame()), nil, nil, alpha)
end

function UIWidgetImage:getFrame()
	if not self.enabled then return 4 end
	if self.clicked then return 3 end
	if self.hovered then return 2 end
	return 1
end

return UIWidgetImage