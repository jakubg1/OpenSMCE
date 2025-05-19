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
	self.tabCompletionOffset = 0
	self.tabCompletionSelection = 0
	self.MAX_TAB_COMPLETION_SUGGESTIONS = 10

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
			elseif self.keyRepeat == "pageup" then
				self:inputPageUp()
			elseif self.keyRepeat == "pagedown" then
				self:inputPageDown()
			elseif self.keyRepeat == "tab" then
				self:inputTab()
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
---If no suggestions are available, the suggestions are disabled.
function Console:updateTabCompletionList()
	self.tabCompletionList = _Debug:getCommandCompletionSuggestions(self.command)
	if #self.tabCompletionList == 0 then
		-- No suggestions.
		self.tabCompletionList = nil
		return
	end
	self.tabCompletionSelection = 1
	self:updateTabCompletionScroll()
end

---Updates the scroll offset of the completion suggestion list.
function Console:updateTabCompletionScroll()
	-- We treat no selection as 1.
	local virtualSelection = math.max(self.tabCompletionSelection, 1)
	if virtualSelection < self.tabCompletionOffset + 1 then
		-- If the current selection is above the viewable area, bring the viewable area up.
		self.tabCompletionOffset = virtualSelection - 1
	elseif virtualSelection > self.tabCompletionOffset + self.MAX_TAB_COMPLETION_SUGGESTIONS then
		-- If the current selection is below the viewable area, bring the viewable area down.
		self.tabCompletionOffset = virtualSelection - self.MAX_TAB_COMPLETION_SUGGESTIONS
	end
end

---Returns the currently being typed-in command without the last word.
---If at least one word remains, a space character will be appended at the end of the string.
---@return string
function Console:getCommandWithoutLastWord()
	local words = _Utils.strSplit(self.command, " ")
	table.remove(words, #words)
	local command = _Utils.strJoin(words, " ")
	if command ~= "" then
		command = command .. " "
	end
	return command
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
		local a = self.tabCompletionOffset + 1
		local b = math.min(a + self.MAX_TAB_COMPLETION_SUGGESTIONS - 1, #self.tabCompletionList)
		local x = pos.x + (utf8.len(self:getCommandWithoutLastWord()) + 2) * 8
		local y = pos.y - 25 - (b - a + 1) * 20
		local width = 150
		for i, completion in ipairs(self.tabCompletionList) do
			width = math.max(width, _FONT_CONSOLE:getWidth(completion))
		end
		for i = a, b do
			local completion = self.tabCompletionList[i]
			local color = self.tabCompletionSelection == i and _COLORS.white or _COLORS.white
			local backgroundColor = self.tabCompletionSelection == i and _COLORS.darkAqua or _COLORS.black
			_Debug:drawVisibleText({color, completion}, Vec2(x, y + (i - a) * 20), 20, width, nil, true, backgroundColor)
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
		elseif key == "tab" then
			self:inputTab()
		elseif key == "up" then
			self:inputUp()
		elseif key == "down" then
			self:inputDown()
		elseif key == "pageup" then
			self:inputPageUp()
		elseif key == "pagedown" then
			self:inputPageDown()
		elseif key == "escape" then
			self.tabCompletionList = nil
		elseif key == "return" then
			self:inputEnter()
		end
		self.keyRepeat = key
		self.keyRepeatTime = self.KEY_FIRST_REPEAT_TIME
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
	if not self.active then
		return
	end
	self.command = self.command .. t
	self:updateTabCompletionList()
end

function Console:inputBackspace()
	if not self.active then
		return
	end
	local offset = utf8.offset(self.command, -1)
	if offset then
		self.command = self.command:sub(1, offset - 1)
		self:updateTabCompletionList()
	end
end

function Console:inputUp()
	if self.tabCompletionList then
		self.tabCompletionSelection = (self.tabCompletionSelection - 2) % #self.tabCompletionList + 1
		self:updateTabCompletionScroll()
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
		self.tabCompletionSelection = self.tabCompletionSelection % #self.tabCompletionList + 1
		self:updateTabCompletionScroll()
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

function Console:inputPageUp()
	if self.tabCompletionList then
		self.tabCompletionSelection = math.max(1, self.tabCompletionSelection - self.MAX_TAB_COMPLETION_SUGGESTIONS)
		self:updateTabCompletionScroll()
	end
end

function Console:inputPageDown()
	if self.tabCompletionList then
		self.tabCompletionSelection = math.min(#self.tabCompletionList, self.tabCompletionSelection + self.MAX_TAB_COMPLETION_SUGGESTIONS)
		self:updateTabCompletionScroll()
	end
end

function Console:inputTab()
	if not self.tabCompletionList then
		self:updateTabCompletionList()
	elseif #self.tabCompletionList == 0 then
		return
	else
		local commandStripped = self:getCommandWithoutLastWord()
		if self.tabCompletionSelection == 0 or self.command == commandStripped .. self.tabCompletionList[self.tabCompletionSelection] then
			-- Move through the suggestions.
			self.tabCompletionSelection = self.tabCompletionSelection % #self.tabCompletionList + 1
			self:updateTabCompletionScroll()
		end
		-- Autofill the suggestion.
		self.command = commandStripped .. self.tabCompletionList[self.tabCompletionSelection]
	end
end

function Console:inputEnter()
	-- Do nothing if there's no input.
	if self.command == "" then
		return
	end

	local success, err = xpcall(function() return _Debug:runCommand(self.command) end, debug.traceback)
	if not success and err then
		self:print({_COLORS.lightRed, "An error has occurred while executing command: " .. self.command})
		self:print({_COLORS.lightRed, _Utils.strSplit(err, "\n")[1]})
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
	self.tabCompletionList = nil
end

return Console
