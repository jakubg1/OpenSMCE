local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")

---@class ColorPalette
---@overload fun(config, path):ColorPalette
local ColorPalette = class:derive("ColorPalette")

---Constructs a new Color Palette.
---@param config ColorPaletteConfig The config of this Color Palette.
---@param path string Path to the color palette file.
function ColorPalette:new(config, path)
	self.path = path

	self.image = config.image.data
	self.size = Vec2(self.image:getDimensions())
end

---Returns a color based on the provided offset.
---@param t number The horizontal offset on the palette image in pixels. Wraps around.
---@return Color
function ColorPalette:getColor(t)
	return Color(self.image:getPixel(t % self.size.x, 1))
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function ColorPalette.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a Color Palette by a given path.
    ---@param path string The resource path.
    ---@return ColorPalette
    function ResourceManager:getColorPalette(path)
        return self:getResourceAsset(path, "ColorPalette")
    end
end

return ColorPalette