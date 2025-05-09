--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class SpriteConfig
---@overload fun(data, path):SpriteConfig
local SpriteConfig = class:derive("SpriteConfig")

SpriteConfig.metadata = {
    schemaPath = "sprite.json"
}

---Constructs an instance of SpriteConfig.
---@param data table Raw data from a file.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function SpriteConfig:new(data, path)
    local u = _ConfigUtils
    self._path = path

    self.image = u.parseImage(data.image, path, "image")
    self.frameSize = u.parseVec2(data.frameSize, path, "frameSize")

    if data.frameCuts then
        self.frameCuts = {}
        self.frameCuts.x1 = u.parseInteger(data.frameCuts.x1, path, "frameCuts.x1")
        self.frameCuts.x2 = u.parseInteger(data.frameCuts.x2, path, "frameCuts.x2")
        self.frameCuts.y1 = u.parseInteger(data.frameCuts.y1, path, "frameCuts.y1")
        self.frameCuts.y2 = u.parseInteger(data.frameCuts.y2, path, "frameCuts.y2")
    end

    self.states = {}
    for i = 1, #data.states do
        self.states[i] = {}
        self.states[i].pos = u.parseVec2(data.states[i].pos, path, "states[" .. tostring(i) .. "].pos")
        self.states[i].frames = u.parseVec2(data.states[i].frames, path, "states[" .. tostring(i) .. "].frames")
    end

    self.batched = u.parseBooleanOpt(data.batched, path, "batched")
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function SpriteConfig.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a SpriteConfig by a given path.
    ---@param path string The resource path.
    ---@return SpriteConfig
    function ResourceManager:getSpriteConfig(path)
        return self:getResourceConfig(path, "SpriteConfig")
    end
end

return SpriteConfig