-- Original code from @bncastle
-- https://github.com/bncastle/love2d-tutorial/blob/Episode4/class.lua
-- is published under MIT license.
-- This code has been modified for compliance with luadoc and LuaLS.
-- Feel free to reuse.
-- @jakubg1 2025

---@class Class
local Class = {type = "Class", ptr = ": 0x123456789abc"}
Class.__index = Class

-- default implementation
function Class:new(...) end

-- create a new Class type from our base class
function Class:derive(type)
    local cls = {}
    cls["__call"] = Class.__call
    cls["__tostring"] = Class.__tostring
    cls.type = type
    cls.__index = cls
    cls.super = self
    cls.ptr = tostring(self):sub(6)
    setmetatable(cls, self)
    return cls
end

function Class:__call(...)
    local inst = setmetatable({}, self)
    inst:new(...)
    return inst
end

function Class:__tostring()
    return self.type .. self.ptr
end

function Class:get_type()
    return self.type
end

return Class