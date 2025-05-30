--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class ColorPaletteConfig
---@overload fun(data, path, isAnonymous):ColorPaletteConfig
local ColorPaletteConfig = class:derive("ColorPaletteConfig")

ColorPaletteConfig.metadata = {
    schemaPath = "color_palette.json"
}

---Constructs an instance of ColorPaletteConfig.
---@param data table Raw data from a file.
---@param path string? Path to the file. Used for error messages and saving data.
---@param isAnonymous boolean? If `true`, this resource is anonymous and its path is invalid for saving data.
function ColorPaletteConfig:new(data, path, isAnonymous)
    local u = _ConfigUtils
    self._path = path
    self._alias = data._alias
    self._isAnonymous = isAnonymous

    self.image = u.parseImage(data.image, path, "image")
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function ColorPaletteConfig.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a ColorPaletteConfig by given path.
    ---@param reference string The path to the resource.
    ---@return ColorPaletteConfig
    function ResourceManager:getColorPaletteConfig(reference)
        return self:getResourceConfig(reference, "ColorPalette")
    end
end

return ColorPaletteConfig