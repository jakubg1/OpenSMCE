local class = require "com/class"

---@class UI2Widget
---@overload fun(path):UI2Widget
local UI2Widget = class:derive("UI2Widget")

-- Place your imports here
local UIWidgetRectangle = require("src/UI/WidgetRectangle")

local Vec2 = require("src/Essentials/Vector2")



---Constructs a new UI2Widget.
---@param name string The name of an UI2Widget JSON file, located in `ui2/layouts`.
function UI2Widget:new(name)
    local path = "ui2/layouts/" .. name .. ".json"
    local data = _LoadJson(_ParsePath(path))
    assert(data, string.format("Failed to locate a UI2Widget file: %s", path))

    -- Data
    self.pos = _ParseVec2(data.pos) or Vec2()
    self.alpha = data.alpha or 1

    -- Widget
    local w = data.widget
    if w then
        if w.type == "rectangle" then
            self.widget = UIWidgetRectangle(self, w.size, w.color)
        end
    end
end



---Returns the effective position of this Widget.
---@return Vector2
function UI2Widget:getPos()
    return self.pos
end



---Returns the current effective alpha value of this Widget.
---@return number
function UI2Widget:getAlpha()
    return self.alpha
end



---Draws this Widget.
function UI2Widget:draw()
    self.widget:draw()
end



return UI2Widget