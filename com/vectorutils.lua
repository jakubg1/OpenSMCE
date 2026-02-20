-- vectorutils.lua by jakubg1
-- a quick library for dealing with complex vector operations without using vectors as objects

local vectorutils = {}

---Returns the length of the `(x, y)` vector.
---@param x number The X component of the vector.
---@param y number The Y component of the vector.
---@return number
function vectorutils.length(x, y)
	return math.sqrt(x ^ 2 + y ^ 2)
end

---Returns the distance between the `(x1, y1)` and the `(x2, y2)` points.
---@param x1 number The X component of the first vector.
---@param y1 number The Y component of the first vector.
---@param x2 number The X component of the second vector.
---@param y2 number The Y component of the second vector.
---@return number
function vectorutils.distance(x1, y1, x2, y2)
	return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

---Returns the angle of the `(x, y)` vector.
---@param x number The X component of the vector.
---@param y number The Y component of the vector.
---@return number
function vectorutils.angle(x, y)
	return math.atan2(y, x)
end

---Rotates the `(x, y)` vector by a given angle in radians, clockwise.
---@param x number The X part of the vector which will be rotated.
---@param y number The Y part of the vector which will be rotated.
---@param r number The rotation angle, in radians.
---@return number, number
function vectorutils.rotate(x, y, r)
	return x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r)
end

---Returns a cross product of two vectors.
---@param x1 number The X component of the first vector.
---@param y1 number The Y component of the first vector.
---@param x2 number The X component of the second vector.
---@param y2 number The Y component of the second vector.
---@return number
function vectorutils.cross(x1, y1, x2, y2)
	return x1 * y2 - y1 * x2
end

return vectorutils