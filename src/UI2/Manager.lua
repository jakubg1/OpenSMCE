local class = require "com/class"

---@class UI2Manager
---@overload fun():UI2Manager
local UI2Manager = class:derive("UI2Manager")

-- Place your imports here
local UI2Widget = require("src/UI2/Widget")



---Constructs the UI2Manager.
function UI2Manager:new()
    self.rootWidget = UI2Widget("test")
end



---Draws the UI on the screen.
function UI2Manager:draw()
    self.rootWidget:draw()
end



return UI2Manager