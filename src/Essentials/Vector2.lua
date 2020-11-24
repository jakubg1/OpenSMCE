local class = require "com/class"
local Vec2 = class:derive("Vec2")

function Vec2:new(x, y)
	self.x = x or 0
	self.y = y or self.x
end

function Vec2.__tostring(o) return "(" .. tostring(o.x) .. ", " .. tostring(o.y) .. ")" end
function Vec2.__unm(o) return Vec2(-o.x, -o.y) end
function Vec2.clone(o) return Vec2(o.x, o.y) end

function Vec2.len(o) return math.sqrt(math.pow(o.x, 2) + math.pow(o.y, 2)) end
function Vec2.angle(o) return math.atan2(o.y, o.x) end
function Vec2.floor(o) return Vec2(math.floor(o.x), math.floor(o.y)) end
function Vec2.ceil(o) return Vec2(math.ceil(o.x), math.floor(o.y)) end
function Vec2.swap(o) return Vec2(o.y, o.x) end
function Vec2.rotate(o, r) return Vec2(o.x * math.cos(r) - o.y * math.sin(r), o.x * math.sin(r) + o.y * math.cos(r)) end

function Vec2.__eq(o1, o2)
	if type(o2) == "number" then
		return o1.x == o2 and o1.y == o2
	else
		return o1.x == o2.x and o1.y == o2.y
	end
end

function Vec2.__add(o1, o2)
	if type(o2) == "number" then
		return Vec2(o1.x + o2, o1.y + o2)
	else
		return Vec2(o1.x + o2.x, o1.y + o2.y)
	end
end

function Vec2.__sub(o1, o2)
	if type(o2) == "number" then
		return Vec2(o1.x - o2, o1.y - o2)
	else
		return Vec2(o1.x - o2.x, o1.y - o2.y)
	end
end

function Vec2.__mul(o1, o2)
	if type(o2) == "number" then
		return Vec2(o1.x * o2, o1.y * o2)
	else
		return Vec2(o1.x * o2.x, o1.y * o2.y)
	end
end

function Vec2.__div(o1, o2)
	if type(o2) == "number" then
		return Vec2(o1.x / o2, o1.y / o2)
	else
		return Vec2(o1.x / o2.x, o1.y / o2.y)
	end
end

function Vec2.min(o1, o2)
	if type(o2) == "number" then
		return Vec2(math.min(o1.x, o2), math.min(o1.y, o2))
	else
		return Vec2(math.min(o1.x, o2.x), math.min(o1.y, o2.y))
	end
end

function Vec2.max(o1, o2)
	if type(o2) == "number" then
		return Vec2(math.max(o1.x, o2), math.max(o1.y, o2))
	else
		return Vec2(math.max(o1.x, o2.x), math.max(o1.y, o2.y))
	end
end

--function Vec2.__idiv(o1, o2) return Vec2(o1.x // o2.x, o1.y // o2.y) end


return Vec2