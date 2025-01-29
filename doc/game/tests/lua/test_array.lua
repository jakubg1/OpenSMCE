self.listOfNumbers = {}
for i = 1, #data.listOfNumbers do
    self.listOfNumbers[i] = u.parseNumber(data.listOfNumbers[i], path, "listOfNumbers[" .. tostring(i) .. "]")
end