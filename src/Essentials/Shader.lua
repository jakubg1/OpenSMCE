local class = require "com.class"

---@class Shader
---@overload fun(data, path):Shader
local Shader = class:derive("Shader")

---Constructs a new Shader.
---@param data nil Unused, but required due to standardized resource constructors.
---@param path string The path to the shader file.
function Shader:new(data, path)
	self.path = path
	self.shader = _Utils.loadShader(_ParsePath(path))
	assert(self.shader, "Failed to load shader data: " .. path)
end

---Returns the LOVE2D shader object representing this Shader.
---@return love.Shader
function Shader:getShader()
	return self.shader
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function Shader.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a Shader by a given path.
    ---@param path string The resource path.
    ---@return Shader
    function ResourceManager:getShader(path)
        return self:getResourceAsset(path, "Shader")
    end
end

return Shader
