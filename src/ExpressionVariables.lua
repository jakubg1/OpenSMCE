-- A storage class which is holding variables for Expressions.



local class = require "com/class"

---@class ExpressionVariables
---@overload fun():ExpressionVariables
local ExpressionVariables = class:derive("ExpressionVariables")

local Expression = require("src/Expression")



---Constructor.
function ExpressionVariables:new()
	self.data = {}
    self.expressionCache = {}
end



---Sets a variable to be used by Expressions.
---@param name string The variable name.
---@param value any The value to be stored.
function ExpressionVariables:set(name, value)
    self.data[name] = value
end



---Obtains a variable value.
---@param name string The variable name.
---@return any
function ExpressionVariables:get(name)
    if self.data[name] == nil then
        error(string.format("[ExpressionVariables] Tried to get a nonexistent variable: %s", name))
    end
    return self.data[name]
end



---Evaluates an Expression and caches it, or evaluates an already cached Expression. Returns the result.
---@param expression string The expression string.
---@return number
function ExpressionVariables:evaluateExpression(expression)
    -- Get an already cached and compiled expression if exists.
    local c = self.expressionCache[expression]
    if c then
        return c:evaluate()
    end
    -- Else, compile and cache an expression first.
    local e = Expression(expression)
    self.expressionCache[expression] = e
    return e:evaluate()
end



return ExpressionVariables
