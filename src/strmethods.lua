function _StrSplit(s, k)
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

function _StrJoin(t, k)
	local s = ""
	for i, n in ipairs(t) do
		if i > 1 then s = s .. k end
		s = s .. n
	end
	return s
end

function _StrTrim(s)
	-- truncate leading whitespace
	while s:sub(1, 1) == " " or s:sub(1, 1) == "\t" do s = s:sub(2) end
	-- truncate trailing whitespace
	while s:sub(s:len(), s:len()) == " " or s:sub(s:len(), s:len()) == "\t" do s = s:sub(1, s:len() - 1) end

	return s
end

function _StrTrimCom(s)
	-- truncate the comment part and trim
	return _StrTrim(_StrSplit(s, "//")[1])
end

function _JsonBeautify(s)
	local indent = 0
	local ret = "" -- returned string
	local ln = "" -- current line
	local strMode = false -- if we're inside a string chain (")

	for i = 1, s:len() do
		local pc = s:sub(i-1, i-1) -- previous character
		local c = s:sub(i, i) -- this character
		local nc = s:sub(i+1, i+1) -- next character
		if not strMode and c == "\"" then strMode = true end
		if strMode then -- strings are not JSON syntax, so they omit the formatting rules
			ln = ln .. c
			if c == "\"" and pc ~= "\\" then strMode = false end
		else
			if (c == "]" or c == "}") and not (pc == "[" or pc == "{") then
				indent = indent - 1
				ret = ret .. ln .. "\n"
				ln = string.rep("\t", indent)			-- NEWLINE
			end
			ln = ln .. c
			if c == ":" then
				ln = ln .. " " -- spacing after colons, for more juice
			end
			if c == "," then
				ret = ret .. ln .. "\n"
				ln = string.rep("\t", indent)			-- NEWLINE
			end
			if (c == "[" or c == "{") and not (nc == "]" or nc == "}") then
				indent = indent + 1
				ret = ret .. ln .. "\n"
				ln = string.rep("\t", indent)			-- NEWLINE
			end
		end
	end

	ret = ret .. ln .. "\n"

	return ret
end
