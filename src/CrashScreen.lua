local class = require "com/class"
local CrashScreen = class:derive("CrashScreen")

local Vec2 = require("src/Essentials/Vector2")

function CrashScreen:new(err)
	-- error message
	self.err = err
	
	-- prepare fonts of various sizes
	self.font = love.graphics.newFont()
	self.fontMed = love.graphics.newFont(14)
	self.fontBig = love.graphics.newFont(18)
	self.fontGiant = love.graphics.newFont(30)
	
	-- button data
	self.buttons = {
		{name = "Copy error data to clipboard", hovered = false, pos = Vec2(30, 520), size = Vec2(360, 25)},
		{name = "Report crash and copy error data", hovered = false, pos = Vec2(410, 520), size = Vec2(360, 25)},
		{name = "Emergency save", hovered = false, pos = Vec2(30, 550), size = Vec2(360, 25)},
		{name = "Exit without saving", hovered = false, pos = Vec2(410, 550), size = Vec2(360, 25)}
	}
	self.url = "https://github.com/jakubg1/OpenSMCE/issues"
	
	
	
	if math.random() <3 then
		pcall(function()
			local sound = love.audio.newSource("assets/crash.wav", "static")
			sound:play()
		end)
	end
end

function CrashScreen:update(dt)
	mousePos = Vec2(love.mouse.getPosition())
	
	-- URL hover
	for i, button in ipairs(self.buttons) do
		button.hovered = mousePos.x > button.pos.x and
						mousePos.x < button.pos.x + button.size.x and
						mousePos.y > button.pos.y and
						mousePos.y < button.pos.y + button.size.y
	end
end

function CrashScreen:draw()
	-- White color
	love.graphics.setColor(1, 1, 1)
	
	-- Header
	love.graphics.setFont(self.fontGiant)
	love.graphics.print("Oh no!", 30, 30)
	-- Text
	love.graphics.setFont(self.fontMed)
	love.graphics.print("OpenSMCE encountered a problem and crashed.\nThis is not meant to happen and you should report this error to the Github repository page\n(unless you caused the crash, of course).\nYou can try to emergency save the progress, in order to not lose it.\n\nHere's some error info:", 30, 70)
	
	-- Yellow color
	love.graphics.setColor(1, 1, 0)
	
	-- Error text
	love.graphics.setFont(self.font)
	love.graphics.print(self.err, 30, 180)
	
	-- Button hovering
	love.graphics.setFont(self.fontBig)
	love.graphics.setLineWidth(1)
	for i, button in ipairs(self.buttons) do
		if button.hovered then
			love.graphics.setColor(0.8, 0.8, 0.8)
		else
			love.graphics.setColor(0.4, 0.4, 0.4)
		end
		love.graphics.rectangle("fill", button.pos.x, button.pos.y, button.size.x, button.size.y)
		love.graphics.setColor(0.2, 0.2, 0.2)
		love.graphics.rectangle("line", button.pos.x, button.pos.y, button.size.x, button.size.y)
		love.graphics.setColor(0, 0, 0)
		love.graphics.print(button.name, button.pos.x + 15, button.pos.y + 1)
	end
end



function CrashScreen:mousepressed(x, y, button)
	-- STUB
end

function CrashScreen:mousereleased(x, y, button)
	-- URL
	for i, buttonW in ipairs(self.buttons) do
		if buttonW.hovered then
			if i == 1 then
				love.system.setClipboardText(self.err)
			elseif i == 2 then
				love.system.setClipboardText(self.err)
				love.system.openURL(self.url)
			elseif i == 3 then
				love.event.quit()
			elseif i == 4 then
				love.event.quit()
			end
		end
	end
end

function CrashScreen:keypressed(key)
	-- STUB
end

function CrashScreen:keyreleased(key)
	-- STUB
end

return CrashScreen