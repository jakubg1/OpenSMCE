local class = require "com.class"

---The console window serves as a debugging input/output system.
---@class Console
---@overload fun():Console
local Console = class:derive("Console")

local utf8 = require("utf8")

---Constructs the Console.
---@private
function Console:new()
	-- NOTE: Y position is recalculated each frame in `:draw()` because the console is brought down to the bottom of the window.
	self.x, self.y = 0, 0
	self.w, self.h = 600, 200
	self.font = love.graphics.getFont()

	---@type {text: string, time: number}[]
	self.output = {}
	self.outputOffset = 0
	---@type string[]
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

---Updates the console. Handles key repeat timing.
---@param dt number Time delta in seconds.
function Console:_update(dt)
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

---Prints a message to the console.
---@param message any? The message to be sent. If it's not a string or a formatted string (table), `tostring` will be implicitly used first.
function Console:print(message)
	if type(message) ~= "string" and type(message) ~= "table" then
		message = tostring(message)
	end
	table.insert(self.output, {text = message, time = _TotalTime})
	-- When browsing the command history, don't drag previous messages from under our feet.
	if self.outputOffset > 0 then
		self:scrollOutputHistory(self.outputOffset + 1)
	end
end

---Sets whether the console is currently open.
---@param open boolean Whether the console should be now open.
function Console:setOpen(open)
	self.open = open
	self.active = open
	if not open then
		self.tabCompletionList = nil
	end
end

---Toggles whether the console is currently open.
function Console:toggleOpen()
	self:setOpen(not self.open)
end

---Sets the font to be used to draw text in the Console. A monospace font is recommended.
---@param font love.Font A LOVE2D font object to be used as the console font.
function Console:setFont(font)
	self.font = font
end

---Scrolls the console output to the provided amount of lines back.
---Makes sure that the output is not scrolled out of bounds.
---@private
---@param offset integer The amount of lines back from the most recent line to be scrolled to.
function Console:scrollOutputHistory(offset)
	self.outputOffset = math.max(math.min(offset, #self.output - self.MAX_MESSAGES), 0)
end

---Scrolls the console input to the given history entry.
---If no history entry was being viewed until now, stores the command being currently typed in a buffer so it's not lost.
---That command is restored when you exit the history (call the function without the parameter).
---@private
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
---@private
function Console:updateTabCompletionList()
	self.tabCompletionList = self:getCommandCompletionSuggestions(self.command)
	if #self.tabCompletionList == 0 then
		-- No suggestions.
		self.tabCompletionList = nil
		return
	end
	self.tabCompletionSelection = 1
	self:updateTabCompletionScroll()
end

---Updates the scroll offset of the completion suggestion list.
---@private
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
---@private
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

---Returns a list of Tab completion suggestions for the current command.
---@private
---@param command string The incomplete command. The suggestions will be provided for the last word.
---@return table
function Console:getCommandCompletionSuggestions(command)
	local suggestions = {}
	local words = _Utils.strSplit(command, " ")
	if #words == 1 then
		-- First word: provide the suggestions for command names.
		suggestions = _Utils.copyTable(_Debug.commandNames)
	else
		-- Subsequent word: check the command and provide the suggestions for command arguments.
		local commandConfig = _Debug.commands[words[1]]
		if commandConfig then
			local parameter = commandConfig.parameters[#words - 1]
			if parameter then
				if parameter.type == "Collectible" then
					if _Game.resourceManager then
						suggestions = _Game.resourceManager:getResourceList("Collectible")
					end
				elseif parameter.type == "ParticleEffect" then
					if _Game.resourceManager then
						suggestions = _Game.resourceManager:getResourceList("ParticleEffect")
					end
				end
			end
		end
	end

	-- Remove irrelevant suggestions and sort them alphabetically.
	local result = {}
	for i = 1, #suggestions do
		if _Utils.strStartsWith(suggestions[i], words[#words]) then
			table.insert(result, suggestions[i])
		end
	end
	-- If no suggestions are found, loosen the criteria and try finding the string anywhere.
	if #result == 0 then
		for i = 1, #suggestions do
			if _Utils.strContains(suggestions[i], words[#words]) then
				table.insert(result, suggestions[i])
			end
		end
	end
	table.sort(result)
	return result
end

---Draws the Console on the screen.
function Console:_draw()
	-- Bring the console to the bottom of the screen.
	local w, h = love.window.getMode()
	self.y = h

	-- Output
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(self.font)
	local a = math.max(#self.output - self.MAX_MESSAGES - self.outputOffset + 1, 1)
	local b = math.min(a + self.MAX_MESSAGES - 1, #self.output)
	local y = self.y - 25 - (b - a + 1) * 20
	for i = a, b do
		local message = self.output[i]
		local t = _TotalTime - message.time
		if self.open or t < 10 then
			local alpha = 1
			if not self.open then
				alpha = math.min(10 - t, 1)
			end
			_Debug:drawVisibleText(message.text, self.x + 5, y + (i - a) * 20, 20, nil, alpha, true)
		end
	end

	if self.open then
		-- Output scrollbar
		local totalH = self.MAX_MESSAGES * 20
		local scrollH = totalH * math.min(self.MAX_MESSAGES / #self.output, 1)
		local scrollY = totalH * (1 - (self.outputOffset / #self.output)) - scrollH
		love.graphics.setColor(0.8, 0.8, 0.8)
		love.graphics.rectangle("fill", self.x, self.y - 25 - totalH + scrollY, 2, scrollH)

		-- Input box
		local text = "> " .. self.command
		if self.active and _TotalTime % 1 < 0.5 then text = text .. "_" end
		_Debug:drawVisibleText(text, self.x + 5, self.y - 23, 20, self.w, 1, true)

		-- Tab completion
		if self.tabCompletionList then
			local a = self.tabCompletionOffset + 1
			local b = math.min(a + self.MAX_TAB_COMPLETION_SUGGESTIONS - 1, #self.tabCompletionList)
			local x = self.x + 5 + (utf8.len(self:getCommandWithoutLastWord()) + 2) * 8
			local y = self.y - 23 - (b - a + 1) * 20
			local width = 150
			for i, completion in ipairs(self.tabCompletionList) do
				width = math.max(width, self.font:getWidth(completion))
			end
			for i = a, b do
				local completion = self.tabCompletionList[i]
				local color = self.tabCompletionSelection == i and _COLORS.white or _COLORS.white
				local backgroundColor = self.tabCompletionSelection == i and _COLORS.sky or _COLORS.black
				_Debug:drawVisibleText({color, completion}, x, y + (i - a) * 20, 20, width, nil, true, backgroundColor)
			end
		end
	end

	love.graphics.setFont(_FONT)
end

---LOVE2D callback for when the mouse wheel is scrolled.
---@param x integer Scroll distance on X axis.
---@param y integer Scroll distance on Y axis.
function Console:_wheelmoved(x, y)
	if not self.active then
		return
	end
	self:scrollOutputHistory(self.outputOffset + y * 3)
end

---LOVE2D callback for when a key is pressed.
---@param key string The key which has been pressed.
function Console:_keypressed(key)
	-- the shortcut is Ctrl + `
	if key == "`" and (_KeyModifiers["lctrl"] or _KeyModifiers["rctrl"]) then
		self:toggleOpen()
	end
	if not self.active then
		return
	end
	if key == "v" and (_KeyModifiers["lctrl"] or _KeyModifiers["rctrl"]) then
		self:inputText(love.system.getClipboardText())
	elseif key == "backspace" then
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

---LOVE2D callback for when a key was released.
---@param key string The key that was released.
function Console:_keyreleased(key)
	if key == self.keyRepeat then
		self.keyRepeat = nil
	end
end

---LOVE2D callback for when a character was inputted.
---@param t string The character which was inputted.
function Console:_textinput(t)
	self:inputText(t)
end

---Adds the provided string to the current command buffer.
---@private
---@param text string The text to be added.
function Console:inputText(text)
	if not self.active then
		return
	end
	self.command = self.command .. text
	self:updateTabCompletionList()
end

---Removes the last character from the current command buffer.
---@private
function Console:inputBackspace()
	if not self.active then
		return
	end
	local offset = utf8.offset(self.command, -1)
	if offset then
		self.command = self.command:sub(1, offset - 1)
		if self.command ~= "" then
			self:updateTabCompletionList()
		else
			-- Hide the tab completion list when we've cleared the entire command.
			self.tabCompletionList = nil
		end
	end
end

---Handles the pressing of the up arrow on the keyboard.
---Srolls the command history or the tab completion list, depending on whether the tab completion list is visible.
---@private
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

---Handles the pressing of the down arrow on the keyboard.
---Srolls the command history or the tab completion list, depending on whether the tab completion list is visible.
---@private
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

---Handless the pressing of the Page Up key on the keyboard.
---Scrolls the tab completion list by one page.
---@private
function Console:inputPageUp()
	if self.tabCompletionList then
		self.tabCompletionSelection = math.max(1, self.tabCompletionSelection - self.MAX_TAB_COMPLETION_SUGGESTIONS)
		self:updateTabCompletionScroll()
	end
end

---Handless the pressing of the Page Down key on the keyboard.
---Scrolls the tab completion list by one page.
---@private
function Console:inputPageDown()
	if self.tabCompletionList then
		self.tabCompletionSelection = math.min(#self.tabCompletionList, self.tabCompletionSelection + self.MAX_TAB_COMPLETION_SUGGESTIONS)
		self:updateTabCompletionScroll()
	end
end

---Handless the pressing of the Tab key on the keyboard.
---Brings up the tab completion list and provides autofill.
---@private
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

---Handles the pressing of Enter on the keyboard.
---Runs the command and catches any errors which could happen.
---@private
function Console:inputEnter()
	-- Do nothing if there's no input.
	if self.command == "" then
		return
	end

	-- Run the command and handle any error which could happen during its execution.
	local success, err = xpcall(function() return _Debug:runCommand(self.command) end, debug.traceback)
	if not success and err then
		self:print({_COLORS.lightRed, "An error has occurred while executing command: " .. self.command})
		self:print({_COLORS.lightRed, _Utils.strSplit(err, "\n")[1]})
		_Log:printt("CONSOLE", "Full Error:")
		_Log:printt("CONSOLE", err)
	end

	-- We need to bypass the crash function somehow.
	if success and err == "crash" then
		error(_Debug:getWitty())
	end

	-- Add the command to the history (if it's distinct from the last one) and clears the buffers.
	if self.command ~= self.history[#self.history] then
		table.insert(self.history, self.command)
	end
	self.historyOffset = nil
	self.command = ""
	self.commandBuffer = nil
	self.tabCompletionList = nil
end

return Console
