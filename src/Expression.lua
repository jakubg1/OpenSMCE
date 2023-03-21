-- Represents a compiled Expression.
-- If you give it a string, an expression will be compiled and stored in RPN notation.

local class = require "com.class"

---@class Expression
---@overload fun(str):Expression
local Expression = class:derive("Expression")

local Vec2 = require("src.Essentials.Vector2")



---Constructs and compiles a new Expression.
---@param str string|number The expression to be compiled.
function Expression:new(str)
	-- Operators.
	self.OPERATOR_FUNCTIONS = {
		-- Artithmetic: Takes two last numbers in the stack (one in case of unary minus), performs an operation and puts the result number back.
		["+"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a + b)
		end,
		["-"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a - b)
		end,
		["-u"] = function(stack)
			local a = table.remove(stack)
			table.insert(stack, -a)
		end,
		["*"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a * b)
		end,
		["/"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a / b)
		end,
		["^"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a ^ b)
		end,
		["%"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a % b)
		end,

		-- String manipulation: Takes two last strings in the stack, performs an operation and puts the result number back.
		[".."] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, tostring(a) .. tostring(b))
		end,

		-- Comparison: Compares two numbers or strings in the stack, consuming them and puts the result boolean back.
		["=="] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a == b)
		end,
		["!="] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a ~= b)
		end,
		[">"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a > b)
		end,
		["<"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a < b)
		end,
		[">="] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a >= b)
		end,
		["<="] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a <= b)
		end,

		-- Logic: Performs a logic operation on one or two booleans, consuming them and puts back one boolean result.
		["||"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a or b)
		end,
		["&&"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a and b)
		end,
		["!"] = function(stack)
			local a = table.remove(stack)
			table.insert(stack, not a)
		end,

		-- Ternary (the only available) "if" operation.
		-- The colon is ignored; serves as a separator.
		["?"] = function(stack)
			local c = table.remove(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a and b or c)
		end,

		-- Functions.
		["floor"] = function(stack)
			local a = table.remove(stack)
			table.insert(stack, math.floor(a))
		end,
		["ceil"] = function(stack)
			local a = table.remove(stack)
			table.insert(stack, math.ceil(a))
		end,
		["round"] = function(stack)
			local a = table.remove(stack)
			table.insert(stack, math.floor(a + 0.5))
		end,
		["random"] = function(stack)
			table.insert(stack, math.random())
		end,
		["randomf"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, a + math.random() * (b - a))
		end,
		["vec2"] = function(stack)
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, Vec2(a, b))
		end,

		-- Miscellaneous.
		["get"] = function(stack)
			-- Get a value of a variable.
			local a = table.remove(stack)
			table.insert(stack, _Vars:get(a))
		end,
		["getd"] = function(stack)
			-- Get a value of a variable, or return a specified value if nil.
			local b = table.remove(stack)
			local a = table.remove(stack)
			table.insert(stack, _Vars:get(a, b))
		end
	}

	self.data = self:prepare(str)
end



---Prepares and compiles a given expression if it's a string.
---@param str any The expression to be compiled.
---@return table
function Expression:prepare(str)
	-- If this is not a string, but instead a number, then there's nothing to talk about.
	if type(str) ~= "string" then
		-- Number value.
		return {
			{type = "value", value = str}
		}
	end

	return self:compile(self:tokenize(str))
end



---Performs a tokenization step: in the given string, the first token is returned as raw token data and the remainder is returned as a string.
---Returns `nil`, `<error message>` if the tokenization step fails.
---@param str string The string to be tokenized.
---@return table?
---@return string?
function Expression:getToken(str)
	str = _StrTrim(str)

	-- Let's compare the first character.
	local c = string.sub(str, 1, 1)
	local type = nil
	local PATTERNS = {
		{pattern = "%d", type = "number"},
		{pattern = "\"", type = "string"},
		{pattern = "[%a_]", type = "literal"},
		{pattern = "[%+%-%/%*%%%^%|%&%=%!%<%>%?%,%:%.]", type = "operator"},
		{pattern = "[%(%)%[%]]", type = "bracket"}
	}
	for i, pattern in ipairs(PATTERNS) do
		if string.find(c, pattern.pattern) then
			type = pattern.type
			break
		end
	end

	-- Each type has its own ending sequence.
	local value = nil
	if type == "number" then
		-- The format can be either <digits>.<digits> or <digits>
		local a, b = string.find(str, "^%d+%.%d+")
		if not a or not b then
			a, b = string.find(str, "^%d+")
		end
		value = tonumber(string.sub(str, a, b))
		str = string.sub(str, b + 1)

	elseif type == "string" then
		-- We need to avoid escaped quotation marks.
		local a, b = 2, nil
		for i = 2, string.len(str) do
			if string.sub(str, i, i) == "\"" and string.sub(str, i - 1, i - 1) ~= "\\" then
				b = i - 1
				break
			end
		end
		-- No matching quotation mark found; abort!
		if not b then
			return nil, "No matching quotation mark found"
		end
		value = string.gsub(string.sub(str, a, b), "\\\"", "\"")
		str = string.sub(str, b + 2)

	elseif type == "literal" then
		local a, b = string.find(str, "^[%a%d_]+")
		value = string.sub(str, a, b)
		-- Convert to a boolean.
		if value == "true" or value == "false" then
			type = "boolean"
			value = value == "true"
		end
		str = string.sub(str, b + 1)

	elseif type == "operator" then
		-- Some operators consist of 2 characters.
		local a, b = 1, 1
		local t = string.sub(str, 1, 2)
		if t == "//" or t == "||" or t == "&&" or t == "==" or t == "!=" or t == "<=" or t == ">=" or t == ".." then
			b = 2
		end
		value = string.sub(str, a, b)
		str = string.sub(str, b + 1)

	elseif type == "bracket" then
		local a, b = 1, 1
		value = string.sub(str, a, b)
		str = string.sub(str, b + 1)
	end

	if value ~= nil and type then
		return {value = value, type = type}, str
	end
	return nil, string.format("Unknown token type (%s, %s)", value, type)
end



---Breaks a given expression string down to single tokens.
---@param str any
---@return table
function Expression:tokenize(str)
	local origStr = str

	local tokens = {}
	while str ~= "" do
		local token, newStr = self:getToken(str)
		-- Detect an error.
		assert(token, string.format("Expression tokenization failed: %s at col %s in expression: %s", newStr, string.len(origStr) - string.len(str) + 1, origStr))
		str = newStr
		-- Detect unary minuses.
		if token.type == "operator" and token.value == "-" and
			(#tokens == 0 or tokens[#tokens].type == "operator" or (tokens[#tokens].type == "bracket" and tokens[#tokens].value == "(")) then
				token.value = "-u"
		end
		-- Detect functions.
		if token.type == "bracket" and token.value == "(" and #tokens > 0 and tokens[#tokens].type == "literal" then
			tokens[#tokens].type = "function"
		end
		table.insert(tokens, token)
	end
	return tokens
end



---Compiles the given token list into an RPN notation and returns it.
---@param tokens table A list of tokens of which this expression is built.
---@return table
function Expression:compile(tokens)
	-- This function uses an extended version of the shunting yard algorithm.
	-- https://en.wikipedia.org/wiki/Shunting_yard_algorithm
	local OPERATORS = {
		["^"] = {precedence = 10, rightAssoc = true},
		["!"] = {precedence = 9, rightAssoc = true},
		["-u"] = {precedence = 9, rightAssoc = true},
		["*"] = {precedence = 8, rightAssoc = false},
		["/"] = {precedence = 8, rightAssoc = false},
		["%"] = {precedence = 8, rightAssoc = false},
		["+"] = {precedence = 7, rightAssoc = false},
		["-"] = {precedence = 7, rightAssoc = false},
		[".."] = {precedence = 6, rightAssoc = true},
		[">"] = {precedence = 5, rightAssoc = false},
		[">="] = {precedence = 5, rightAssoc = false},
		["<"] = {precedence = 5, rightAssoc = false},
		["<="] = {precedence = 5, rightAssoc = false},
		["=="] = {precedence = 4, rightAssoc = false},
		["!="] = {precedence = 4, rightAssoc = false},
		["&&"] = {precedence = 3, rightAssoc = false},
		["||"] = {precedence = 2, rightAssoc = false},
		["?"] = {precedence = 1, rightAssoc = true},
		[":"] = {precedence = 1, rightAssoc = true},
		[","] = {precedence = 0, rightAssoc = false}
	}

	local steps = {}
	local opStack = {}

	for i, token in ipairs(tokens) do
		if token.type == "number" or token.type == "boolean" or token.type == "string" or token.type == "literal" then
			table.insert(steps, {type = "value", value = token.value})
		elseif token.type == "bracket" then
			local op = token.value
			local opData = OPERATORS[op]
			if op == "(" then
				table.insert(opStack, {type = "operator", value = op})
			elseif op == ")" then
				-- Pop operators until the matching bracket is found.
				while #opStack > 0 and opStack[#opStack].value ~= "(" do
					table.insert(steps, {type = "operator", value = opStack[#opStack].value})
					table.remove(opStack)
				end
				assert(#opStack > 0, string.format("Missing ( in Expression(%s)!", self.data))
				-- Pop the parenthesis.
				table.remove(opStack)
				-- If there's a function name beforehand, add it.
				if #opStack > 0 and opStack[#opStack].type == "function" then
					table.insert(steps, {type = "operator", value = opStack[#opStack].value})
					table.remove(opStack)
				end
			elseif op == "[" then
				table.insert(opStack, {type = "function", value = "get"})
				table.insert(opStack, {type = "operator", value = op})
			elseif op == "]" then
				-- Pop operators until the matching bracket is found.
				while #opStack > 0 and opStack[#opStack].value ~= "[" do
					table.insert(steps, {type = "operator", value = opStack[#opStack].value})
					table.remove(opStack)
				end
				assert(#opStack > 0, string.format("Missing [ in Expression(%s)!", self.data))
				-- Pop the parenthesis.
				table.remove(opStack)
				-- If there's a function name beforehand, add it.
				if opStack[#opStack].type == "function" then
					table.insert(steps, {type = "operator", value = opStack[#opStack].value})
					table.remove(opStack)
				end
			end
		elseif token.type == "operator" then
			local op = token.value
			local opData = OPERATORS[op]
			if op == "|" then
				-- This is a symbol which changes get to getd.
				assert(#opStack > 1 and opStack[#opStack - 1].type == "function" and opStack[#opStack - 1].value == "get", string.format("| in incorrect place in Expression(%s)!", self.data))
				opStack[#opStack - 1].value = "getd"
			elseif OPERATORS[op] then
				-- Pop any required operators.
				local opLast = opStack[#opStack] and opStack[#opStack].value
				local opLastData = OPERATORS[opLast]
				while opLast and opLast ~= "(" and (opData.precedence < opLastData.precedence or (opData.precedence == opLastData.precedence and not opData.rightAssoc)) do
					table.insert(steps, {type = "operator", value = opLast})
					table.remove(opStack)
					opLast = opStack[#opStack] and opStack[#opStack].value
					opLastData = OPERATORS[opLast]
				end
				table.insert(opStack, {type = "operator", value = op})
			end
		elseif token.type == "function" then
			table.insert(opStack, {type = "function", value = token.value})
		end
	end

	-- Flush the operator stack.
	for i = #opStack, 1, -1 do
		assert(opStack[i].value ~= "(", string.format("Missing ) in Expression(%s)!", self.data))
		assert(opStack[i].value ~= "[", string.format("Missing ] in Expression(%s)!", self.data))
		table.insert(steps, {type = "operator", value = opStack[i].value})
	end

	return steps
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
			-- Execute the corresponding operator function.
			local f = self.OPERATOR_FUNCTIONS[op]
			if f then
				f(stack)
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
