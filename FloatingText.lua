local class = require "class"
local FloatingText = class:derive("FloatingText")

local Vec2 = require("Essentials/Vector2")

function FloatingText:new(text, pos, font)
	self.text = text
	self.pos = pos
	self.font = game.resourceBank:getFont(font)
	
	self.time = 0
	
	self.delQueue = false
end

function FloatingText:update(dt)
	self.time = self.time + dt
	if self.time >= 1 then self.delQueue = true end
end



function FloatingText:draw()
	self.font:draw(self.text, self.pos + Vec2(0, self.time * -48), nil, nil, math.min((1 - self.time) / 0.2, 1))
end

return FloatingText