local class = require "com/class"

---@class UI2WidgetSpriteProgress
---@overload fun(node, align, sprite, value, smooth):UI2WidgetSpriteProgress
local UI2WidgetSpriteProgress = class:derive("UI2WidgetSpriteProgress")



---Constructs a new UI2 Sprite widget.
---@param node UI2Node The Node this Widget is bound to.
---@param align Vector2 The Widget's alignment.
---@param sprite Sprite The Sprite to be drawn as this Widget.
---@param value number
---@param smooth boolean
function UI2WidgetSpriteProgress:new(node, align, sprite, value, smooth)
	self.type = "sprite"

	self.node = node
	self.align = align

    self.sprite = sprite
    self.value = 0
	self.valueData = value
    self.smooth = smooth
end



---Returns the current Widget's position.
---@return Vector2
function UI2WidgetSpriteProgress:getPos()
	return self.node:getGlobalPos() - self:getSize() * self.align
end

---Returns the current Widget's size.
---@return Vector2
function UI2WidgetSpriteProgress:getSize()
	return self.sprite.frameSize * self.node:getGlobalScale()
end



---Draws this Widget on the screen.
function UI2WidgetSpriteProgress:update(dt)
	local value = _ParseNumber(self.valueData)
	if self.smooth then
		if self.value < value then
			self.value = math.min(self.value * 0.95 + value * 0.0501, value)
		elseif self.value > value then
			self.value = math.max(self.value * 0.95 + value * 0.0501, 0)
		end
	else
		self.value = value
	end
end



---Draws this Widget on the screen.
function UI2WidgetSpriteProgress:draw()
    local pos = self:getPos()
    local pos2 = _PosOnScreen(pos)
    -- this looks stupid because the original UI1 code didn't have an if statement
    -- but UI2 is pickier and wants this to be here lest I dare click on the play
	-- button and have the game crash
	if self.value then
		love.graphics.setScissor(pos2.x, pos2.y, self:getSize().x * _GetResolutionScale() * self.value, self:getSize().y * _GetResolutionScale())
		self.sprite:draw(self:getPos(), nil, nil, nil, nil, nil, self.node:getGlobalAlpha(), self.node:getGlobalScale())
		love.graphics.setScissor()
	end
end



return UI2WidgetSpriteProgress
