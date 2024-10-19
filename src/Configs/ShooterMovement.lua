local class = require "com.class"

---@class ShooterMovementConfig
---@overload fun(data, path):ShooterMovementConfig
local ShooterMovementConfig = class:derive("ShooterMovementConfig")



---Constructs a new Shooter Movement Config.
---@param data table Raw shooter movement data, found in `config/levels/*.json` and `config/shooters/*.json`.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function ShooterMovementConfig:new(data, path)
    local u = _ConfigUtils

    self.type = u.parseString(data.type, path, "type")

    if self.type == "linear" then
        self.xMin = u.parseNumber(data.xMin, path, "xMin")
        self.xMax = u.parseNumber(data.xMax, path, "xMax")
        self.y = u.parseNumber(data.y, path, "y")
        self.angle = u.parseNumber(data.angle, path, "angle")
    elseif self.type == "circular" then
        self.x = u.parseNumber(data.x, path, "x")
        self.y = u.parseNumber(data.y, path, "y")
    else
        error(string.format("Failed to load file %s, unknown shooter type: %s (expected \"linear\" or \"circular\")", path, self.type))
    end
end



return ShooterMovementConfig