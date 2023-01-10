local class = require "com/class"

---@class UI2Manager
---@overload fun():UI2Manager
local UI2Manager = class:derive("UI2Manager")

-- Place your imports here
local UI2Node = require("src/UI2/Node")
local UI2Sequence = require("src/UI2/Sequence")



---Constructs the UI2Manager.
function UI2Manager:new()
    self.rootNodes = {
        root = UI2Node(self, _Game.resourceManager:getUINodeConfig("ui2/layouts/root.json"), "root")
    }

    self.activeSequences = {}

    self.timer = 7
end



---Updates the UI2 Manager.
---@param dt number Delta time in seconds.
function UI2Manager:update(dt)
    if self.timer then
        self.timer = self.timer - dt
        if self.timer < 0 then
            self.timer = nil
            self.rootNodes.root2 = UI2Node(self, _Game.resourceManager:getUINodeConfig("ui2/layouts/root2.json"), "root2")
            self:setActive("root2")
            self:activateSequence("ui2/sequences/test_new2.json")
        end
    end

    for i = #self.activeSequences, 1, -1 do
        local sequence = self.activeSequences[i]
        sequence:update(dt)
        if sequence:isFinished() then
            table.remove(self.activeSequences, i)
        end
    end

    for nodeN, node in pairs(self.rootNodes) do
        node:update(dt)
    end
end



---Returns a Node with a given path, if it exists.
---@param path string The path to the Node, starting with "root" or "splash" depending on the currently active root node, and next nodes separated by slashes.
---@return UI2Node?
function UI2Manager:getNode(path)
    local names = _StrSplit(path, "/")
    local node = self.rootNodes[names[1]]
    for i, name in ipairs(names) do
        if i > 1 then
            node = node:getChild(name)
        end
        if not node then
            return nil
        end
    end
    return node
end



---Activates a given Node and all its children.
---@param path string The path to the Node.
---@param append boolean? Whether the already activated Nodes should remain active.
function UI2Manager:setActive(path, append)
    self:getNode(path):setActive(append)
end



---Deactivates all Nodes.
function UI2Manager:resetActive()
    for nodeN, node in pairs(self.rootNodes) do
        node:resetActive()
    end
end



---Activates a Sequence with a given name.
---@param name string The Sequence to be activated.
function UI2Manager:activateSequence(name)
    table.insert(self.activeSequences, UI2Sequence(self, _Game.resourceManager:getUISequenceConfig(name)))
end



---Draws the UI on the screen.
function UI2Manager:draw()
    for nodeN, node in pairs(self.rootNodes) do
        node:draw()
    end
end



---Callback from Game.lua.
---@see Game.mousepressed
---@param x number
---@param y number
---@param button number
function UI2Manager:mousepressed(x, y, button)
    for nodeN, node in pairs(self.rootNodes) do
        node:mousepressed(x, y, button)
    end
end



---Callback from Game.lua.
---@see Game.mousereleased
---@param x number
---@param y number
---@param button number
function UI2Manager:mousereleased(x, y, button)
    for nodeN, node in pairs(self.rootNodes) do
        node:mousereleased(x, y, button)
    end
    --self:executeCallback("click")
end



---Callback from Game.lua.
---@see Game.keypressed
---@param key string
function UI2Manager:keypressed(key)
    for nodeN, node in pairs(self.rootNodes) do
		node:keypressed(key)
	end
end



---Callback from Game.lua.
---@see Game.textinput
---@param t string
function UI2Manager:textinput(t)
    for nodeN, node in pairs(self.rootNodes) do
        node:textinput(t)
    end
end



return UI2Manager