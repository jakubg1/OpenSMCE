local class = require "com/class"

---@class FloatingText
---@overload fun(text, pos, font):FloatingText
local FloatingText = class:derive("FloatingText")

local Vec2 = require("src/Essentials/Vector2")



function FloatingText:new(text, pos, font)
	self.text = text
	self.pos = pos
	self.font = _Game.resourceManager:getFont(font)

	self.time = 0
end

function FloatingText:update(dt)
	self.time = self.time + dt
	if self.time >= 1 then self:destroy() end
end

function FloatingText:destroy()
	self._list:destroy(self)
end



function FloatingText:draw()
	self.font:draw(self.text, self.pos + Vec2(0, self.time * -48), nil, nil, math.min((1 - self.time) / 0.2, 1))
end

return FloatingText
