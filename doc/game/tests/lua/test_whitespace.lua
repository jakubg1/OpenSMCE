---@type {item: integer}
self.a = {}
self.a.item = u.parseInteger(data, base, path, {"a", "item"})

---@type {item: integer}
self.b = {}
self.b.item = u.parseInteger(data, base, path, {"b", "item"})

---@type {item: integer}
self.c = {}
self.c.item = u.parseInteger(data, base, path, {"c", "item"})

self.d = u.parseInteger(data, base, path, {"d"})
self.e = u.parseInteger(data, base, path, {"e"})
self.f = u.parseInteger(data, base, path, {"f"})

---@type {item: integer}
self.g = {}
self.g.item = u.parseInteger(data, base, path, {"g", "item"})