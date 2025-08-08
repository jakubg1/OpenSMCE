local class = require "com.class"

---Represents a label which appears for a moment when the Player gets score.
---@class FloatingText
---@overload fun(text, x, y, font):FloatingText
local FloatingText = class:derive("FloatingText")

---Constructs a new instance of Floating Text.
---@param text string The text to be displayed.
---@param x number The starting X position of this text.
---@param y number The starting Y position of this text.
---@param font Font The font which is going to be used to draw the text.
function FloatingText:new(text, x, y, font)
	self.text = text
	self.x, self.y = x, y
	self.font = font

	self.time = 0

	self.delQueue = false
end

---Updates the Floating Text.
---@param dt number Delta time in seconds.
function FloatingText:update(dt)
	self.time = self.time + dt
	if self.time >= 1 then
		self:destroy()
	end
end

---Removes itself from the level.
function FloatingText:destroy()
	self.delQueue = true
end

---Draws the Floating Text.
function FloatingText:draw()
	self.font:draw(self.text, self.x, self.y - self.time * 48, nil, nil, nil, math.min((1 - self.time) / 0.2, 1))
end

return FloatingText
