local class = require "com.class"

---@class UI2NodeConfig
---@overload fun(data, path):UI2NodeConfig
local UI2NodeConfig = class:derive("UI2NodeConfig")

local Vec2 = require("src.Essentials.Vector2")
local UI2WidgetConfig = require("src.Configs.UI2Widget")



---Constructs a new UI2 Node Config.
---@param data table Raw data parsed from `ui2/layout/*.json`.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function UI2NodeConfig:new(data, path)
    self._path = path



    -- This table stores children as either strings (if they're includes) or as UI2NodeConfigs if defined directly in the file.
    -- This mess is resolved by the UI2 Manager itself.
    self.children = {}
    if data.children then
        for childN, child in pairs(data.children) do
            if child.type == "include" then
                self.children[childN] = child.layout
            elseif child.type == "node" then
                self.children[childN] = UI2NodeConfig(child.node)
            else
                error(string.format("Failed to load file %s, unknown Node[%s] type: %s (expected \"include\" or \"node\")", path, childN, child.type))
            end
        end
    end

    ---@type UI2WidgetConfig?
    self.widget = data.widget and UI2WidgetConfig(data.widget, path)
    ---@type Vector2
    self.pos = _ParseVec2(data.pos) or Vec2()
    ---@type Vector2
    self.scale = _ParseVec2(data.scale) or Vec2(1)
    ---@type number
    self.alpha = data.alpha or 1
    ---@type string?
    self.layer = data.layer
end



return UI2NodeConfig