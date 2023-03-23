-- A storage class which is holding variables for Expressions.



local class = require "com.class"

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



---Evaluates an Expression and caches it, or evaluates an already cached Expression. Returns the result.
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
    local e = Expression(actualExpression)
    self.expressionCache[expression] = e
    return e:evaluate()
end



return ExpressionVariables
