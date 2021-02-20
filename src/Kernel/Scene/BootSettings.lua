local class = require "com/class"
local BootSettings = class:derive("BootSettings")

local Vec2 = require("src/Essentials/Vector2")
local Button = require("src/Kernel/UI/Button")



function BootSettings:new(bootScreen)
  self.bootScreen = bootScreen

	-- prepare fonts of various sizes
	self.font = love.graphics.newFont()
	self.fontBig = love.graphics.newFont(18)

	-- buttons
	self.menuBtn = Button("Go Back", self.fontBig, Vec2(30, 546), Vec2(300, 24), function() self.bootScreen:setScene("main") end)
end



function BootSettings:update(dt)
	-- buttons
	self.menuBtn:update(dt)
end



function BootSettings:draw()
	-- White color
	love.graphics.setColor(1, 1, 1)

	-----------------------------
	-- HEADER
	-----------------------------
	love.graphics.setFont(self.fontBig)
	love.graphics.print("OpenSMCE Boot Menu", 30, 30)
	love.graphics.print(string.format("Version: %s (%s)", VERSION_NAME, VERSION), 520, 30)

	-----------------------------
	-- SETTING LIST
	-----------------------------
	love.graphics.print("Settings", 30, 70)
	love.graphics.setColor(1, 1, 1)
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 30, 100, 740, 200) -- frame

	-----------------------------
	-- GO BACK BUTTON
	-----------------------------
	self.menuBtn:draw()

end



function BootSettings:mousereleased(x, y, button)
	-- Buttons
	self.menuBtn:mousereleased(x, y, button)
end



return BootSettings
