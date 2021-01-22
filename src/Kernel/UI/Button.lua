local class = require "com/class"
local Button = class:derive("Button")

local Vec2 = require("src/Essentials/Vector2")

function Button:new(name, font, pos, size, onClick)
	self.name = name
	self.font = font
	self.pos = pos
	self.size = size
	
	self.hovered = false
	self.onClick = onClick
	-- self.buttons = {
		-- {name = "Copy error data to clipboard", hovered = false, pos = Vec2(30, 520), size = Vec2(360, 25)},
		-- {name = "Report crash and copy error data", hovered = false, pos = Vec2(410, 520), size = Vec2(360, 25)},
		-- {name = "Emergency save", hovered = false, pos = Vec2(30, 550), size = Vec2(360, 25)},
		-- {name = "Exit without saving", hovered = false, pos = Vec2(410, 550), size = Vec2(360, 25)}
	-- }
end

function Button:update(dt)
	self.hovered = mousePos.x > self.pos.x and
					mousePos.x < self.pos.x + self.size.x and
					mousePos.y > self.pos.y and
					mousePos.y < self.pos.y + self.size.y
end

function Button:draw()
	-- Button hovering
	love.graphics.setFont(self.font)
	love.graphics.setLineWidth(1)
	if self.hovered then
		love.graphics.setColor(0.8, 0.8, 0.8)
	else
		love.graphics.setColor(0.4, 0.4, 0.4)
	end
	love.graphics.rectangle("fill", self.pos.x, self.pos.y, self.size.x, self.size.y)
	love.graphics.setColor(0.2, 0.2, 0.2)
	love.graphics.rectangle("line", self.pos.x, self.pos.y, self.size.x, self.size.y)
	love.graphics.setColor(0, 0, 0)
	love.graphics.print(self.name, self.pos.x + 4, self.pos.y + 2)
end



function Button:mousereleased(x, y, button)
	if self.hovered then
		self.onClick()
	end
end

return Button