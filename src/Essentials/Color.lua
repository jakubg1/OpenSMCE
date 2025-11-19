local class = require "com.class"

---@class Color
---@operator add(Color|number):Color
---@operator sub(Color|number):Color
---@operator mul(Color|number):Color
---@operator div(Color|number):Color
---@operator unm():Color
---@overload fun(r, g, b):Color
local Color = class:derive("Color")

---Constructor.
---
---`Color()` will make a `(1, 1, 1)` color (white).
---
---`Color(x)` will make a `(x, x, x)` color (grayscale).
---
---`Color(r, g, b)` will make a `(r, g, b)` color.
---
---`Color({r: r, g: g, b: b})` will make a `(r, g, b)` color.
---
---`Color(hex)` will make a color matching the hexadecimal color code. Allowed formats are:
---`"rrggbb"`, `"#rrggbb"`, `"rgb"`, `"#rgb"`.
function Color:new(r, g, b)
	if type(r) == "table" then
		self.r = r.r
		self.g = r.g
		self.b = r.b
	elseif type(r) == "string" then
		if r:sub(1, 1) == "#" then
			r = r:sub(2)
		end
		if r:len() == 6 then
			self.r = tonumber(r:sub(1, 2), 16) / 255
			self.g = tonumber(r:sub(3, 4), 16) / 255
			self.b = tonumber(r:sub(5, 6), 16) / 255
		else
			self.r = tonumber(r:sub(1, 1), 16) / 15
			self.g = tonumber(r:sub(2, 2), 16) / 15
			self.b = tonumber(r:sub(3, 3), 16) / 15
		end
	else
		self.r = r or 1
		self.g = g or self.r
		self.b = b or self.r
	end
end

function Color.__tostring(o) return "Color(" .. tostring(o.r) .. ", " .. tostring(o.g) .. ", " .. tostring(o.b) .. ")" end
function Color.__unm(o) return Color(-o.r, -o.g, -o.b) end
function Color.clone(o) return Color(o.r, o.g, o.b) end

function Color.__eq(o1, o2)
	if type(o2) == "number" then
		return o1.r == o2 and o1.g == o2 and o1.b == o2
	else
		return o1.r == o2.r and o1.g == o2.g and o1.b == o2.b
	end
end

function Color.__add(o1, o2)
	if type(o2) == "number" then
		return Color(o1.r + o2, o1.g + o2, o1.b + o2)
	else
		return Color(o1.r + o2.r, o1.g + o2.g, o1.b + o2.b)
	end
end

function Color.__sub(o1, o2)
	if type(o2) == "number" then
		return Color(o1.r - o2, o1.g - o2, o1.b - o2)
	else
		return Color(o1.r - o2.r, o1.g - o2.g, o1.b - o2.b)
	end
end

function Color.__mul(o1, o2)
	if type(o2) == "number" then
		return Color(o1.r * o2, o1.g * o2, o1.b * o2)
	else
		return Color(o1.r * o2.r, o1.g * o2.g, o1.b * o2.b)
	end
end

function Color.__div(o1, o2)
	if type(o2) == "number" then
		return Color(o1.r / o2, o1.g / o2, o1.b / o2)
	else
		return Color(o1.r / o2.r, o1.g / o2.g, o1.b / o2.b)
	end
end

---Returns a hexadecimal representation of this color. The result is always formatted as a `"#rrggbb"` string.
---@return string
function Color:getHex()
	return string.format("#%02x%02x%02x", self.r * 255, self.g * 255, self.b * 255)
end

return Color