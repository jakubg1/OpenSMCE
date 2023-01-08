local class = require "com/class"

---@class UI2Manager
---@overload fun():UI2Manager
local UI2Manager = class:derive("UI2Manager")

-- Place your imports here
local UI2Node = require("src/UI2/Node")
local UI2Sequence = require("src/UI2/Sequence")



---Constructs the UI2Manager.
function UI2Manager:new()
    self.rootNode = UI2Node(self, _Game.resourceManager:getUINodeConfig("ui2/layouts/root.json"), "root")
    self.rootNode:printTree()

    self.activeSequences = {}

    self.timer = 7
end



---Updates the UI2 Manager.
---@param dt number Delta time in seconds.
function UI2Manager:update(dt)
    if self.timer then
        self.timer = self.timer - dt
        print(self.timer)
        if self.timer < 0 then
            self.timer = nil
            self:activateSequence("ui2/sequences/test_new.json")
            --self.rootNode:playAnimation(_Game.configManager:getUI2Animation("fade_1_0_250ms"))
        end
    end

    for i = #self.activeSequences, 1, -1 do
        local sequence = self.activeSequences[i]
        sequence:update(dt)
        if sequence:isFinished() then
            table.remove(self.activeSequences, i)
        end
    end

    self.rootNode:update(dt)
end



---Returns a Node with a given path, if it exists.
---@param path string The path to the Node, starting with "root" or "splash" depending on the currently active root node, and next nodes separated by slashes.
---@return UI2Node?
function UI2Manager:getNode(path)
    local names = _StrSplit(path, "/")
    ---@type UI2Node?
    local node = self.rootNode
    for i, name in ipairs(names) do
        if i > 1 then -- what's with the root node? to be tidied up later
            if not node then
                return nil
            end
            node = node:getChild(name)
        end
    end
    return node
end



---Activates a Sequence with a given name.
---@param name string The Sequence to be activated.
function UI2Manager:activateSequence(name)
    table.insert(self.activeSequences, UI2Sequence(self, _Game.resourceManager:getUISequenceConfig(name)))
end



---Draws the UI on the screen.
function UI2Manager:draw()
    self.rootNode:draw()
end



return UI2Manager