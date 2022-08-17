-- A storage class which is holding variables for Expressions.



local class = require "com/class"

---@class ExpressionVariables
---@overload fun():ExpressionVariables
local ExpressionVariables = class:derive("ExpressionVariables")

local Expression = require("src/Expression")



-- Constructor.
function ExpressionVariables:new()
	self.data = {}
    self.expressionCache = {}
end



-- Sets a value.
function ExpressionVariables:set(name, value)
    self.data[name] = value
end



-- Gets a value.
function ExpressionVariables:get(name)
    if self.data[name] == nil then
        error(string.format("[ExpressionVariables] Tried to get a nonexistent variable: %s", name))
    end
    return self.data[name]
end



-- Evaluates an expression.
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
