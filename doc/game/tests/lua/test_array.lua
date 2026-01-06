---@type number[]
self.listOfNumbers = {}
for i = 1, #data.listOfNumbers do
    self.listOfNumbers[i] = u.parseNumber(data, base, path, {"listOfNumbers", i})
end