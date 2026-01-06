---@type {contents: string, inner: {contents: string}}
self.outer = {}
self.outer.contents = u.parseString(data, base, path, {"outer", "contents"})

self.outer.inner = {}
self.outer.inner.contents = u.parseString(data, base, path, {"outer", "inner", "contents"})