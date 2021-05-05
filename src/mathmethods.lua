function mathWeightedRandom(weights)
	local t = 0
	for i, w in ipairs(weights) do
		t = t + w
	end
	local rnd = math.random(t) -- from 1 to t, inclusive, integer!!
	local i = 1
	while rnd > weights[i] do
		rnd = rnd - weights[i]
		i = i + 1
	end
	return i
end
