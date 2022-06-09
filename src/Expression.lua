-- Represents a compiled Expression.
-- If you give it a string, an expression will be compiled and stored in RPN notation.



local class = require "com/class"
local Expression = class:derive("Expression")



-- Constructor. Creates and compiles an expression.
function Expression:new(str)
	self.data = self:compile(str)
end



-- Compiles a given expression.
function Expression:compile(str)
	-- Stores a list of RPN "steps".
	local t = {}

	-- If the whole expression is in a bracket, remove it.
	if str:sub(1, 1) == "(" and str:sub(str:len()) == ")" then
		local pos = 2
		local brackets = 1
		local ok = true

		-- Test whether this is the same bracket at the beginning and at the end.
		while pos < str:len() do
			-- Get the character.
			local c = str:sub(pos, pos)
			-- Update the bracket count.
			if c == "(" then
				brackets = brackets + 1
			elseif c == ")" then
				brackets = brackets - 1
			end
			-- If we're out of the root bracket, don't remove it.
			if brackets == 0 then
				ok = false
				break
			end
			pos = pos + 1
		end

		if ok then
			return self:compile(str:sub(2, str:len() - 1))
		end
	end

	-- If there is an unary minus, then we're going to cheat by adding a leading zero to the expression.
	if str:sub(1, 1) == "-" then
		str = "0" .. str
	end

	-- Four basic operators are supported by now. Start from the lowest priority!!!
	local operators = {"+", "-", "*", "/"}
	for i = 1, 4 do
		local op = operators[i]
		local pos = 1
		local brackets = 0

		while pos <= str:len() do
			-- Get the character.
			local c = str:sub(pos, pos)
			-- Update the bracket count.
			if c == "(" then
				brackets = brackets + 1
			elseif c == ")" then
				brackets = brackets - 1
			end
			-- If we're not in a bracket and an operator has been found, proceed.
			if brackets == 0 and c == op then
				-- Calculate both hand sides and compile them.
				local lhs = str:sub(1, pos - 1)
				local rhs = str:sub(pos + 1)
				for j, step in ipairs(self:compile(lhs)) do
					table.insert(t, step)
				end
				for j, step in ipairs(self:compile(rhs)) do
					table.insert(t, step)
				end
				-- Insert an operator and return the result.
				table.insert(t, op)
				return t
			end
			pos = pos + 1
		end
	end

	-- If there are no operators, convert this value to a number and return itself.
	return {tonumber(str)}
end



-- Evaluates this expression and returns the result.
function Expression:evaluate()
	local stack = {}

	for i, step in ipairs(self.data) do
		if type(step) == "number" then
			table.insert(stack, step)
		elseif type(step) == "string" then
			if step == "+" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a + b)
			elseif step == "-" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a - b)
			elseif step == "*" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a * b)
			elseif step == "/" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a / b)
			end
		end
	end

	return stack[1]
end



-- Returns the data of this expression as a string.
function Expression:getDebug()
	local s = "["
	for i, step in ipairs(self.data) do
		if i > 1 then
			s = s .. ", "
		end
		if type(step) == "number" then
			s = s .. tostring(step)
		elseif type(step) == "string" then
			s = s .. "(" .. step .. ")"
		end
	end
	s = s .. "]"

	return s
end





return Expression
