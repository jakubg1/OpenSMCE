--- A class used for debugging; one can write commands there in order to affect gameplay or test some things.
-- @classmod Console



-- Class identification
local class = require "class"
local Console = class:derive("Console")

-- Include commons
local Vec2 = require("Essentials/Vector2")



--- Constructors
-- @section constructors

--- Object constructor.
-- Executed when this object is created.
function Console:new()
	self.history = {}
	self.command = ""
	
	self.open = false
	self.active = false
	
	self.backspace = false
	self.BACKSPACE_FIRST_REPEAT_TIME = 0.5
	self.BACKSPACE_NEXT_REPEAT_TIME = 0.05
	self.backspaceTime = 0
end



--- Callbacks
-- @section callbacks

--- An update callback.
-- @tparam number dt Delta time in seconds.
-- @see main.update
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



--- A drawing callback.
-- @see main.draw
function Console:draw()
	if not self.open then return end
	local pos = posOnScreen(Vec2())
	local size = Vec2(NATIVE_RESOLUTION.x, 160) * getResolutionScale()
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.rectangle("fill", pos.x, pos.y, size.x, size.y)
	
	love.graphics.setColor(1, 1, 1)
	for i = 1, 10 do
		local pos = posOnScreen(Vec2(10, 16 * (i - 1)))
		local text = nil
		if i == 10 then
			text = "> " .. self.command
			if self.active and totalTime % 1 < 0.5 then text = text .. "_" end
		else
			text = self.history[i + #self.history - 9]
		end
		if text then love.graphics.print(text, pos.x, pos.y) end
	end
end



--- Key press callback.
-- @tparam string key Which key was pressed.
-- @see main.keypressed
function Console:keypressed(key)
	-- the shortcut is Shift + Control + ~
	if key == "`" and (keyModifiers["lshift"] or keyModifiers["rshift"]) and (keyModifiers["lctrl"] or keyModifiers["rctrl"]) then
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



--- Key release callback.
-- @tparam string key Which key was pressed.
-- @see main.keyreleased
function Console:keyreleased(key)
	if key == "backspace" then
		self.backspace = false
	end
end



--- Text input callback.
-- @tparam string t What would be typed in.
-- @see main.textinput
function Console:textinput(t)
	self:inputCharacter(t)
end



--- @section end

--- Prints a message in the console.
-- @tparam string message A message to print.
function Console:print(message)
	table.insert(self.history, message)
end



--- Makes the console opened or closed.
-- @tparam boolean open Whether the console should be opened or closed.
function Console:setOpen(open)
	self.open = open
	self.active = open
end



--- Opens or closes the console, depending on which state it is now.
function Console:toggleOpen()
	self:setOpen(not self.open)
end



--- Adds a character to the input box.
-- @tparam string t A character that was typed in.
function Console:inputCharacter(t)
	if not self.active then return end
	self.command = self.command .. t
end



--- Removes the last character from the input box.
function Console:inputBackspace()
	if not self.active then return end
	self.command = self.command:sub(1, -2)
end



--- Sends the current input contents as a command.
function Console:inputEnter()
	self:print("> " .. self.command)
	local success = runCommand(self.command)
	if not success then self:print("Invalid command!") end
	self.command = ""
end



return Console