self.a = u.parseIntegerOpt(data, base, path, {"a"}) or 2
self.b = u.parseNumberOpt(data, base, path, {"b"}) or -3.14
self.c = u.parseBooleanOpt(data, base, path, {"c"}) == true
self.d = u.parseBooleanOpt(data, base, path, {"d"}) ~= false
self.e = u.parseStringOpt(data, base, path, {"e"}) or "Hello, World!"
self.f = u.parseVec2Opt(data, base, path, {"f"}) or Vec2(-2.5, 6)