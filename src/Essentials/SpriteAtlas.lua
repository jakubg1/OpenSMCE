local class = require "com.class"

---Represents a single Sprite Atlas.
---
---Sprite Atlases are textures generated dynamically by the game during loading of all assets.
---By stitching several sprites together, the GPU does not have to switch between textures, which is an expensive operation.
---This comes in handy when drawing a lot of spheres or particles at once in any desired order.
---
---Sprite Atlases inject themselves into affected Sprites.
---All affected Sprites are permanently redirected to the latest Atlas they are defined in.
---
---**NOTE:**
---Currently, if the Atlas contains multiple Sprites which reference the same Image, the Image would get copied for each sprite,
---instead of all of the sprites sharing the same image. This will be implemented at some point.
---@class SpriteAtlas
---@overload fun(config, path):SpriteAtlas
local SpriteAtlas = class:derive("SpriteAtlas")

---Constructs a new Sprite Atlas.
---@param config SpriteAtlasConfig The sprite atlas config.
---@param path string A path to the sprite atlas file.
function SpriteAtlas:new(config, path)
    self.config = config
    self.path = path

    self.canvas = nil
    self.sprites = {} -- Indexed by Sprite instances, data: {offsetX, offsetY}
    self:generateAtlas()
end

---Generates the Sprite Atlas from all sprites defined in its configuration.
function SpriteAtlas:generateAtlas()
    -- Determine the atlas' canvas size.
    -- All sprites have a 1px margin on all four sides to avoid additional bleeding.
    local sizeX = 0
    local sizeY = 0
    for i, sprite in ipairs(self.config.sprites) do
        sizeX = math.max(sizeX, sprite.imageSize.x + 2)
        sizeY = sizeY + sprite.imageSize.y + 2
    end
    self.canvas = love.graphics.newCanvas(sizeX, sizeY)
    -- Place the sprites on the canvas and generate relevant metadata.
    love.graphics.setCanvas(self.canvas)
    local y = 1
    for i, sprite in ipairs(self.config.sprites) do
        sprite.config.image:draw(1, y)
        local yAdd = sprite.imageSize.y
        sprite:attachToAtlas(self, 1, y)
        y = y + yAdd + 2
    end
    love.graphics.setCanvas()
end

---Saves the contents of this Sprite Atlas to a file called `test.png`.
function SpriteAtlas:testSave()
    self.canvas:newImageData():encode("png", "test.png")
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function SpriteAtlas.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a SpriteAtlas by a given path.
    ---@param path string The resource path.
    ---@return SpriteAtlas
    function ResourceManager:getSpriteAtlas(path)
        return self:getResourceAsset(path, "SpriteAtlas")
    end
end

return SpriteAtlas