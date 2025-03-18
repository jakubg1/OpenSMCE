self.integers = {}
for n, _ in pairs(data.integers) do
    self.integers[tonumber(n)] = u.parseBoolean(data.integers[n], path, "integers." .. tostring(n) .. "")
end

self.nonNegative = {}
for n, _ in pairs(data.nonNegative) do
    self.nonNegative[tonumber(n)] = u.parseBoolean(data.nonNegative[n], path, "nonNegative." .. tostring(n) .. "")
end

self.negative = {}
for n, _ in pairs(data.negative) do
    self.negative[tonumber(n)] = u.parseBoolean(data.negative[n], path, "negative." .. tostring(n) .. "")
end

self.any = {}
for n, _ in pairs(data.any) do
    self.any[n] = u.parseBoolean(data.any[n], path, "any." .. tostring(n) .. "")
end

self.characters = {}
for n, _ in pairs(data.characters) do
    self.characters[n] = u.parseBoolean(data.characters[n], path, "characters." .. tostring(n) .. "")
end