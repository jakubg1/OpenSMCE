local class = require "com.class"

---@class UIWidgetSpriteButton
---@overload fun(parent, sprite, clickSound, releaseSound, hoverSound, orbMasterHoverEffect):UIWidgetSpriteButton
local UIWidgetSpriteButton = class:derive("UIWidgetSpriteButton")

local Vec2 = require("src.Essentials.Vector2")



function UIWidgetSpriteButton:new(parent, sprite, clickSound, releaseSound, hoverSound, orbMasterHoverEffect)
	self.type = "spriteButton"

	self.parent = parent

	self.hovered = false
	self.clicked = false
	self.clickedV = false
	self.enabled = true
	self.enableForced = true

	self.sprite = _Game.resourceManager:getSprite(sprite)
	self.size = self.sprite.config.frameSize
	self.clickSound = clickSound and _Game.resourceManager:getSoundEvent(clickSound) or _Game.configManager:getUIClickSound()
	self.releaseSound = releaseSound and _Game.resourceManager:getSoundEvent(releaseSound) or _Game.configManager:getUIReleaseSound()
	self.hoverSound = hoverSound and _Game.resourceManager:getSoundEvent(hoverSound) or _Game.configManager:getUIHoverSound()

	self.orbMasterHoverEffect = orbMasterHoverEffect
	self.orbMasterHoverTime = 0
end

function UIWidgetSpriteButton:click()
	if not self.parent:isVisible() or not self.hovered or self.clicked then return end
	self.clicked = true
	if self.clickSound then
		_Game:playSound(self.clickSound)
	end
	print("Button clicked: " .. self.parent:getFullName())
end

function UIWidgetSpriteButton:unclick()
	if not self.clicked then return end
	if self.hovered then
		self.parent:executeAction("buttonClick")
	end
	if self.releaseSound then
		_Game:playSound(self.releaseSound)
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



function UIWidgetSpriteButton:update(dt)
	if self.hovered then
		self.orbMasterHoverTime = math.min(self.orbMasterHoverTime + dt / 0.25, 1)
	else
		self.orbMasterHoverTime = math.max(self.orbMasterHoverTime - dt / 0.25, 0)
	end
end

function UIWidgetSpriteButton:draw()
	local pos = self.parent:getPos()
	local alpha = self.parent:getAlpha()
	local size = self.size
	local scale = 1

	if self.orbMasterHoverEffect then
		local t = math.sqrt(self.orbMasterHoverTime)
		pos = pos + Vec2(t * 20, 0)
		scale = 1 + t * 0.2
		size = size * scale
	end

	self.enabled = self.enableForced and (alpha == 1 or self.parent.neverDisabled)
	local hovered = self.enabled and self.parent.active and _Utils.isPointInsideBox(_MousePos, self.parent:getPos(), size) and not _Debug.uiDebug:isHovered()
	if hovered ~= self.hovered then
		self.hovered = hovered
		--if not self.hovered and self.clicked then self:unclick() end
		if hovered and self.hoverSound then
			_Game:playSound(self.hoverSound)
		end
	end

	self.sprite:draw(pos, nil, self:getState(), nil, nil, nil, alpha, Vec2(scale))
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
