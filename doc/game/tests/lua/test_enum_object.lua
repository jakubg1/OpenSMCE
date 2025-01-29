self.type = u.parseString(data.type, path, "type")
if self.type == "string" then
    self.value = u.parseString(data.value, path, "value")
elseif self.type == "number" then
    self.value = u.parseNumber(data.value, path, "value")
elseif self.type == "both" then
    self.value = u.parseString(data.value, path, "value")
    self.value = u.parseNumber(data.value, path, "value")
elseif self.type == "none" then
    -- No fields
else
    error(string.format("Unknown ExampleObject type: %s (expected \"string\", \"number\", \"both\", \"none\")", self.type))
end
self.visible = u.parseBooleanOpt(data.visible, path, "visible")