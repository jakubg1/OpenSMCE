local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")

---@class UIWidgetSpriteButton
---@overload fun(parent, sprite, clickSound, releaseSound, hoverSound, orbMasterHoverEffect):UIWidgetSpriteButton
local UIWidgetSpriteButton = class:derive("UIWidgetSpriteButton")

function UIWidgetSpriteButton:new(parent, sprite, clickSound, releaseSound, hoverSound, orbMasterHoverEffect)
	self.type = "spriteButton"

	self.parent = parent

	self.hovered = false
	self.clicked = false
	self.clickedV = false
	self.enabled = true
	self.disabled = false

	self.sprite = _Res:getSprite(sprite)
	self.size = self.sprite.config.frameSize
	self.clickSound = clickSound and _Res:getSoundEvent(clickSound) or _Game.configManager:getUIClickSound()
	self.releaseSound = releaseSound and _Res:getSoundEvent(releaseSound) or _Game.configManager:getUIReleaseSound()
	self.hoverSound = hoverSound and _Res:getSoundEvent(hoverSound) or _Game.configManager:getUIHoverSound()

	self.orbMasterHoverEffect = orbMasterHoverEffect
	self.orbMasterHoverTime = 0
end

function UIWidgetSpriteButton:click()
	if not self.hovered or self.clicked then return end
	self.clicked = true
	if self.clickSound then
		self.clickSound:play()
	end
	print("Button clicked: " .. self.parent:getFullName())
end

function UIWidgetSpriteButton:unclick()
	if not self.clicked then return end
	if self.hovered then
		self.parent:executeAction("buttonClick")
	end
	if self.releaseSound then
		self.releaseSound:play()
	end
	self.clicked = false
end

function UIWidgetSpriteButton:keypressed(key)
	if not self.enabled then return end
	if key == self.parent.hotkey then
		self.parent:executeAction("buttonClick")
	end
end

function UIWidgetSpriteButton:setEnabled(enabled)
	self.disabled = not enabled
end

function UIWidgetSpriteButton:getEnabled()
	return not self.disabled
end

function UIWidgetSpriteButton:update(dt)
	self.enabled = not self.disabled and ((self.parent:getAlpha() == 1 and self.parent.active) or self.parent.neverDisabled)
	if self.hovered then
		self.orbMasterHoverTime = math.min(self.orbMasterHoverTime + dt / 0.25, 1)
	else
		self.orbMasterHoverTime = math.max(self.orbMasterHoverTime - dt / 0.25, 0)
	end
end

function UIWidgetSpriteButton:draw()
	local pos = self.parent:getPos()
	local origPos = pos:clone()
	local alpha = self.parent:getAlpha()
	local size = self.size
	local scale = 1

	if self.orbMasterHoverEffect then
		local t = math.sqrt(self.orbMasterHoverTime)
		pos = pos + Vec2(t * 20, 0)
		scale = 1 + t * 0.2
		size = size * scale
	end

	local hovered = self.enabled and self.parent.active and _Utils.isPointInsideBox(_MouseX, _MouseY, origPos.x, origPos.y, size.x - 1, size.y - 1) and not _Debug.uiDebug:isHovered()
	if hovered ~= self.hovered then
		self.hovered = hovered
		--if not self.hovered and self.clicked then self:unclick() end
		if hovered and self.hoverSound then
			self.hoverSound:play()
		end
	end

	_Renderer:setLayer(self.parent.layer)
	self.sprite:draw(pos.x, pos.y, nil, nil, self:getState(), nil, nil, nil, alpha, scale)
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
