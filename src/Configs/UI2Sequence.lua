local class = require "com/class"

---@class UI2SequenceConfig
---@overload fun(data):UI2SequenceConfig
local UI2SequenceConfig = class:derive("UI2SequenceConfig")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")



---Constructs a new UI2 Sequence Config.
---@param data table Raw data parsed from `ui2/sequences/*.json`.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function UI2SequenceConfig:new(data, path)
    self._path = path



    self.timeline = {}

    for i, entry in ipairs(data.timeline) do
        local entryT = {}

        entryT.type = entry.type

        if entry.type == "playAnimation" then
            -- This is a literal path, and here we are only dealing with building blocks, so this will remain unresolved.
            entryT.node = entry.node
            entryT.animation = _Game.resourceManager:getUIAnimationConfig(entry.animation)
            entryT.waitUntilFinished = entry.waitUntilFinished
        elseif entry.type == "wait" then
            entryT.time = entry.time
        else
            error(string.format("Failed to load file %s, unknown Timeline Entry type: %s (expected \"playAnimation\" or \"wait\")", path, entry.type))
        end

        table.insert(self.timeline, entryT)
    end
end



return UI2SequenceConfig