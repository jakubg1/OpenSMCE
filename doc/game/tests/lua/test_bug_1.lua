self.obj = {}
self.obj.type = u.parseString(data.obj.type, path, "obj.type")
if self.obj.type == "test" then
    -- No fields
else
    error(string.format("Unknown obj type: %s (expected \"test\")", self.obj.type))
end

if data.obj.a then
    self.obj.a = {}
    self.obj.a.field = u.parseInteger(data.obj.a.field, path, "obj.a.field")
end