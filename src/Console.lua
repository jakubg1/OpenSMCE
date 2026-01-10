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
	self.width, self.height = 600, 200
	self.scale = 1
	self.font = love.graphics.getFont()
	self.colors = {
		background = {0, 0, 0},
		helpHeader = {1, 0.2, 1},
		command = {1, 1, 0.2},
		commandParameter = {0.3, 1, 1},
		commandDescription = {1, 1, 1},
		error = {1, 0.4, 0.2},
		completion = {1, 1, 1},
		completionBackground = {0, 0, 0},
		selectedCompletion = {1, 1, 1},
		selectedCompletionBackground = {0.1, 0.4, 0.7}
	}
	---@alias Command {description: string, parameters: CommandParameter[], fn: function?, caller: any?}
	---@alias CommandParameter {name: string, type: string, optional: boolean?, greedy: boolean?, subcommands: Command[]?}
	---@type table<string, Command>
	self.commands = {
		help = {
			description = "Displays a list of available commands.",
			parameters = {},
			fn = self.displayHelp,
			caller = self
		}
	}

	---@type {text: string, time: number}[]
	self.output = {}
	self.outputOffset = 0
	self.MAX_MESSAGES = 20
	---@type string[]
	self.history = {}
	self.historyOffset = nil
	self.command = ""
	self.commandBuffer = nil -- Stores the newest non-submitted command if the history is being browsed.
	self.tabCompletionList = nil
	self.tabCompletionOffset = 0
	self.tabCompletionSelection = 0
	self.MAX_TAB_COMPLETION_SUGGESTIONS = 10

	self.time = 0
	self.open = false
	self.active = false

	self.keyRepeat = nil
	self.KEY_FIRST_REPEAT_TIME = 0.5
	self.KEY_NEXT_REPEAT_TIME = 0.02
	self.keyRepeatTime = 0
end

---Updates the console. Handles key repeat timing and message fadeout.
---@param dt number Time delta in seconds.
function Console:update(dt)
	self.time = self.time + dt
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
	local lines = _Utils.tableIsCtext(message) and _Utils.ctextSplit(message, "\n") or _Utils.strSplit(message, "\n")
	for i, line in ipairs(lines) do
		table.insert(self.output, {text = line, time = self.time})
	end
	-- When browsing the command history, don't drag previous messages from under our feet.
	if self.outputOffset > 0 then
		self:scrollOutputHistory(self.outputOffset + #lines)
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

---Returns whether the console is currently open.
---@return boolean
function Console:isOpen()
	return self.open
end

---Sets the width of the Console. This includes both the input box and the output background.
---@param width number The width, in pixels.
function Console:setWidth(width)
	self.width = width
end

---Sets the scale of the Console.
---@param scale number The new scale of the Console. 1 is natural size.
function Console:setScale(scale)
	self.scale = scale
end

---Sets the font to be used to draw text in the Console. A monospace font is recommended.
---@param font love.Font A LOVE2D font object to be used as the console font.
function Console:setFont(font)
	self.font = font
end

---Registers a new command for the Console.
---@param name string The command name. You can also make subcommands by using spaces, for example `"net connect"`.
---@param description string The command description, seen in the output of `help` command.
---@param parameters CommandParameter[] A list of command parameters for this command.
---@param fn function? The function to be called when this command is executed. The given parameters will be converted and passed as arguments. If not specified, nothing will happen when the command is executed. Normally that would make the command useless, but it's desirable if you want to set up subcommands.
---@param caller Class? The object on which the function should be called. Use when a class function is passed.
function Console:addCommand(name, description, parameters, fn, caller)
	local subnames = _Utils.strSplit(name, " ")
	if #subnames == 1 then
		-- Add a new command.
		self.commands[name] = {
			description = description,
			parameters = parameters,
			fn = fn,
			caller = caller
		}
	elseif #subnames == 2 then
		-- Add a subcommand to an existing command.
		local command = assert(self.commands[subnames[1]], string.format("Failed to register a command `%s`: The `%s` command must be registered first.", name, subnames[1]))
		local lastParam = command.parameters[#command.parameters]
		assert(lastParam and lastParam.type == "string", string.format("Failed to register a command `%s`: The last parameter of the `%s` command must be a string.", name, subnames[1]))
		-- Create a list of subcommands if this is the first subcommand added to the command.
		if not lastParam.subcommands then
			lastParam.subcommands = {}
		end
		lastParam.subcommands[subnames[2]] = {
			description = description,
			parameters = parameters,
			fn = fn,
			caller = caller
		}
	elseif #subnames > 2 then
		-- TODO: Rewrite this code so that multiple layers of depth are supported.
		error(string.format("Failed to register a command `%s`: Multi-layered subcommands are not yet supported.", name))
	end
end

---Parses and executes the provided command.
---@private
---@param command string The command to be executed.
function Console:runCommand(command)
	local words = _Utils.strSplit(command, " ")

	-- Get command data.
	-- This will change in the parsing step to the subcommand data if a subcommand is encountered!
	local commandData = self.commands[words[1]]
	if not commandData then
		self:print({self.colors.error, string.format("Command `%s` not found. Type `help` to see available commands.", words[1])})
		return
	end

	-- Parse and obtain all necessary parameters.
	local parameters = {}
	local paramIndex = 1 -- In the current command data (as this can shift), which parameter is going to be parsed next
	local greed = false -- Whether we've already encountered a greedy parameter - this means all subsequent words will add on to the last parameter
	for i = 2, #words do
		local word = words[i]
		if greed then
			parameters[#parameters] = parameters[#parameters] .. " " .. word
		else
			local parameter = commandData.parameters[paramIndex]
			local success, result = pcall(function() return self:parseCommandParameter(parameter, word) end)
			if success then
				if parameter.subcommands then
					-- This is a subcommand parameter, which means we're going to shift our focus to the selected subcommand.
					commandData = parameter.subcommands[result]
					if not commandData then
						-- An invalid subcommand has been specified. Stop the process.
						self:print({self.colors.error, string.format("Invalid subcommand for `%s`: `%s`", words[1], result)})
						return
					end
					-- Note that we're setting 0 here because this will be incremented by the time the next iteration starts.
					paramIndex = 0
				else
					table.insert(parameters, result)
					if parameter.greedy then
						greed = true
					end
				end
			else
				-- There has been an error. Stop the process.
				self:print({self.colors.error, result})
				return
			end
		end
		paramIndex = paramIndex + 1
	end

	-- Check if we are missing some required parameters.
	for i, parameter in ipairs(commandData.parameters) do
		if parameter.optional then
			break
		end
		if #parameters < i then
			self:print({self.colors.error, string.format("Missing parameter: %s", parameter.name)})
			return
		end
	end

	-- Execute the function.
	local fn = commandData.fn
	if fn then
		local caller = commandData.caller
		if caller then
			return fn(caller, unpack(parameters))
		else
			return fn(unpack(parameters))
		end
	end
end

---Parses the provided command parameter. If the parsing fails, throws an error with a description.
---@private
---@param parameter CommandParameter The manifest for the provided parameter.
---@param raw string The word to be parsed.
---@return any
function Console:parseCommandParameter(parameter, raw)
	if not raw then
		assert(parameter.optional, string.format("Missing parameter: `%s`, expected: %s", parameter.name, parameter.type))
		-- Optional parameters which are not given evaluate to `nil`.
		return nil
	else
		if parameter.type == "number" or parameter.type == "integer" then
			return assert(tonumber(raw), string.format("Failed to convert to number: `%s`, expected: %s", raw, parameter.type))
		elseif parameter.type == "string" then
			return raw
		elseif parameter.type == "Collectible" then
			return _Res:getCollectibleConfig(raw)
		end
	end
end

---Prints a list of all available commands with their descriptions.
---@private
function Console:displayHelp()
	self:print({self.colors.helpHeader, "Available commands:"})
	for i, name in ipairs(self:getCommandList()) do
		local commandData = self.commands[name]
		local msg = {self.colors.command, name}
		for j, parameter in ipairs(commandData.parameters) do
			local name = parameter.name
			if parameter.greedy then
				name = name .. "..."
			end
			table.insert(msg, self.colors.commandParameter)
			if parameter.optional then
				table.insert(msg, string.format(" [%s]", name))
			elseif parameter.subcommands then
				table.insert(msg, string.format(" <%s> ...", name))
			else
				table.insert(msg, string.format(" <%s>", name))
			end
		end
		table.insert(msg, self.colors.commandDescription)
		table.insert(msg, " - " .. commandData.description)
		self:print(msg)
	end
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

---Returns a list of all commands, sorted alphabetically.
---@return string[]
function Console:getCommandList()
	local commandNames = {}
	for commandName, commandData in pairs(self.commands) do
		table.insert(commandNames, commandName)
	end
	table.sort(commandNames)
	return commandNames
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
		suggestions = self:getCommandList()
	else
		-- Subsequent word: check the command and provide the suggestions for command arguments.
		local commandConfig = self.commands[words[1]]
		if commandConfig then
			local parameter = commandConfig.parameters[#words - 1]
			if not parameter then
				-- There is no parameter for our command because we went too far. But maybe there's a subcommand in the process?
				local lastParamConfig = commandConfig.parameters[#commandConfig.parameters]
				if lastParamConfig and lastParamConfig.subcommands then
					-- There is! Check the subcommand.
					--print("Found config for " .. tostring(words[#commandConfig.parameters + 1]))
					commandConfig = lastParamConfig.subcommands[words[#commandConfig.parameters + 1]]
					-- TODO: Continue and possibly untangle the logic (recursive function?)
				end
			end
			if parameter then
				-- TODO: Support all resource types.
				if parameter.type == "Collectible" then
					suggestions = _Res:getResourceList("Collectible")
				elseif parameter.type == "ParticleEffect" then
					suggestions = _Res:getResourceList("ParticleEffect")
				elseif parameter.type == "string" and parameter.subcommands then
					suggestions = _Utils.tableGetSortedKeys(parameter.subcommands)
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

---Draws the Console on the screen.
function Console:draw()
	-- Bring the console to the bottom of the screen.
	local w, h = love.window.getMode()
	self.y = h

	local previousFont = love.graphics.getFont()

	-- Output
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(self.font)
	local lineHeight = (self.font:getHeight() + 2) * self.scale
	local a = math.max(#self.output - self.MAX_MESSAGES - self.outputOffset + 1, 1)
	local b = math.min(a + self.MAX_MESSAGES - 1, #self.output)
	local y = self.y - lineHeight - 5 - (b - a + 1) * lineHeight
	for i = a, b do
		local message = self.output[i]
		local t = self.time - message.time
		if self.open or t < 10 then
			local alpha = 1
			if not self.open then
				alpha = math.min(10 - t, 1)
			end
			self:drawText(message.text, self.x + 5, y + (i - a) * lineHeight, self.width, lineHeight, self.scale, alpha)
		end
	end

	if self.open then
		-- Output scrollbar
		local totalH = self.MAX_MESSAGES * lineHeight
		local scrollH = totalH * math.min(self.MAX_MESSAGES / #self.output, 1)
		local scrollY = totalH * (1 - (self.outputOffset / #self.output)) - scrollH
		love.graphics.setColor(0.8, 0.8, 0.8)
		love.graphics.rectangle("fill", self.x, self.y - lineHeight - 5 - totalH + scrollY, 2, scrollH)

		-- Input box
		local text = "> " .. self.command
		if self.active and self.time % 1 < 0.5 then
			text = text .. "_"
		end
		self:drawText(text, self.x + 5, self.y - lineHeight - 3, self.width, lineHeight, self.scale)

		-- Tab completion
		if self.tabCompletionList then
			local a = self.tabCompletionOffset + 1
			local b = math.min(a + self.MAX_TAB_COMPLETION_SUGGESTIONS - 1, #self.tabCompletionList)
			local x = self.x + 5 + self.font:getWidth("> " .. self:getCommandWithoutLastWord()) * self.scale
			local y = self.y - lineHeight - 3 - (b - a + 1) * lineHeight
			local width = 150
			for i, completion in ipairs(self.tabCompletionList) do
				width = math.max(width, self.font:getWidth(completion))
			end
			for i = a, b do
				local completion = self.tabCompletionList[i]
				local color = self.tabCompletionSelection == i and self.colors.selectedCompletion or self.colors.completion
				local backgroundColor = self.tabCompletionSelection == i and self.colors.selectedCompletionBackground or self.colors.completionBackground
				self:drawText({color, completion}, x, y + (i - a) * lineHeight, width, lineHeight, self.scale, 1, backgroundColor)
			end
		end
	end

	love.graphics.setFont(previousFont)
end

---Draws a text with a semi-transparent background.
---@private
---@param text string|table The text to be drawn.
---@param x number The X position of the text.
---@param y number The Y position of the text.
---@param width number The box width, in pixels.
---@param height number The box height, in pixels.
---@param scale number? Relative scale of text.
---@param alpha number? Transparency of text. 1 is opaque (and default).
---@param backgroundColor table? The background color, black by default.
function Console:drawText(text, x, y, width, height, scale, alpha, backgroundColor)
	scale = scale or 1
	alpha = alpha or 1
	backgroundColor = backgroundColor or self.colors.background

	love.graphics.setColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], 0.7 * alpha)
	love.graphics.rectangle("fill", x - 3 * scale, y, width + 6 * scale, height)
	-- Pad text down a bit.
	y = y + scale
	love.graphics.setColor(0, 0, 0, alpha)
	love.graphics.print(text, x + 2, y + 2, 0, scale)
	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.print(text, x, y, 0, scale)
end

---LOVE2D callback for when the mouse wheel is scrolled.
---@param x integer Scroll distance on X axis.
---@param y integer Scroll distance on Y axis.
function Console:wheelmoved(x, y)
	if not self.active then
		return
	end
	self:scrollOutputHistory(self.outputOffset + y * 3)
end

---LOVE2D callback for when a key is pressed.
---@param key string The key which has been pressed.
function Console:keypressed(key)
	-- the shortcut is Ctrl + `
	if key == "`" and love.keyboard.isDown("lctrl", "rctrl") then
		self:toggleOpen()
	end
	if not self.active then
		return
	end
	if key == "v" and love.keyboard.isDown("lctrl", "rctrl") then
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
function Console:keyreleased(key)
	if key == self.keyRepeat then
		self.keyRepeat = nil
	end
end

---LOVE2D callback for when a character was inputted.
---@param t string The character which was inputted.
function Console:textinput(t)
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
			if love.keyboard.isDown("lshift", "rshift") then
				self.tabCompletionSelection = (self.tabCompletionSelection - 2) % #self.tabCompletionList + 1
			else
				self.tabCompletionSelection = self.tabCompletionSelection % #self.tabCompletionList + 1
			end
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
	local success, err, msg = xpcall(function() return self:runCommand(self.command) end, debug.traceback)
	if not success and err then
		self:print({self.colors.error, "An error has occurred while executing command: " .. self.command})
		self:print({self.colors.error, _Utils.strSplit(err, "\n")[1]})
		_Log:printt("CONSOLE", "Full Error:")
		_Log:printt("CONSOLE", err)
	end

	-- We need to bypass the crash function somehow.
	if success and err == "crash" then
		error(msg)
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
