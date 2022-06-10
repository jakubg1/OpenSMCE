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

	-- Remove any spaces.
	local s = ""
	for i = 1, str:len() do
		local c = str:sub(i, i)
		if c ~= " " then
			s = s .. c
		end
	end
	str = s


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

	-- Operators start from the lowest priority!!!
	local operators = {"||", "&&", "==", "!=", ">", "<", ">=", "<=", "+", "-", "*", "/", "%"}
	for i, op in ipairs(operators) do
		local pos = 1
		local brackets = 0

		while pos <= str:len() - op:len() + 1 do
			-- Get the character.
			local c = str:sub(pos, pos)
			local cop = str:sub(pos, pos + op:len() - 1)
			-- Update the bracket count.
			if c == "(" then
				brackets = brackets + 1
			elseif c == ")" then
				brackets = brackets - 1
			end
			-- If we're not in a bracket and an operator has been found, proceed.
			if brackets == 0 and cop == op then
				-- Calculate both hand sides and compile them.
				local lhs = str:sub(1, pos - 1)
				local rhs = str:sub(pos + op:len())
				for j, step in ipairs(self:compile(lhs)) do
					table.insert(t, step)
				end
				for j, step in ipairs(self:compile(rhs)) do
					table.insert(t, step)
				end
				-- Insert an operator and return the result.
				table.insert(t, {type = "operator", value = op})
				return t
			end
			pos = pos + 1
		end
	end

	-- If there are no operators, convert this value to an appropriate type and return itself.
	if str == "true" or str == "false" then
		-- Boolean value.
		return {
			{type = "value", value = str == "true"}
		}
	elseif str:sub(1, 1) == "[" and str:sub(str:len()) == "]" then
		-- Variable value.
		return {
			{type = "value", value = str:sub(2, str:len() - 1)},
			{type = "operator", value = "get"}
		}
	elseif str == "random" then
		-- Random value from 0 to 1, uniform.
		return {
			{type = "operator", value = "rnd"}
		}
	else
		-- Number value.
		return {
			{type = "value", value = tonumber(str)}
		}
	end
end



-- Evaluates this expression and returns the result.
function Expression:evaluate()
	local stack = {}

	for i, step in ipairs(self.data) do
		if step.type == "value" then
			table.insert(stack, step.value)
		elseif step.type == "operator" then
			local op = step.value
			-- Operators.
			-- Artithmetic: Takes two last numbers in the stack, performs an operation and puts the result number back.
			if op == "+" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a + b)
			elseif op == "-" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a - b)
			elseif op == "*" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a * b)
			elseif op == "/" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a / b)
			elseif op == "%" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a % b)

			-- Comparison: Compares two numbers or strings in the stack, consuming them and puts the result boolean back.
			elseif op == "==" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a == b)
			elseif op == "!=" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a ~= b)
			elseif op == ">" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a > b)
			elseif op == "<" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a < b)
			elseif op == ">=" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a >= b)
			elseif op == "<=" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a <= b)

			-- Logic: Performs a logic operation on two booleans, consuming them and puts back one boolean result.
			elseif op == "||" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a or b)
			elseif op == "&&" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a and b)

			-- Miscellaneous.
			elseif op == "rnd" then
				-- Generate a random number.
				table.insert(stack, math.random())
			elseif op == "get" then
				-- Get a value of a variable.
				local a = table.remove(stack)
				table.insert(stack, _Vars:get(a))
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
		if step.type == "value" then
			s = s .. tostring(step.value)
		elseif step.type == "operator" then
			s = s .. "(" .. step.value .. ")"
		end
	end
	s = s .. "]"

	return s
end





return Expression
