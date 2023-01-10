local class = require "com/class"

---@class UI2WidgetSpriteButton
---@overload fun(node, align, sprite):UI2WidgetSpriteButton
local UI2WidgetSpriteButton = class:derive("UI2WidgetSpriteButton")

local Vec2 = require("src/Essentials/Vector2")



---Constructs a new UI2 Sprite Button widget.
---@param node UI2Node The Node this Widget is bound to.
---@param sprite Sprite The Sprite to be drawn as this Widget.
function UI2WidgetSpriteButton:new(node, align, sprite)
	self.type = "spriteButton"

    self.node = node

	self.align = align
	self.sprite = sprite

	self.hovered = false
	self.clicked = false
	self.clickedV = false
	self.enableForced = true
	self.hotkeys = {}
end



---Updates this Widget.
---@param dt number Time delta in seconds.
function UI2WidgetSpriteButton:update(dt)
	local hovered = self:isEnabled() and self.node.active and self:isHovered()
	if hovered ~= self.hovered then
		self.hovered = hovered
		--if not self.hovered and self.clicked then self:unclick() end
		if hovered then
			_Game:playSound("sound_events/button_hover.json")
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
	return _MousePos.x >= p1.x and _MousePos.x <= p2.x and _MousePos.y >= p1.y and _MousePos.y <= p2.y
end

---Returns whether this Widget can be clicked.
function UI2WidgetSpriteButton:isEnabled()
	return self.enableForced and (self.node:getGlobalAlpha() == 1 or self.node.neverDisabled)
end



---Clicks this Widget.
function UI2WidgetSpriteButton:click()
	if not self.hovered or self.clicked then
		return
	end
	self.clicked = true
	_Game:playSound("sound_events/button_click.json")
	--print("Button clicked: " .. self.parent:getFullName())
end

---Unclicks this Widget.
function UI2WidgetSpriteButton:unclick()
	if not self.clicked then
		return
	end
	--self.parent:executeAction("buttonClick")
	self.clicked = false
end



---Keypress callback.
---@param key string The key which has been pressed.
function UI2WidgetSpriteButton:keypressed(key)
	if not self.enabled then
		return
	end
	if key == self.node.hotkey then
		--self.parent:executeAction("buttonClick")
	end
end



---Sets whether this Button should bypass the alpha check.
---By default, if the Button is not fully opaque (alpha < 1), it will be disabled.
---This function allows making buttons which are transparent (or even invisible!) and can still operate as normal.




---Sets whether this Button should be enabled.
---@param enabled boolean
function UI2WidgetSpriteButton:setEnabled(enabled)
	self.enableForced = enabled
end



---Draws this Widget.
function UI2WidgetSpriteButton:draw()
	self.sprite:draw(self:getPos(), nil, self:getState(), nil, nil, nil, self.node:getGlobalAlpha(), self.node:getGlobalScale())
end



return UI2WidgetSpriteButton
