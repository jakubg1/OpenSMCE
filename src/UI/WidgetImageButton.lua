local class = require "com/class"
local UIWidgetImageButton = class:derive("UIWidgetImageButton")

local Vec2 = require("src/Essentials/Vector2")

function UIWidgetImageButton:new(parent, image)
	self.type = "imageButton"

	self.parent = parent

	self.hovered = false
	self.clicked = false
	self.enabled = true
	self.enableForced = true

	self.image = game.resourceManager:getImage(image)
end

function UIWidgetImageButton:click()
	if not self.parent:isVisible() or not self.hovered or self.clicked then return end
	self.clicked = true
	game:playSound("button_click")
	print("Button clicked: " .. self.parent:getFullName())
end

function UIWidgetImageButton:unclick()
	if not self.clicked then return end
	self.parent:executeAction("buttonClick")
	self.clicked = false
end

function UIWidgetImageButton:keypressed(key)
	if not self.parent:isVisible() or not self.enabled then return end
	if key == self.parent.hotkey then
		self.parent:executeAction("buttonClick")
	end
end

function UIWidgetImageButton:setEnabled(enabled)
	self.enableForced = enabled
end



function UIWidgetImageButton:draw()
	local pos = self.parent:getPos()
	local pos2 = pos + self.image.size * Vec2(1, 0.25)
	local alpha = self.parent:getAlpha()

	self.enabled = self.enableForced and (alpha == 1 or self.parent.neverDisabled)
	local hovered = self.enabled and self.parent.active and mousePos.x >= pos.x and mousePos.y >= pos.y and mousePos.x <= pos2.x and mousePos.y <= pos2.y
	if hovered ~= self.hovered then
		self.hovered = hovered
		--if not self.hovered and self.clicked then self:unclick() end
		--SOUNDS.buttonHover:play()
	end

	self.image:draw(pos, nil, Vec2(1, self:getFrame()), nil, nil, alpha)
end

function UIWidgetImageButton:getFrame()
	if not self.enabled then return 4 end
	if self.clicked then return 3 end
	if self.hovered then return 2 end
	return 1
end

return UIWidgetImageButton
