self.outer = {}
self.outer.contents = u.parseString(data.outer.contents, path, "outer.contents")

self.outer.inner = {}
self.outer.inner.contents = u.parseString(data.outer.inner.contents, path, "outer.inner.contents")