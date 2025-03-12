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
	self.tabCompletionList = nil
	self.tabCompletionOffset = nil
	self.tabCompletionSelection = 0

	self.open = false
	self.active = false

	self.keyRepeat = nil
	self.KEY_FIRST_REPEAT_TIME = 0.5
	self.KEY_NEXT_REPEAT_TIME = 0.05
	self.keyRepeatTime = 0

	self.MAX_MESSAGES = 20
end

function Console:update(dt)
	if self.keyRepeat then
		self.keyRepeatTime = self.keyRepeatTime - dt
		if self.keyRepeatTime <= 0 then
			self.keyRepeatTime = self.KEY_NEXT_REPEAT_TIME
			if self.keyRepeat == "backspace" then
				self:inputBackspace()
			elseif self.keyRepeat == "up" then
				self:inputUp()
			elseif self.keyRepeat == "down" then
				self:inputDown()
			end
		end
	else
		self.keyRepeatTime = self.KEY_FIRST_REPEAT_TIME
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

function Console:toggleOpen()
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
		self.command = self.history[n] or ""
	else
		self.command = self.commandBuffer
		self.commandBuffer = nil
	end
	self.historyOffset = n
	--print("Scrolled to " .. tostring(n))
end

---Updates the list of completion suggestions.
function Console:updateTabCompletionList()
	self.tabCompletionList = _Debug:getCommandCompletionSuggestions(self.command)
	self.tabCompletionSelection = 0
end

function Console:draw()
	local pos = Vec2(5, _Display.size.y)
	local size = Vec2(600, 200)

	-- History
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

	-- Input box
	if self.open then
		local text = "> " .. self.command
		if self.active and _TotalTime % 1 < 0.5 then text = text .. "_" end
		_Debug:drawVisibleText(text, pos - Vec2(0, 25), 20, size.x, 1, true)
	end

	-- Tab completion
	if self.open and self.tabCompletionList then
		local x = pos.x + (utf8.len(self.command) + 2) * 8
		local y = pos.y - 25 - #self.tabCompletionList * 20
		for i, completion in ipairs(self.tabCompletionList) do
			local color = self.tabCompletionSelection == i and _COLORS.yellow or _COLORS.white
			local backgroundColor = self.tabCompletionSelection == i and _COLORS.gray or _COLORS.black
			_Debug:drawVisibleText({color, completion}, Vec2(x, y + (i - 1) * 20), 20, 150, nil, true, backgroundColor)
		end
	end

	love.graphics.setFont(_FONT)
end



function Console:keypressed(key)
	-- the shortcut is Ctrl + `
	if key == "`" and (_KeyModifiers["lctrl"] or _KeyModifiers["rctrl"]) then
		self:toggleOpen()
	end
	if self.active then
		if key == "v" and (_KeyModifiers["lctrl"] or _KeyModifiers["rctrl"]) then
			self:inputCharacter(love.system.getClipboardText())
		end
		if key == "backspace" then
			self:inputBackspace()
			self.keyRepeat = "backspace"
			self.keyRepeatTime = self.KEY_FIRST_REPEAT_TIME
		elseif key == "tab" then
			self:inputTab()
		elseif key == "up" then
			self:inputUp()
			self.keyRepeat = "up"
			self.keyRepeatTime = self.KEY_FIRST_REPEAT_TIME
		elseif key == "down" then
			self:inputDown()
			self.keyRepeat = "down"
			self.keyRepeatTime = self.KEY_FIRST_REPEAT_TIME
		elseif key == "escape" then
			self.tabCompletionList = nil
		elseif key == "return" then
			self:inputEnter()
		end
	end
end

function Console:keyreleased(key)
	if key == self.keyRepeat then
		self.keyRepeat = nil
	end
end

function Console:textinput(t)
	self:inputCharacter(t)
end



function Console:inputCharacter(t)
	if not self.active then return end
	self.command = self.command .. t
	self:updateTabCompletionList()
end

function Console:inputBackspace()
	if not self.active then return end
	local offset = utf8.offset(self.command, -1)
	if offset then
		self.command = self.command:sub(1, offset - 1)
		self:updateTabCompletionList()
	end
end

function Console:inputUp()
	if self.tabCompletionList then
		self.tabCompletionSelection = math.max(1, self.tabCompletionSelection - 1)
	else
		if self.historyOffset then
			self:scrollToHistoryEntry(math.max(1, self.historyOffset - 1))
		else
			self:scrollToHistoryEntry(#self.history)
		end
	end
end

function Console:inputDown()
	if self.tabCompletionList then
		self.tabCompletionSelection = math.min(#self.tabCompletionList, self.tabCompletionSelection + 1)
	else
		if self.historyOffset then
			if self.historyOffset < #self.history then
				self:scrollToHistoryEntry(self.historyOffset + 1)
			else
				self:scrollToHistoryEntry()
			end
		end
	end
end

function Console:inputTab()
	if not self.tabCompletionList then
		self:updateTabCompletionList()
	elseif #self.tabCompletionList == 0 then
		return
	elseif self.tabCompletionSelection == 0 then
		self.tabCompletionSelection = 1
	else
		-- Autofill the suggestion.
		local words = _Utils.strSplit(self.command, " ")
		table.remove(words, #words)
		self.command = _Utils.strJoin(words, " ")
		if self.command ~= "" then
			self.command = self.command .. " "
		end
		self.command = self.command .. self.tabCompletionList[self.tabCompletionSelection]
	end
end

function Console:inputEnter()
	-- Do nothing if there's no input.
	if self.command == "" then
		return
	end

	local success, err = xpcall(function() return _Debug:runCommand(self.command) end, debug.traceback)
	if not success and err then
		self:print({{1, 0.4, 0.4}, "An error has occured when executing a command: " .. self.command})
		self:print({{1, 0.4, 0.4}, _Utils.strSplit(err, "\n")[1]})
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

	if self.command ~= self.history[#self.history] then
		table.insert(self.history, self.command)
	end
	self.historyOffset = nil
	self.command = ""
	self.commandBuffer = nil
	self.tabCompletionList = {}
end

return Console
