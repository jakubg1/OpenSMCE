local class = require "com/class"

---@class Console
---@overload fun():Console
local Console = class:derive("Console")

local Vec2 = require("src/Essentials/Vector2")



function Console:new()
	self.history = {}
	self.command = ""

	self.open = false
	self.active = false

	self.backspace = false
	self.BACKSPACE_FIRST_REPEAT_TIME = 0.5
	self.BACKSPACE_NEXT_REPEAT_TIME = 0.05
	self.backspaceTime = 0

	self.MAX_MESSAGES = 20

	self.font = love.graphics.newFont()
	self.consoleFont = love.graphics.newFont("unifont.ttf", 16)
end

function Console:update(dt)
	if self.backspace then
		self.backspaceTime = self.backspaceTime - dt
		if self.backspaceTime <= 0 then
			self.backspaceTime = self.BACKSPACE_NEXT_REPEAT_TIME
			self:inputBackspace()
		end
	else
		self.backspaceTime = self.BACKSPACE_FIRST_REPEAT_TIME
	end
end

function Console:print(message)
	if type(message) ~= "string" and type(message) ~= "table" then
		message = tostring(message)
	end
	table.insert(self.history, {text = message, time = _TotalTime})
	_Log:printt("CONSOLE", _StrUnformat(message))
end

function Console:setOpen(open)
	self.open = open
	self.active = open
end

function Console:toggleOpen(open)
	self:setOpen(not self.open)
end

function Console:draw()
	local pos = Vec2(5, _DisplaySize.y)
	local size = Vec2(600, 200)

	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(self.consoleFont)
	for i = 1, self.MAX_MESSAGES do
		local pos = pos - Vec2(0, 30 + 20 * i)
		local message = self.history[#self.history - i + 1]
		if message then
			local t = _TotalTime - message.time
			if self.open or t < 10 then
				local a = 1
				if not self.open then
					a = math.min(10 - t, 1)
				end
				_Debug:drawVisibleText(message.text, pos, 20, nil, a)
			end
		end
	end

	if self.open then
		local text = "> " .. self.command
		if self.active and _TotalTime % 1 < 0.5 then text = text .. "_" end
		_Debug:drawVisibleText(text, pos - Vec2(0, 25), 20, size.x)
	end
	love.graphics.setFont(self.font)
end



function Console:keypressed(key)
	-- the shortcut is Ctrl + `
	if key == "`" and (_KeyModifiers["lctrl"] or _KeyModifiers["rctrl"]) then
		self:toggleOpen()
	end
	if self.active then
		if key == "backspace" then
			self:inputBackspace()
			self.backspace = true
		end
		if key == "return" then
			self:inputEnter()
		end
	end
end

function Console:keyreleased(key)
	if key == "backspace" then
		self.backspace = false
	end
end

function Console:textinput(t)
	self:inputCharacter(t)
end



function Console:inputCharacter(t)
	if not self.active then return end
	self.command = self.command .. t
end

function Console:inputBackspace()
	if not self.active then return end
	self.command = self.command:sub(1, -2)
end

function Console:inputEnter()
	local success = _Debug:runCommand(self.command)
	if not success then self:print("Invalid command!") end
	self.command = ""
end

return Console
