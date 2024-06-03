local class = require "com.class"

---@class UIWidgetSpriteButton
---@overload fun(parent, sprite):UIWidgetSpriteButton
local UIWidgetSpriteButton = class:derive("UIWidgetSpriteButton")

local Vec2 = require("src.Essentials.Vector2")



function UIWidgetSpriteButton:new(parent, sprite)
	self.type = "spriteButton"

	self.parent = parent

	self.hovered = false
	self.clicked = false
	self.clickedV = false
	self.enabled = true
	self.enableForced = true

	self.sprite = _Game.resourceManager:getSprite(sprite)
	self.size = self.sprite.frameSize
end

function UIWidgetSpriteButton:click()
	if not self.parent:isVisible() or not self.hovered or self.clicked then return end
	self.clicked = true
	_Game:playSound(_Game.configManager.gameplay.ui.buttonClickSound)
	print("Button clicked: " .. self.parent:getFullName())
end

function UIWidgetSpriteButton:unclick()
	if not self.clicked then return end
	if self.hovered then
		self.parent:executeAction("buttonClick")
	end
	self.clicked = false
end

function UIWidgetSpriteButton:keypressed(key)
	if not self.parent:isVisible() or not self.enabled then return end
	if key == self.parent.hotkey then
		self.parent:executeAction("buttonClick")
	end
end

function UIWidgetSpriteButton:setEnabled(enabled)
	self.enableForced = enabled
end



function UIWidgetSpriteButton:draw()
	local pos = self.parent:getPos()
	local pos2 = pos + self.size
	local alpha = self.parent:getAlpha()

	self.enabled = self.enableForced and (alpha == 1 or self.parent.neverDisabled)
	local hovered = self.enabled and self.parent.active and _MousePos.x >= pos.x and _MousePos.y >= pos.y and _MousePos.x < pos2.x and _MousePos.y < pos2.y
	if hovered ~= self.hovered then
		self.hovered = hovered
		--if not self.hovered and self.clicked then self:unclick() end
		if hovered then
			_Game:playSound(_Game.configManager.gameplay.ui.buttonHoverSound)
		end
	end

	self.sprite:draw(pos, nil, self:getState(), nil, nil, nil, alpha)
end

function UIWidgetSpriteButton:getState()
	if not self.enabled then return 4 end
	if self.clicked or self.clickedV then return 3 end
	if self.hovered then return 2 end
	return 1
end

function UIWidgetSpriteButton:getSize()
	return self.size
end

return UIWidgetSpriteButton
