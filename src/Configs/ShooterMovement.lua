local class = require "com.class"

---@class ShooterMovementConfig
---@overload fun(data):ShooterMovementConfig
local ShooterMovementConfig = class:derive("ShooterMovementConfig")

-- Place your imports here



---Constructs a new Shooter Movement Config.
---@param data table Raw shooter movement data, found in `config/levels/*.json` and `config/shooters/*.json`.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function ShooterMovementConfig:new(data, path)
    self._path = path



    ---@type string
    self.type = data.type

    if self.type == "linear" then
        ---@type number
        self.xMin = data.xMin
        ---@type number
        self.xMax = data.xMax
        ---@type number
        self.y = data.y
        ---@type number
        self.angle = data.angle
    elseif self.type == "circular" then
        ---@type number
        self.x = data.x
        ---@type number
        self.y = data.y
    else
        error(string.format("Failed to load file %s, unknown shooter type: %s (expected \"linear\" or \"circular\")", path, data.type))
    end
end



return ShooterMovementConfig