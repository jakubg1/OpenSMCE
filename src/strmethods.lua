---Splits a string `s` with the delimiter being `k`.
---@param s string A string to be split.
---@param k string A delimiter which determines where to split `s`.
---@return table t A table of strings the input string has been split to.
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



---Combines a table of strings together to produce a string.
---@param t table A table of strings to be combined.
---@param k string A delimiter which will separate the terms.
---@return string s A combined string.
function _StrJoin(t, k)
	local s = ""
	for i, n in ipairs(t) do
		if i > 1 then s = s .. k end
		s = s .. n
	end
	return s
end



---Trims whitespace from both the beginning and the end of a given string.
---Currently supported whitespace characters are `" "` and `"\t"`.
---@param s string A string to be truncated.
---@return string s A truncated string.
function _StrTrim(s)
	-- truncate leading whitespace
	while s:sub(1, 1) == " " or s:sub(1, 1) == "\t" do s = s:sub(2) end
	-- truncate trailing whitespace
	while s:sub(s:len(), s:len()) == " " or s:sub(s:len(), s:len()) == "\t" do s = s:sub(1, s:len() - 1) end

	return s
end



---Trims a line from a trailing comment.
---The only supported comment marker is `//`.
---
---Example: `"abcdef   // ghijkl"` will be truncated to `"abcdef"`.
---@param s string A string to be truncated.
---@return string s A truncated string.
function _StrTrimCom(s)
	-- truncate the comment part and trim
	return _StrTrim(_StrSplit(s, "//")[1])
end



-- Strips the formatted text from formatting, if exists.
function _StrUnformat(s)
	if type(s) == "table" then
		local t = ""
		for i = 1, #s / 2 do
			t = t .. s[i * 2]
		end
		return t
	else
		return s
	end
end



-- Checks whether the whole string is in a single bracket.
function _StrIsInWholeBracket(s)
	if s:sub(1, 1) ~= "(" or s:sub(s:len()) ~= ")" then
		return false
	end
	
	local pos = 2
	local brackets = 1

	-- Test whether this is the same bracket at the beginning and at the end.
	while pos < s:len() do
		-- Get the character.
		local c = s:sub(pos, pos)
		-- Update the bracket count.
		if c == "(" then
			brackets = brackets + 1
		elseif c == ")" then
			brackets = brackets - 1
		end
		-- If we're out of the root bracket, return false.
		if brackets == 0 then
			return false
		end
		pos = pos + 1
	end
	
	return true
end



---A simple function which makes JSON formatting nicer.
---@param s string Raw JSON input.
---@return string output Beautiful JSON output.
function _JsonBeautify(s)
	local indent = 0
	local ret = "" -- returned string
	local ln = "" -- current line
	local strMode = false -- if we're inside a string chain (")

	for i = 1, s:len() do
		local pc = s:sub(i-1, i-1) -- previous character
		local c = s:sub(i, i) -- this character
		local nc = s:sub(i+1, i+1) -- next character
		local strModePrev = false -- so we don't switch this back off on the way

		if not strMode and c == "\"" then
			strMode = true
			strModePrev = true
		end
		if strMode then -- strings are not JSON syntax, so they omit the formatting rules
			ln = ln .. c
			if not strModePrev and c == "\"" and pc ~= "\\" then strMode = false end
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
