--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class SpriteAtlasConfig
---@overload fun(data, path):SpriteAtlasConfig
local SpriteAtlasConfig = class:derive("SpriteAtlasConfig")

SpriteAtlasConfig.metadata = {
    schemaPath = "sprite_atlas.json"
}

---Constructs an instance of SpriteAtlasConfig.
---@param data table Raw data from a file.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function SpriteAtlasConfig:new(data, path)
    local u = _ConfigUtils
    self._path = path

    self.sprites = {}
    for i = 1, #data.sprites do
        self.sprites[i] = u.parseSprite(data.sprites[i], path, "sprites[" .. tostring(i) .. "]")
    end
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function SpriteAtlasConfig.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a SpriteAtlasConfig by a given path.
    ---@param path string The resource path.
    ---@return SpriteAtlasConfig
    function ResourceManager:getSpriteAtlasConfig(path)
        return self:getResourceConfig(path, "SpriteAtlasConfig")
    end
end

return SpriteAtlasConfig