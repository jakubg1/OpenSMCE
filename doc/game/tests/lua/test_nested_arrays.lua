self.one = {}
for i = 1, #data.one do
    self.one[i].two = {}
    for j = 1, #data.one[i].two do
        self.one[i].two[j].three = {}
        for k = 1, #data.one[i].two[j].three do
            self.one[i].two[j].three[k].value = u.parseInteger(data.one[i].two[j].three[k].value, path, "one[" .. tostring(i) .. "].two[" .. tostring(j) .. "].three[" .. tostring(k) .. "].value")
        end
    end
end