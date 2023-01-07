local class = require "com/class"

---@class UI2WidgetConfig
---@overload fun(data):UI2WidgetConfig
local UI2WidgetConfig = class:derive("UI2WidgetConfig")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")



---Constructs a new UI2 Animation Config.
---@param data table Raw data parsed from `ui2/layout/*.json`.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function UI2WidgetConfig:new(data, path)
    self._path = path



    ---@type string
    self.type = data.type

    if self.type == "rectangle" then
        ---@type Vector2
        self.size = _ParseVec2(data.size) or Vec2()
        ---@type Color
        self.color = _ParseColor(data.color) or Color()
    else
        error(string.format("Failed to load file %s, unknown Widget type: %s (expected \"rectangle\")", path, self.type))
    end
end



return UI2WidgetConfig