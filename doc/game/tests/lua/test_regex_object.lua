self.integers = {}
for n, _ in pairs(data.integers) do
    self.integers[tonumber(n)] = u.parseBoolean(data, base, path, {"integers", n})
end

self.nonNegative = {}
for n, _ in pairs(data.nonNegative) do
    self.nonNegative[tonumber(n)] = u.parseBoolean(data, base, path, {"nonNegative", n})
end

self.negative = {}
for n, _ in pairs(data.negative) do
    self.negative[tonumber(n)] = u.parseBoolean(data, base, path, {"negative", n})
end

self.any = {}
for n, _ in pairs(data.any) do
    self.any[n] = u.parseBoolean(data, base, path, {"any", n})
end

self.characters = {}
for n, _ in pairs(data.characters) do
    self.characters[n] = u.parseBoolean(data, base, path, {"characters", n})
end