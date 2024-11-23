local class = require "com.class"

---@class SphereSelectorConfig
---@overload fun(data, path):SphereSelectorConfig
local SphereSelectorConfig = class:derive("SphereSelectorConfig")



---Constructs a new Sphere Selector Config.
---@param data table Raw sphere selector data.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function SphereSelectorConfig:new(data, path)
    local u = _ConfigUtils

    self.operations = {}
    for i = 1, #data.operations do
        self.operations[i] = {}
        self.operations[i].type = u.parseString(data.operations[i].type, path, "operations[" .. tostring(i) .. "].type")
        self.operations[i].condition = u.parseExprBoolean(data.operations[i].condition, path, "operations[" .. tostring(i) .. "].condition")
    end
    self.scoreEvent = u.parseScoreEventConfigOpt(data.scoreEvent, path, "scoreEvent")
end



return SphereSelectorConfig