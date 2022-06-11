-- A storage class which is holding variables for Expressions.



local class = require "com/class"
local ExpressionVariables = class:derive("ExpressionVariables")



-- Constructor.
function ExpressionVariables:new()
	self.data = {}
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





return ExpressionVariables
