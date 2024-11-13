local class = require "com.class"

---@class SpriteConfig
---@overload fun(data, path):SpriteConfig
local SpriteConfig = class:derive("SpriteConfig")



---Constructs a new Sprite Config.
---@param data table Raw sprite data.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function SpriteConfig:new(data, path)
    local u = _ConfigUtils

    self.image = u.parseImage(data.path, path, "path")
    self.frameSize = u.parseVec2(data.frameSize, path, "frameSize")

    if data.frameCuts then
        self.frameCuts = {
            x1 = u.parseInteger(data.frameCuts.x1, path, "frameCuts.x1"),
            x2 = u.parseInteger(data.frameCuts.x2, path, "frameCuts.x2"),
            y1 = u.parseInteger(data.frameCuts.y1, path, "frameCuts.y1"),
            y2 = u.parseInteger(data.frameCuts.y2, path, "frameCuts.y2")
        }
    end

	---@type [{pos: Vector2, frames: Vector2}]
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