local class = require "com.class"

---A storage class which is holding variables for Expressions.
---@class ExpressionVariables
---@overload fun():ExpressionVariables
local ExpressionVariables = class:derive("ExpressionVariables")

---Constructor.
function ExpressionVariables:new()
	self.data = {pi = math.pi}
end

---Sets a variable to be used by Expressions.
---@param name string The variable name.
---@param value any The value to be stored.
function ExpressionVariables:set(name, value)
    self.data[name] = value
end

---Unsets a variable and/or a context with the given name.
---@param name string The variable/context name.
function ExpressionVariables:unset(name)
    for key, value in pairs(self.data) do
        if key == name or _Utils.strStartsWith(key, name .. ".") then
            self.data[key] = nil
        end
    end
end

---Obtains a variable value.
---@param name string The variable name.
---@param default any? A value to be returned if this variable doesn't exist. If not specified, this function will raise an error in that case instead.
---@return any
function ExpressionVariables:get(name, default)
    if self.data[name] == nil then
        assert(default, "Tried to get a nonexistent variable: " .. name)
        return default
    end
    return self.data[name]
end

---A debug function which returns a list of all the variables that are currently available for Expressions.
---@param prefix string? Internal; for recursion.
---@param data table? Internal; for recursion.
---@return string
function ExpressionVariables:getDebugText(prefix, data)
    --[[
    data = data or self.data

    local s = ""
    local keys = {}
    for key, value in pairs(data) do
        table.insert(keys, key)
    end
    table.sort(keys)

    for i, key in ipairs(keys) do
        local keyName = key
        if prefix then
            keyName = prefix .. "." .. key
        end
        print(keyName)
        local value = data[key]
        if type(value) == "table" then
            s = s .. string.format("%s:\n", keyName)
            s = s .. _Utils.strIndent(self:getDebugText(keyName, value), 4)
        else
            s = s .. string.format("%s = %s\n", keyName, value)
        end
    end
    return s
    ]]
    return "Variable debug unavailable for now!"
end

return ExpressionVariables
