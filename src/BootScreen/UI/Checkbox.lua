local class = require "com.class"

---@class Checkbox
---@overload fun(name, font, pos, size, onClick):Checkbox
local Checkbox = class:derive("Checkbox")

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

	self.hovered = _Utils.isPointInsideBoxExcl(_MouseX, _MouseY, self.pos.x, self.pos.y, self.size.x, self.size.y)
end

function Checkbox:draw()
	if not self.visible then return end

	love.graphics.setFont(self.font)
	love.graphics.setLineWidth(1)
	if self.hovered then
		if self.selected then
			love.graphics.setColor(0.4, 1, 0.4)
		else
			love.graphics.setColor(1, 0.4, 0.4)
		end
	else
		if self.selected then
			love.graphics.setColor(0, 0.9, 0)
		else
			love.graphics.setColor(0.9, 0, 0)
		end
	end
	love.graphics.rectangle("fill", self.pos.x, self.pos.y, 40, self.size.y)
	love.graphics.setColor(0.2, 0.2, 0.2)
	love.graphics.rectangle("line", self.pos.x, self.pos.y, 40, self.size.y)
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
