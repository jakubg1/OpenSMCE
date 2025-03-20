local class = require "com.class"

---Represents a label which appears for a moment when the Player gets score.
---@class FloatingText
---@overload fun(text, pos, font):FloatingText
local FloatingText = class:derive("FloatingText")

local Vec2 = require("src.Essentials.Vector2")



---Constructs a new instance of Floating Text.
---@param text string The text to be displayed.
---@param pos Vector2 The starting position of this text.
---@param font string|Font Path to the Font or the Font itself which is going to be used.
function FloatingText:new(text, pos, font)
	self.text = text
	self.pos = pos
	self.font = font
	if type(self.font) == "string" then
		-- TODO: Remove at some point when we get rid of pointing to resources via names.
		_Debug:deprecationNotice("FloatingText:new(): String argument will be phased out soon!", 2)
		self.font = _Game.resourceManager:getFont(self.font)
	end

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
	self.font:draw(self.text, self.pos + Vec2(0, self.time * -48), nil, nil, math.min((1 - self.time) / 0.2, 1))
end



return FloatingText
