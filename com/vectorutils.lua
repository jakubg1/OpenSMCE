-- vectorutils.lua by jakubg1
-- a quick library for dealing with complex vector operations without using vectors as objects

local vectorutils = {}



---Rotates the `(x, y)` vector by a given angle in radians, clockwise.
---@param x number The X part of the vector which will be rotated.
---@param y number The Y part of the vector which will be rotated.
---@param r number The rotation angle, in radians.
---@return number
---@return number
function vectorutils.rotate(x, y, r)
	return x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r)
end



return vectorutils