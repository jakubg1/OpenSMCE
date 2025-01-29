self.a = u.parseIntegerOpt(data.a, path, "a") or 2
self.b = u.parseNumberOpt(data.b, path, "b") or -3.14
self.c = u.parseBooleanOpt(data.c, path, "c") or false
self.d = u.parseBooleanOpt(data.d, path, "d") or true
self.e = u.parseStringOpt(data.e, path, "e") or "Hello, World!"
self.f = u.parseVec2Opt(data.f, path, "f") or Vec2(-2.5, 6)