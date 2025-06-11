self.type = u.parseString(data, base, path, {"type"})
if self.type == "string" then
    self.value = u.parseString(data, base, path, {"value"})
elseif self.type == "number" then
    self.value = u.parseNumber(data, base, path, {"value"})
elseif self.type == "both" then
    self.value = u.parseString(data, base, path, {"value"})
    self.value = u.parseNumber(data, base, path, {"value"})
elseif self.type == "none" then
    -- No fields
else
    error(string.format("Unknown ExampleObject type: %s (expected \"string\", \"number\", \"both\", \"none\")", self.type))
end
self.visible = u.parseBooleanOpt(data, base, path, {"visible"})