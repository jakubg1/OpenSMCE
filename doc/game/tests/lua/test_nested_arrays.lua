---@type {two: {three: {value: integer}[]}[]}[]
self.one = {}
for i = 1, #data.one do
    self.one[i].two = {}
    for j = 1, #data.one[i].two do
        self.one[i].two[j].three = {}
        for k = 1, #data.one[i].two[j].three do
            self.one[i].two[j].three[k].value = u.parseInteger(data, base, path, {"one", i, "two", j, "three", k, "value"})
        end
    end
end