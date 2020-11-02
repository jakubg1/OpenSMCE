function strSplit(s, k)
	local t = {}
	local l = k:len()
	while true do
		local n = s:find("%" .. k)
		if n then
			table.insert(t, s:sub(1, n - 1))
			s = s:sub(n + l)
		else
			table.insert(t, s)
			return t
		end
	end
end

function strJoin(t, k)
	s = ""
	for i, n in ipairs(t) do
		if i > 1 then s = s .. k end
		s = s .. n
	end
	return s
end