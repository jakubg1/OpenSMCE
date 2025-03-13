--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class SphereSelectorConfig
---@overload fun(data, path):SphereSelectorConfig
local SphereSelectorConfig = class:derive("SphereSelectorConfig")



---Constructs an instance of SphereSelectorConfig.
---@param data table Raw data from a file.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function SphereSelectorConfig:new(data, path)
    local u = _ConfigUtils
    self._path = path

    self.operations = {}
    for i = 1, #data.operations do
        self.operations[i] = {}
        self.operations[i].type = u.parseString(data.operations[i].type, path, "operations[" .. tostring(i) .. "].type")
        if self.operations[i].type == "add" then
            self.operations[i].condition = u.parseExprBoolean(data.operations[i].condition, path, "operations[" .. tostring(i) .. "].condition")
        elseif self.operations[i].type == "select" then
            self.operations[i].percentage = u.parseNumber(data.operations[i].percentage, path, "operations[" .. tostring(i) .. "].percentage")
            self.operations[i].round = u.parseStringOpt(data.operations[i].round, path, "operations[" .. tostring(i) .. "].round") or "down"
        else
            error(string.format("Unknown SphereSelectorConfig type: %s (expected \"add\", \"select\")", self.operations[i].type))
        end
    end
end



return SphereSelectorConfig