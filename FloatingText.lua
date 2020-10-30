--- A purely decorational tooltip informing which powerup was just picked up or how much score the player gained.
-- @classmod FloatingText



-- Class identification
local class = require "class"
local FloatingText = class:derive("FloatingText")

local Vec2 = require("Essentials/Vector2")



--- Constructors
-- @section constructors

--- Object constructor.
-- Executed when this object is created.
-- @tparam string text The text to display.
-- @tparam Vector2 pos Where to spawn the FloatingText.
-- @tparam string font Which font to use. This method will automatically get a font instance from ResourceBank.
function FloatingText:new(text, pos, font)
	self.text = text
	self.pos = pos
	self.font = game.resourceBank:getFont(font)
	
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