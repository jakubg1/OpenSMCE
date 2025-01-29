self.object = {}
for n, _ in pairs(data.object) do
    self.object[tonumber(n)] = u.parseBoolean(data.object[n], path, "object." .. tostring(n) .. "")
end