local class = require "com.class"

---@class Shader
---@overload fun(data, path):Shader
local Shader = class:derive("Shader")

---Constructs a new Shader.
---@param data nil Unused, but required due to standardized resource constructors.
---@param path string The path to the shader file.
function Shader:new(data, path)
	self.path = path
	self.shader = assert(_Utils.loadShader(_ParsePath(path)), "Failed to load shader: " .. path)
end

---Returns the LOVE2D shader object representing this Shader.
---@return love.Shader
function Shader:getShader()
	return self.shader
end

return Shader
