local class = require "com/class"

---@class UI2WidgetSpriteButton
---@overload fun(parent, sprite):UI2WidgetSpriteButton
local UI2WidgetSpriteButton = class:derive("UI2WidgetSpriteButton")

local Vec2 = require("src/Essentials/Vector2")



---Constructs a new UI2 Sprite Button widget.
---@param parent UI2Node The Node this Widget is bound to.
---@param sprite Sprite The Sprite to be drawn as this Widget.
function UI2WidgetSpriteButton:new(parent, align, sprite)
	self.type = "spriteButton"

	self.parent = parent

	self.hovered = false
	self.clicked = false
	self.clickedV = false
	self.enabled = true
	self.enableForced = true

    self.parent = parent
    
	self.align = align
	self.sprite = sprite
end

---Returns the current Widget's position.
---@return Vector2
function UI2WidgetSpriteButton:getPos()
	return self.parent:getGlobalPos() - self:getSize() * self.align
end

---Returns the current Widget's size.
---@return Vector2
function UI2WidgetSpriteButton:getSize()
	return self.sprite.size * self.parent:getGlobalScale()
end

function UI2WidgetSpriteButton:click()
	if not self.parent:isVisible() or not self.hovered or self.clicked then return end
	self.clicked = true
	_Game:playSound("sound_events/button_click.json")
	--print("Button clicked: " .. self.parent:getFullName())
end

function UI2WidgetSpriteButton:unclick()
	if not self.clicked then return end
	--self.parent:executeAction("buttonClick")
	self.clicked = false
end

function UI2WidgetSpriteButton:keypressed(key)
	if not self.parent:isVisible() or not self.enabled then return end
	if key == self.parent.hotkey then
		--self.parent:executeAction("buttonClick")
	end
end

function UI2WidgetSpriteButton:setEnabled(enabled)
	self.enableForced = enabled
end



function UI2WidgetSpriteButton:draw()
	local pos = self:getPos()
	local pos2 = pos + self:getSize()
	local alpha = self.parent:getGlobalAlpha()

	self.enabled = self.enableForced and (alpha == 1 or self.parent.neverDisabled)
	local hovered = self.enabled --[[and self.parent.active]] and _MousePos.x >= pos.x and _MousePos.y >= pos.y and _MousePos.x < pos2.x and _MousePos.y < pos2.y
	if hovered ~= self.hovered then
		self.hovered = hovered
		--if not self.hovered and self.clicked then self:unclick() end
		if hovered then
			_Game:playSound("sound_events/button_hover.json")
		end
	end

	self.sprite:draw(pos, nil, self:getState(), nil, nil, nil, alpha, self.parent:getGlobalScale())
end

function UI2WidgetSpriteButton:getState()
	if not self.enabled then return 4 end
	if self.clicked or self.clickedV then return 3 end
	if self.hovered then return 2 end
	return 1
end

return UI2WidgetSpriteButton
