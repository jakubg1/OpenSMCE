local class = require "com/class"

---@class UI2WidgetSpriteButton
---@overload fun(node, align, sprite, callbacks):UI2WidgetSpriteButton
local UI2WidgetSpriteButton = class:derive("UI2WidgetSpriteButton")

local Vec2 = require("src/Essentials/Vector2")



---Constructs a new UI2 Sprite Button widget.
---@param node UI2Node The Node this Widget is bound to.
---@param align Vector2 The Widget's alignment.
---@param sprite Sprite The Sprite to be drawn as this Widget.
---@param shape string Can be `"rectangle"` or `"ellipse"`. Defines the button hitbox.
---@param callbacks table A table of callbacks which should be fired on certain events.
function UI2WidgetSpriteButton:new(node, align, sprite, shape, callbacks)
	self.type = "spriteButton"

    self.node = node
	self.align = align

	self.sprite = sprite
	self.shape = shape
	self.callbacks = callbacks

	self.hovered = false
	self.clicked = false
	self.clickedV = false
	self.disabled = false
	self.neverDisabled = false
	self.hotkeys = {}
	self.hoverSound = "sound_events/button_hover.json"
	self.clickSound = "sound_events/button_click.json"
end



---Updates this Widget.
---@param dt number Time delta in seconds.
function UI2WidgetSpriteButton:update(dt)
	local hovered = self.node.active and self:isEnabled() and self:isHovered()
	if hovered ~= self.hovered then
		self.hovered = hovered
		if hovered then
			_Game:playSound(self.hoverSound)
		end
	end
end



---Returns the current Widget's position.
---@return Vector2
function UI2WidgetSpriteButton:getPos()
	return self.node:getGlobalPos() - self:getSize() * self.align
end

---Returns the current Widget's size.
---@return Vector2
function UI2WidgetSpriteButton:getSize()
	return self.sprite.frameSize * self.node:getGlobalScale()
end



---Returns the current Widget's state, depending on the button state.
---@return integer
function UI2WidgetSpriteButton:getState()
	if not self:isEnabled() then
		return 4
	elseif self.clicked or self.clickedV then
		return 3
	elseif self.hovered then
		return 2
	end
	return 1
end



---Returns whether this Widget is hovered.
---@return boolean
function UI2WidgetSpriteButton:isHovered()
	local p1 = self:getPos()
	local p2 = p1 + self:getSize()
	-- TODO: add a "sprite" type hitbox which will check pixel transparency (can't do now because no way to probe pixels on the Sprites)
	if self.shape == "ellipse" then
		return ((_MousePos - p1) / (p2 - p1) - Vec2(0.5)):len() <= 0.5
	end
	return _MousePos.x >= p1.x and _MousePos.x <= p2.x and _MousePos.y >= p1.y and _MousePos.y <= p2.y
end



---Returns whether this Widget can be clicked.
function UI2WidgetSpriteButton:isEnabled()
	return not self.disabled and (self.node:getGlobalAlpha() == 1 or self.neverDisabled)
end



---Sets whether this Button should bypass the alpha check.
---By default, if the Button is not fully opaque (alpha < 1), it will be disabled.
---This function allows making buttons which are transparent (or even invisible!) and can still operate as normal.




---Sets whether this Button should be enabled.
---@param enabled boolean
function UI2WidgetSpriteButton:setEnabled(enabled)
	self.disabled = not enabled
end



---Draws this Widget.
function UI2WidgetSpriteButton:draw()
	self.sprite:draw(self:getPos(), nil, self:getState(), nil, nil, nil, self.node:getGlobalAlpha(), self.node:getGlobalScale())
end



---Mouse press callback.
---@see Game.mousepressed
---@param x number
---@param y number
---@param button number
function UI2WidgetSpriteButton:mousepressed(x, y, button)
	if button ~= 1 or not self.hovered or self.clicked then
		return
	end
	self.clicked = true
	_Game:playSound(self.clickSound)
	print("Button clicked: " .. self.node:getPath())
end



---Mouse release callback.
---@see Game.mousereleased
---@param x number
---@param y number
---@param button number
function UI2WidgetSpriteButton:mousereleased(x, y, button)
	if button ~= 1 or not self.clicked then
		return
	end
	if self.callbacks.onClick then
		self.node.manager:executeCallback(self.callbacks.onClick)
	end
	self.clicked = false
end



---Keypress callback.
---@param key string The key which has been pressed.
function UI2WidgetSpriteButton:keypressed(key)
	if not self:isEnabled() then
		return
	end
	if _MathIsValueInTable(self.hotkeys, key) then
		if self.callbacks.onClick then
			self.node.manager:executeCallback(self.callbacks.onClick)
		end
	end
end



return UI2WidgetSpriteButton
