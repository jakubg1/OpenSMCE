local class = require "com/class"

---@class UI2Manager
---@overload fun():UI2Manager
local UI2Manager = class:derive("UI2Manager")

-- Place your imports here
local UI2Node = require("src/UI2/Node")



---Constructs the UI2Manager.
function UI2Manager:new()
    self.rootNode = UI2Node(_Game.configManager:getUI2Layout("root"), "root")
    self.rootNode:printTree()
end



---Draws the UI on the screen.
function UI2Manager:draw()
    self.rootNode:draw()
end



return UI2Manager