local class = require "com/class"
local Checkbox = class:derive("Checkbox")

local Vec2 = require("src/Essentials/Vector2")

function Checkbox:new(name, font, pos, size, onClick)
	self.name = name
	self.font = font
	self.pos = pos
	self.size = size

	self.visible = true
	self.hovered = false
	self.selected = false

	self.onClick = onClick
end

function Checkbox:update(dt)
	if not self.visible then return end

	self.hovered = mousePos.x > self.pos.x and
					mousePos.x < self.pos.x + self.size.x and
					mousePos.y > self.pos.y and
					mousePos.y < self.pos.y + self.size.y
end

function Checkbox:draw()
	if not self.visible then return end

	love.graphics.setFont(self.font)
	love.graphics.setLineWidth(1)
	if self.selected then
		love.graphics.setColor(0.0, 0.8, 0.0)
	else
		love.graphics.setColor(0.8, 0.0, 0.0)
	end
	love.graphics.rectangle("fill", self.pos.x, self.pos.y, 40, self.size.y)
	love.graphics.setColor(0.2, 0.2, 0.2)
	love.graphics.rectangle("line", self.pos.x, self.pos.y, 40, self.size.y)
	-- handle
	local offset = self.selected and 25 or 0
	if self.hovered then
		love.graphics.setColor(0.6, 0.6, 0.6)
	else
		love.graphics.setColor(0.4, 0.4, 0.4)
	end
	love.graphics.rectangle("fill", self.pos.x + offset, self.pos.y, 15, self.size.y)
	love.graphics.setColor(0.2, 0.2, 0.2)
	love.graphics.rectangle("line", self.pos.x + offset, self.pos.y, 15, self.size.y)
	-- text
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(self.name, self.pos.x + 50, self.pos.y + 2)
end



function Checkbox:mousereleased(x, y, button)
	if not self.visible then return end

	if self.hovered then
		self.selected = not self.selected
		self.onClick(self.selected)
	end
end

return Checkbox
