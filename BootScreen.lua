local class = require "class"
local BootScreen = class:derive("BootScreen")

function BootScreen:new()
	-- make the boot screen font bigger
	love.graphics.setFont(love.graphics.newFont(18))
	-- github url link
	self.url = "https://github.com/jakubg1/opensmce"
	self.urlHovered = false
end

function BootScreen:update(dt)
	self.urlHovered = mousePos.x > 25 and mousePos.x < 400 and mousePos.y > 267 and mousePos.y < 292
end

function BootScreen:draw()
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("OpenSMCE Boot Menu", 30, 30)
	love.graphics.print("Version " .. VERSION, 500, 30)
	love.graphics.print("Notes:", 45, 75)
	love.graphics.print("Welcome to this brand new simple boot screen!\nA lot of things will be changed.\nThis engine is still in development!\nIf you have any bugs or suggestions, head on to Forum or Discord!\n\nOpenSMCE is a short for Open-Source Sphere Matcher Community Engine.\n\nSee our GitHub page:\n" .. self.url, 45, 100)
	love.graphics.print("This is the first beta release of the engine!", 30, 320)
	love.graphics.print("If you didn't do so yet, please read the readme!\nThank you for support!\n~jakubg1", 30, 350)
	love.graphics.print("Press Enter to start game \"" .. GAME_NAME .. "\".", 30, 480)
	love.graphics.print("Game selection screen coming soon!", 30, 510)
	
	if self.urlHovered then
		love.graphics.setColor(1, 1, 0)
	else
		love.graphics.setColor(0.4, 0.4, 0)
	end
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", 25, 267, 375, 25)
	if self.urlHovered then
		love.graphics.print("<--- Click here to open the page!", 420, 275, 0.1)
	end
end



function BootScreen:mousepressed(x, y, button)
	-- STUB
end

function BootScreen:mousereleased(x, y, button)
	if self.urlHovered then
		love.system.openURL(self.url)
	end
end

function BootScreen:keypressed(key)
	if key == "return" then loadGame(GAME_NAME) end
end

function BootScreen:keyreleased(key)
	-- STUB
end

return BootScreen