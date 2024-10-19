local class = require "com.class"

---@class DifficultyConfig
---@overload fun(data, path):DifficultyConfig
local DifficultyConfig = class:derive("DifficultyConfig")



---Constructs a new Difficulty Config.
---@param data table Raw difficulty data.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function DifficultyConfig:new(data, path)
    local u = _ConfigUtils

    self.speedMultiplier = u.parseNumber(data.speedMultiplier, path, "speedMultiplier")
    self.scoreMultiplier = u.parseNumber(data.scoreMultiplier, path, "scoreMultiplier")
end



return DifficultyConfig