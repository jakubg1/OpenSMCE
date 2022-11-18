-- Represents a compiled Expression.
-- If you give it a string, an expression will be compiled and stored in RPN notation.



local class = require "com/class"

---@class Expression
---@overload fun(str):Expression
local Expression = class:derive("Expression")



---Constructs and compiles a new Expression.
---@param str string|number The expression to be compiled.
function Expression:new(str)
	self.data = self:compile(str)
end



---Compiles a given expression.
---@param str string|number The expression to be compiled.
---@return table
function Expression:compile(str)
	-- If this is not a string, but instead a number, then there's nothing to talk about.
	if type(str) == "number" then
		-- Number value.
		return {
			{type = "value", value = str}
		}
	end

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
	if _StrIsInWholeBracket(str) then
		return self:compile(str:sub(2, str:len() - 1))
	end

	-- If there is an unary minus, then we're going to cheat by adding a leading zero to the expression.
	if str:sub(1, 1) == "-" then
		str = "0" .. str
	end

	-- If this is a function, compile the parameters and add an appropriate RPN step.
	local functions = {"floor", "ceil", "round", "random"}
	for i, f in ipairs(functions) do
		local cf = str:sub(1, f:len())
		local cother = str:sub(f:len() + 1, str:len())
		if cf == f and _StrIsInWholeBracket(cother) then
			for j, step in ipairs(self:compile(cother)) do
				table.insert(t, step)
			end
			-- Insert an operator and return the result.
			table.insert(t, {type = "operator", value = f})
			return t
		end
	end

	-- Operators start from the lowest priority!!!
	local operators = {"?", ":", "||", "&&", "!", "==", "!=", ">", "<", ">=", "<=", "+", "-", "*", "/", "%"}
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
				if op ~= "!" then -- '!' is special; no left hand side expression is expected.
					for j, step in ipairs(self:compile(lhs)) do
						table.insert(t, step)
					end
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
		local sp = _StrSplit(str:sub(2, str:len() - 1), "|")
		if #sp == 1 then
			return {
				{type = "value", value = sp[1]},
				{type = "operator", value = "get"}
			}
		elseif #sp == 2 then
			local tt = {
				{type = "value", value = sp[1]}
			}
			for i, step in ipairs(self:compile(sp[2])) do
				table.insert(tt, step)
			end
			table.insert(tt, {type = "operator", value = "getd"})
			return tt
		end
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



---Evaluates this expression and returns the result.
---@return number
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

			-- Logic: Performs a logic operation on one or two booleans, consuming them and puts back one boolean result.
			elseif op == "||" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a or b)
			elseif op == "&&" then
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a and b)
			elseif op == "!" then
				local a = table.remove(stack)
				table.insert(stack, not a)

			-- Ternary (the only available) "if" operation.
			-- The colon is ignored; serves as a separator.
			elseif op == "?" then
				local c = table.remove(stack)
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, a and b or c)

			-- Functions.
			elseif op == "floor" then
				local a = table.remove(stack)
				table.insert(stack, math.floor(a))
			elseif op == "ceil" then
				local a = table.remove(stack)
				table.insert(stack, math.ceil(a))
			elseif op == "round" then
				local a = table.remove(stack)
				table.insert(stack, math.floor(a + 0.5))
			elseif op == "random" then
				table.insert(stack, math.random())

			-- Miscellaneous.
			elseif op == "get" then
				-- Get a value of a variable.
				local a = table.remove(stack)
				table.insert(stack, _Vars:get(a))
			elseif op == "getd" then
				-- Get a value of a variable, or return a specified value if nil.
				local b = table.remove(stack)
				local a = table.remove(stack)
				table.insert(stack, _Vars:get(a, b))
			end
		end
	end

	return stack[1]
end



---Returns the data of this expression as a string.
---@return string
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
