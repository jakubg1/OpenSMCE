local class = require "com.class"

---A storage class which is holding variables for Expressions.
---Additionally, it caches all Expressions so they only have to be compiled once.
---@class ExpressionVariables
---@overload fun():ExpressionVariables
local ExpressionVariables = class:derive("ExpressionVariables")

local Expression = require("src.Expression")



---Constructor.
function ExpressionVariables:new()
	self.data = {}
    self.expressionCache = {}

    self:set("pi", math.pi)
end



---Sets a variable to be used by Expressions.
---@param name string The variable name.
---@param value any The value to be stored.
function ExpressionVariables:set(name, value)
    self.data[name] = value
end



---Sets a context variable to be used by Expressions.
---Context variables can be set in a procedure, and when certain things which require them are done, they can be purged in one snap using `:unset()`.
---@param context string The context name.
---@param name string The variable name.
---@param value any The value to be stored.
function ExpressionVariables:setC(context, name, value)
    if self.data[context] and type(self.data[context]) ~= "table" then
        error(string.format("[ExpressionVariables] Tried to create a context of the same name as an already existing variable: %s", context))
    end
    if not self.data[context] then
        self.data[context] = {}
    end
    self.data[context][name] = value
end



---Unsets a variable or a context with the given name.
---@param name string The variable/context name.
function ExpressionVariables:unset(name)
    self.data[name] = nil
end



---Obtains a variable value.
---@param name string The variable name.
---@param default any? A value to be returned if this variable doesn't exist. If not specified, this function will raise an error in that case instead.
---@return any
function ExpressionVariables:get(name, default)
    if self.data[name] == nil then
        if default ~= nil then
            return default
        else
            error(string.format("[ExpressionVariables] Tried to get a nonexistent variable: %s", name))
        end
    end
    return self.data[name]
end



---Obtains a context variable value.
---@param context string The context name.
---@param name string The variable name.
---@param default any? A value to be returned if this variable doesn't exist. If not specified, this function will raise an error in that case instead.
---@return any
function ExpressionVariables:getC(context, name, default)
    if self.data[context] == nil or self.data[context][name] == nil then
        if default ~= nil then
            return default
        else
            error(string.format("[ExpressionVariables] Tried to get a nonexistent context variable: %s.%s", context, name))
        end
    end
    return self.data[context][name]
end



---Evaluates an Expression and caches it, or evaluates an already cached Expression. Returns the result.
---TODO: Remove this once we move to Config Classes.
---@param expression string The expression string.
---@return number|string|Vector2
function ExpressionVariables:evaluateExpression(expression)
    -- Get an already cached and compiled expression if exists.
    local c = self.expressionCache[expression]
    if c then
        return c:evaluate()
    end
    -- Else, compile and cache an expression first.
    -- Is it in the $expr{...} format?
    local actualExpression = expression
    if string.sub(expression, 1, 6) == "$expr{" and string.sub(expression, string.len(expression)) == "}" then
        actualExpression = string.sub(expression, 7, string.len(expression) - 1)
    end
    local e = Expression(actualExpression, true)
    self.expressionCache[expression] = e
    return e:evaluate()
end



---A debug function which prints all the variables that are currently available for Expressions.
function ExpressionVariables:printContents()
    print("")
    for key, value in pairs(self.data) do
        if type(value) == "table" then
            print(string.format("[%s]", key))
            for subkey, subvalue in pairs(value) do
                print(string.format(" |--- %s.%s = %s", key, subkey, subvalue))
            end
        else
            print(string.format("%s = %s", key, value))
        end
    end
end



return ExpressionVariables
