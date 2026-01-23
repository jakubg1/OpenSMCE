local class = require "com.class"

---@class FontFile
---@overload fun(data, path):FontFile
local FontFile = class:derive("FontFile")

---Constructs a new FontFile.
---@param data nil Unused, but required due to standardized resource constructors.
---@param path string Path to the FontFile.
function FontFile:new(data, path)
	self.path = path
end

---Returns a new Font from this FontFile.
---@param size integer? The font size, `12` by default.
---@return love.Font
function FontFile:makeFont(size)
	local font = _Utils.loadFont(_ParsePath(self.path), size)
	assert(font, "Failed to make a font: " .. self.path)
	return font
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function FontFile.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a Font File by a given path.
    ---@param path string The resource path.
    ---@return FontFile
    function ResourceManager:getFontFile(path)
        return self:getResourceAsset(path, "FontFile")
    end
end

return FontFile
