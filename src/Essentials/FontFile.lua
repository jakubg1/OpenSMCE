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

return FontFile
