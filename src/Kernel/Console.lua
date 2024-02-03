local class = require "com.class"

---@class Console
---@overload fun():Console
local Console = class:derive("Console")

local utf8 = require("utf8")
local Vec2 = require("src.Essentials.Vector2")



function Console:new()
	self.output = {}
	self.history = {}
	self.historyOffset = nil
	self.command = ""
	self.commandBuffer = nil -- Stores the newest non-submitted command if the history is being browsed.

	self.open = false
	self.active = false

	self.backspace = false
	self.BACKSPACE_FIRST_REPEAT_TIME = 0.5
	self.BACKSPACE_NEXT_REPEAT_TIME = 0.05
	self.backspaceTime = 0

	self.MAX_MESSAGES = 20
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
	table.insert(self.output, {text = message, time = _TotalTime})
	_Log:printt("CONSOLE", _Utils.strUnformat(message))
end

function Console:setOpen(open)
	self.open = open
	self.active = open
end

function Console:toggleOpen(open)
	self:setOpen(not self.open)
end

---Scrolls the console input to the given history entry.
---If no history entry was being viewed until now, stores the command being currently typed in a buffer so it's not lost.
---That command is restored when you exit the history (call the function without the parameter).
---@param n integer? The history entry to be scrolled to, or `nil` to exit history and go back to the previously typed line.
function Console:scrollToHistoryEntry(n)
	if self.historyOffset == n then
		return
	end
	-- Save the command if we start browsing history.
	if not self.historyOffset then
		self.commandBuffer = self.command
	end
	if n then
		self.command = self.history[n]
	else
		self.command = self.commandBuffer
		self.commandBuffer = nil
	end
	self.historyOffset = n
	--print("Scrolled to " .. tostring(n))
end

function Console:draw()
	local pos = Vec2(5, _DisplaySize.y)
	local size = Vec2(600, 200)

	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(_FONT_CONSOLE)
	for i = 1, self.MAX_MESSAGES do
		local pos = pos - Vec2(0, 30 + 20 * i)
		local message = self.output[#self.output - i + 1]
		if message then
			local t = _TotalTime - message.time
			if self.open or t < 10 then
				local a = 1
				if not self.open then
					a = math.min(10 - t, 1)
				end
				_Debug:drawVisibleText(message.text, pos, 20, nil, a, true)
			end
		end
	end

	if self.open then
		local text = "> " .. self.command
		if self.active and _TotalTime % 1 < 0.5 then text = text .. "_" end
		_Debug:drawVisibleText(text, pos - Vec2(0, 25), 20, size.x, a, true)
	end
	love.graphics.setFont(_FONT)
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
		elseif key == "up" then
			if self.historyOffset then
				self:scrollToHistoryEntry(math.max(1, self.historyOffset - 1))
			else
				self:scrollToHistoryEntry(#self.history)
			end
		elseif key == "down" then
			if self.historyOffset then
				if self.historyOffset < #self.history then
					self:scrollToHistoryEntry(self.historyOffset + 1)
				else
					self:scrollToHistoryEntry()
				end
			end
		elseif key == "return" then
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
	local offset = utf8.offset(self.command, -1)
	if offset then
		self.command = self.command:sub(1, offset - 1)
	end
end

function Console:inputEnter()
	local success, err = xpcall(function() return _Debug:runCommand(self.command) end, debug.traceback)
	if not success and err then
		self:print({{1, 0.2, 0.2}, "An error has occured when executing a command:"})
		self:print({{1, 0.2, 0.2}, _Utils.strSplit(err, "\n")[1]})
		_Log:printt("CONSOLE", "Full Error:")
		_Log:printt("CONSOLE", err)
	end

	-- We need to bypass the crash function somehow.
	if success and err == "crash" then
		local s, witty = pcall(_Debug.getWitty)
		if not s or not witty then
			witty = "Boring manual crash"
		end
		error(witty)
	end

	table.insert(self.history, self.command)
	self.historyOffset = nil
	self.command = ""
	self.commandBuffer = nil
end

return Console
