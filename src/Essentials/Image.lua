local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")

---@class Image
---@overload fun(data, path):Image
local Image = class:derive("Image")

---Constructs a new Image.
---@param data nil Unused, but required due to standardized resource constructors.
---@param path string Path to the image.
function Image:new(data, path)
	self.path = path

	self.data = _Utils.loadImageData(_ParsePath(path))
	assert(self.data, "Failed to load image data: " .. path)
	self.img = love.graphics.newImage(self.data)
	self.size = Vec2(self.img:getDimensions())
end

---Draws the Image onto the screen.
---This is an alias to `love.graphics.draw(Image.img, ...)`.
function Image:draw(...)
	love.graphics.draw(self.img, ...)
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function Image.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a Image by a given path.
    ---@param path string The resource path.
    ---@return Image
    function ResourceManager:getImage(path)
        return self:getResourceAsset(path, "Image")
    end
end

return Image
