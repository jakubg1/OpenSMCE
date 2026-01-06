---@type {type: "test", a: {field: integer}?}
self.obj = {}
self.obj.type = u.parseString(data, base, path, {"obj", "type"})
if self.obj.type == "test" then
    -- No fields
else
    error(string.format("Unknown obj type: %s (expected \"test\")", self.obj.type))
end

if data.obj.a then
    self.obj.a = {}
    self.obj.a.field = u.parseInteger(data, base, path, {"obj", "a", "field"})
end