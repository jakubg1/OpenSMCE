local class = require "com.class"

---@class UI2AnimationConfig
---@overload fun(data):UI2AnimationConfig
local UI2AnimationConfig = class:derive("UI2AnimationConfig")

local Vec2 = require("src.Essentials.Vector2")



---Constructs a new UI2 Animation Config.
---@param data table Raw data parsed from `ui2/animations/*.json`.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function UI2AnimationConfig:new(data, path)
    self._path = path



    ---@type string
    self.property = data.property
    ---@type number|Vector2?
    self.from = data.from
    ---@type number|Vector2
    self.to = data.to
    ---@type number
    self.duration = data.duration
end



return UI2AnimationConfig