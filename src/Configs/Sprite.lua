local class = require "com.class"

---@class SpriteConfig
---@overload fun(data, path):SpriteConfig
local SpriteConfig = class:derive("SpriteConfig")

local u = require("src.Configs.utils")



---Constructs a new Sprite Config.
---@param data table Raw sprite data.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function SpriteConfig:new(data, path)
    self.image = u.parseImage(data.path, path, "path")
    self.frameSize = u.parseVec2(data.frameSize, path, "frameSize")

    self.states = {}
    for i, stateData in ipairs(data.states) do
        local state = {
            pos = u.parseVec2(stateData.pos, path, "states[" .. tostring(i) .. "].pos"),
            frames = u.parseVec2(stateData.frames, path, "states[" .. tostring(i) .. "].frames")
        }
        self.states[i] = state
    end

    self.batched = u.parseBooleanOpt(data.batched, path, "batched")
end



return SpriteConfig