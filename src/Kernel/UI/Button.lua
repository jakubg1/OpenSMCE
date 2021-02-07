local class = require "com/class"
local Button = class:derive("Button")

local Vec2 = require("src/Essentials/Vector2")

function Button:new(name, font, pos, size, onClick)
	self.name = name
	self.font = font
	self.pos = pos
	self.size = size
	
	self.visible = true
	self.hovered = false
	self.selected = false
	
	self.onClick = onClick
end

function Button:update(dt)
	if not self.visible then return end
	
	self.hovered = mousePos.x > self.pos.x and
					mousePos.x < self.pos.x + self.size.x and
					mousePos.y > self.pos.y and
					mousePos.y < self.pos.y + self.size.y
end

function Button:draw()
	if not self.visible then return end
	
	love.graphics.setFont(self.font)
	love.graphics.setLineWidth(1)
	if self.hovered then
		if self.selected then
			love.graphics.setColor(0.2, 0.2, 0.2)
		else
			love.graphics.setColor(0.8, 0.8, 0.8)
		end
	else
		if self.selected then
			love.graphics.setColor(0.6, 0.6, 0.6)
		else
			love.graphics.setColor(0.4, 0.4, 0.4)
		end
	end
	love.graphics.rectangle("fill", self.pos.x, self.pos.y, self.size.x, self.size.y)
	love.graphics.setColor(0.2, 0.2, 0.2)
	love.graphics.rectangle("line", self.pos.x, self.pos.y, self.size.x, self.size.y)
	love.graphics.setColor(0, 0, 0)
	love.graphics.print(self.name, self.pos.x + 4, self.pos.y + 2)
end



function Button:mousereleased(x, y, button)
	if not self.visible then return end
	
	if self.hovered then
		self.onClick()
	end
end

return Button