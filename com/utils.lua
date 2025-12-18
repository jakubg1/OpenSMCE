-- utils.lua by jakubg1
-- version for OpenSMCE (might consider expanding this so that they get their own repository)

local utf8 = require("utf8")
local json = require("com.json")

local utils = {}

---@alias Shortcut {key: string, shift: boolean?, ctrl: boolean?}
---@alias RawColor [number, number, number]

--################################################--
---------------- F I L E S Y S T E M ---------------
--################################################--

---Loads a file from a given path and returns its contents, or `nil` if the file has not been found.
---@param path string The path to the file.
---@return string?
function utils.loadFile(path)
	local file, err = io.open(path, "r")
	if not file then
		-- Try also returning data from inside the executable if fused.
		return love.filesystem.read(path)
	end
	io.input(file)
	local contents = io.read("*a")
	io.close(file)
	return contents
end

---Loads a file from a given path and returns its contents in binary form, or `nil` if the file has not been found.
---@param path string The path to the file.
---@return string?
function utils.loadFileBinary(path)
	local file, err = io.open(path, "rb")
	if not file then
		-- Try also returning data from inside the executable if fused.
		return love.filesystem.read(path)
	end
	io.input(file)
	local contents = io.read("*a")
	io.close(file)
	return contents
end

---Saves a file to the given path with the given contents. Errors out if the file cannot be created.
---@param path string The path to the file.
---@param data string The contents of the file.
---@param append boolean? If set to `true`, the data will be appended at the end of the file, if it exists.
function utils.saveFile(path, data, append)
	local file = io.open(path, append and "a" or "w")
	assert(file, string.format("SAVE FILE FAIL: %s", path))
	io.output(file)
	io.write(data)
	io.close(file)
end

---Loads a file from a given path and interprets it as JSON data. Returns `nil` if the file doesn't exist. Errors out if the file does not contain valid JSON data.
---@param path string The path to the file.
---@return table?
function utils.loadJson(path)
	local contents = utils.loadFile(path)
	if not contents then
		return nil
	end
	local success, data = pcall(function() return json.decode(contents) end)
	assert(success, string.format("JSON error: %s: %s", path, tostring(data)))
	assert(data, string.format("Could not JSON-decode: %s, error in file contents", path))
	return data
end

---Saves a file to the given path with the given contents, converted and beautified in JSON format. Errors out if the file cannot be created.
---@param path string The path to the file.
---@param data table The contents of the file.
function utils.saveJson(path, data)
	utils.saveFile(path, utils.jsonBeautify(json.encode(data)))
end

-- This function allows to load images from external sources.
-- This is an altered code from https://love2d.org/forums/viewtopic.php?t=85350#p221460

---Opens an image file and returns its data.
---Returns `nil` if the file has not been found.
---@param path string The path to the file.
---@return love.ImageData?
function utils.loadImageData(path)
	local data = utils.loadFileBinary(path)
	if data then
		data = love.filesystem.newFileData(data, "tempname")
		data = love.image.newImageData(data)
		return data
	end
end

---Opens an image file and constructs `love.Image` from it.
---Returns `nil` if the file has not been found.
---@param path string The path to the file.
---@return love.Image?
function utils.loadImage(path)
	local imageData = utils.loadImageData(path)
	if not imageData then
		return
	end
	return love.graphics.newImage(imageData)
end

-- This function allows to load sounds from external sources.
-- This is an altered code from the above function.

---Opens a sound file and returns its sound data. Returns `nil` if the file has not been found.
---@param path string The path to the file.
---@return love.SoundData?
function utils.loadSoundData(path)
	local data = utils.loadFileBinary(path)
	if data then
		-- to make everything work properly, we need to get the extension from the path, because it is used
		-- source: https://love2d.org/wiki/love.filesystem.newFileData
		local t = utils.strSplit(path, ".")
		local extension = t[#t]
		data = love.filesystem.newFileData(data, "tempname." .. extension)
		data = love.sound.newSoundData(data)
		return data
	end
end

---Opens a sound file and constructs `love.Source` from it. Returns `nil` if the file has not been found.
---@param path string The path to the file.
---@param type "static"|"stream" How the sound should be loaded: `"static"` or `"stream"`.
---@return love.Source?
function utils.loadSound(path, type)
	local soundData = utils.loadSoundData(path)
	return soundData and love.audio.newSource(soundData, type)
end

-- This function allows to load fonts from external sources.
-- This is an altered code from the above function.

---Opens a font file and returns its font data. Returns `nil` if the file has not been found.
---@param path string The path to the file.
---@param size integer? The size of the font, in pixels. Defaults to LOVE-specified 12 pixels.
---@return love.Rasterizer?
function utils.loadFontData(path, size)
	local data = utils.loadFileBinary(path)
	if data then
		data = love.filesystem.newFileData(data, "tempname")
		data = love.font.newRasterizer(data, size)
		return data
	end
end

---Opens a font file and constructs `love.Font` from it. Returns `nil` if the file has not been found.
---@param path string The path to the file.
---@param size integer? The size of the font, in pixels. Defaults to LOVE-specified 12 pixels.
---@return love.Font?
function utils.loadFont(path, size)
	local fontData = utils.loadFontData(path, size)
	return fontData and love.graphics.newFont(fontData)
end

---Opens a shader file and constructs `love.Shader` from it. Returns `nil` if file not found.
---@param path string The path to the file.
---@return love.Shader?
function utils.loadShader(path)
	local data = utils.loadFile(path)
	return data and love.graphics.newShader(data)
end

---Returns a list of directories and/or files in a given path.
---@param path string The path to the folder of which contents should be checked.
---@param filter string? `"dir"` will only list directories, `"file"` will only list files, `"all"` (default) will list both.
---@param extFilter string? If provided, files will have to end with this string in order to be listed. For example, `".json"` will only list `.json` files.
---@param recursive boolean? If set, files and directories will be checked recursively. Otherwise, only directories and files in this exact folder will be listed.
---@param pathRec string? Internal usage. Don't set.
---@return table
function utils.getDirListing(path, filter, extFilter, recursive, pathRec)
	-- filter can be "all", "dir" for directories only or "file" for files only.
	filter = filter or "all"
	pathRec = pathRec or ""

	local result = {}
	-- If it's compiled /fused/, this piece of code is needed to be able to read the external files
	if love.filesystem.isFused() then
		local success = love.filesystem.mount(love.filesystem.getSourceBaseDirectory(), _FSPrefix)
		if not success then
			local msg = string.format("Failed to read contents of folder: \"%s\". Report this error to a developer.", path)
			error(msg)
		end
	end
	-- Now we can access the directory regardless of whether it's fused or not.
	local items = love.filesystem.getDirectoryItems(path .. "/" .. pathRec)
	-- Each folder will get a / character on the end BUT ONLY IN "ALL" FILTER so it's easier to tell whether this is a file or a directory.
	for i, item in ipairs(items) do
		local p = path .. "/" .. pathRec .. item
		if not love.filesystem.getInfo(p) then
			print("File " .. p .. " doesn't exist DESPITE BEING LISTED - skipping!")
		elseif love.filesystem.getInfo(p).type == "directory" then
			if filter == "all" then
				table.insert(result, pathRec .. item .. "/")
			elseif filter == "dir" then
				table.insert(result, pathRec .. item)
			end
			if recursive then
				for j, file in ipairs(utils.getDirListing(path, filter, extFilter, true, pathRec .. item .. "/")) do
					table.insert(result, file)
				end
			end
		else
			if filter == "all" or filter == "file" and (not extFilter or utils.strEndsWith(item, extFilter)) then
				table.insert(result, pathRec .. item)
			end
		end
	end
	-- Unmount it so we don't get into safety problems.
	if pathRec == "" then
		love.filesystem.unmount(love.filesystem.getSourceBaseDirectory())
	end
	return result
end

--########################################--
---------------- T A B L E S ---------------
--########################################--

---Returns `true` if the provided value is in the table.
---@param t table The table to be checked.
---@param v any The value to be checked. The function will return `true` if this value is inside the `t` table.
---@return boolean
function utils.isValueInTable(t, v)
	for i, n in pairs(t) do
		if n == v then
			return true
		end
	end
	return false
end

---Returns an index of the value in the provided table, or `nil` if the value does not exist in the table.
---@param t table The table to be checked.
---@param v any The value to be checked. The function will return an index of the first matching value from the `t` table.
---@return any?
function utils.getKeyInTable(t, v)
	for i, n in pairs(t) do
		if n == v then
			return i
		end
	end
end

---Removes all occurences of the value `v` from the table `t`. Don't use this on itables!
---@param t table The table to be checked.
---@param v any The value to be removed from the table `t`.
function utils.tableRemoveValue(t, v)
	for i, n in pairs(t) do
		if n == v then
			t[i] = nil
		end
	end
end

---Removes all occurences of the value `v` from the table `t`. Don't use this on keyed tables!
---@param t table The table to be checked.
---@param v any The value to be removed from the table `t`.
function utils.iTableRemoveValue(t, v)
	for i = #t, 1, -1 do
		if t[i] == v then
			table.remove(t, i)
		end
	end
end

---Returns the index of the first occurence of the provided value in the given table.
---Returns `nil` if the value is not found.
---Don't use this on keyed tables!
---@param t table The table to be checked.
---@param v any The value to be found in the table `t`.
---@return integer?
function utils.iTableGetValueIndex(t, v)
	for i = 1, #t do
		if t[i] == v then
			return i
		end
	end
end

---Returns the index of the last occurence of the provided value in the given table.
---Returns `nil` if the value is not found.
---Don't use this on keyed tables!
---@param t table The table to be checked.
---@param v any The value to be found in the table `t`.
---@return integer?
function utils.iTableGetLastValueIndex(t, v)
	for i = #t, 1, -1 do
		if t[i] == v then
			return i
		end
	end
end

---Removes the first occurence of the value `v` from the table `t`. Don't use this on keyed tables!
---@param t table The table to be checked.
---@param v any The value to be removed from the table `t`.
function utils.iTableRemoveFirstValue(t, v)
	local i = utils.iTableGetValueIndex(t, v)
	if i then
		table.remove(t, i)
	end
end

---Removes the last occurence of the value `v` from the table `t`. Don't use this on keyed tables!
---@param t table The table to be checked.
---@param v any The value to be removed from the table `t`.
function utils.iTableRemoveLastValue(t, v)
	local i = utils.iTableGetLastValueIndex(t, v)
	if i then
		table.remove(t, i)
	end
end

---Returns a table with duplicate values from table `t` removed.
---@param t table The table to have duplicate values removed.
---@return table
function utils.tableRemoveDuplicates(t)
	local values = {}
	local r = {}
	for i, v in ipairs(t) do
		if not values[v] then
			values[v] = true
			table.insert(r, v)
		end
	end
	return r
end

---Removes duplicate values from table `t`.
---@param t table The table to have duplicate values removed.
function utils.tableRemoveDuplicatesInplace(t)
	local values = {}
	local i = 1
	while i < #t do
		if values[t[i]] then
			table.remove(t, i)
		else
			i = i + 1
		end
		values[t[i]] = true
	end
end

---Returns a table with combined entries of both tables. Duplicates are not removed.
---@param t1 table The first table.
---@param t2 table The second table.
---@return table
function utils.tableAdd(t1, t2)
	local t = {}
	utils.tableAddInplace(t, t1)
	utils.tableAddInplace(t, t2)
	return t
end

---Adds all entries from `t2` to the table `t1`. Duplicates are not removed.
---@param t1 table The first table.
---@param t2 table The second table.
function utils.tableAddInplace(t1, t2)
	for i, v in ipairs(t2) do
		table.insert(t1, v)
	end
end

---Returns a table with combined entries of both tables. All values are unique; duplicates are removed.
---@param t1 table The first table.
---@param t2 table The second table.
---@return table
function utils.tableUnion(t1, t2)
	return utils.tableRemoveDuplicates(utils.tableAdd(t1, t2))
end

---Adds all entries from `t2` to the table `t1`. Duplicates are removed.
---@param t1 table The first table.
---@param t2 table The second table.
function utils.tableUnionInplace(t1, t2)
	utils.tableAddInplace(t1, t2)
	utils.tableRemoveDuplicatesInplace(t1)
end

---Returns a table with entries which are only present in both tables.
---@param t1 table The first table.
---@param t2 table The second table.
---@return table
function utils.tableMultiply(t1, t2)
	local t = {}
	for i, v in ipairs(t1) do
		if utils.isValueInTable(t2, v) then
			table.insert(t, v)
		end
	end
	return t
end

---Returns a table `t1` with all values from the table `t2` removed.
---@param t1 table The table which contains the possible values.
---@param t2 table The table which should be subtracted from the first table.
---@return table
function utils.tableSubtract(t1, t2)
	local t = {}
	for i, v in ipairs(t1) do
		if not utils.isValueInTable(t2, v) then
			table.insert(t, v)
		end
	end
	return t
end

---Returns whether the provided table is an array (has only numerical keys going from 1 to the size of the table).
---@param t table The table to be checked.
---@return boolean
function utils.tableIsArray(t)
	-- Source: https://stackoverflow.com/questions/7526223/how-do-i-know-if-a-table-is-an-array
	local i = 0
	for _ in pairs(t) do
		i = i + 1
		if t[i] == nil then
			return false
		end
	end
	return true
end

---Creates and returns a shallow copy of the given table.
---@param t table The table to be copied.
---@return table
function utils.copyTable(t)
	local new = {}
	for k, v in pairs(t) do
		new[k] = v
	end
	return new
end

---Removes all elements from the given table. Useful for reducing the table footprint.
---@param t table The table to be emptied.
function utils.emptyTable(t)
	for k, v in pairs(t) do
		t[k] = nil
	end
end

---Returns `true` if the table does not contain any keys.
---@param t table The potentially empty table.
---@return boolean
function utils.tableIsEmpty(t)
	for k, v in pairs(t) do
		return false
	end
	return true
end

---Shuffles the elements in the table `t`.
---@param t table The table to be shuffled.
function utils.tableShuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
end

---Returns a list of all keys in table `t`, sorted alphabetically.
---@param t table The table from which the keys will be sourced.
---@return table
function utils.tableGetSortedKeys(t)
	local keys = {}
	for k, v in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

---Removes all dead objects from the table `t`. By dead objects we mean objects that have their `delQueue` field set to `true`.
---The table must be a list-like. Other keysets are not supported.
---@param t table The table to be cleaned up.
function utils.removeDeadObjects(t)
	for i = #t, 1, -1 do
		if t[i].delQueue then
			table.remove(t, i)
		end
	end
end

---Creates a multidimensional table (table of tables).
---@param value any? The default value for all table elements. If `nil`, the table will be empty. If a function, the function's will be called for each item and the result will be put.
---@param dimSize integer? First of the dimensions. If `nil`, returns the raw `value`.
---@return any?
function utils.tableNewMultidim(value, dimSize, ...)
	if not dimSize then
		return type(value) == "function" and value() or value
	end
	local tbl = {}
	for i = 1, dimSize do
		tbl[i] = utils.tableNewMultidim(value, ...)
	end
	return tbl
end

--##########################################--
---------------- S T R I N G S ---------------
--##########################################--

---Splits a string `s` with the delimiter being `k` and returns a list of results.
---@param s string A string to be split.
---@param k string A delimiter which determines where to split `s`.
---@return string[]
function utils.strSplit(s, k)
	local result = {}
	local l = k:len()
	while true do
		local n = s:find("%" .. k)
		if n then
			table.insert(result, s:sub(1, n - 1))
			s = s:sub(n + l)
		else
			table.insert(result, s)
			return result
		end
	end
end

---Splits a string `str` into characters. UTF-8 characters are respected.
---@param str string A string to be split.
---@return table
function utils.strSplitChars(str)
    local characters = {}
    for i = 1, utf8.len(str) do
        table.insert(characters, str:sub(utf8.offset(str, i), utf8.offset(str, i + 1) - 1))
    end
    return characters
end

---Combines a table of strings together to produce a string and returns the result.
---@param t table A table of strings to be combined.
---@param k string A delimiter which will separate the terms.
---@return string
function utils.strJoin(t, k)
	return table.concat(t, k)
end

---Indents a string `s` by adding `n` spaces at the front of each line.
---@param s string A string to be indented.
---@param n integer The amount of spaces to be added at the front of each line.
---@return string
function utils.strIndent(s, n)
	local l = utils.strSplit(s, "\n")
	for i = 1, #l do
		if l[i] ~= "" then
			l[i] = string.rep(" ", n) .. l[i]
		end
	end
	return utils.strJoin(l, "\n")
end

---Returns `true` if the string `s` contains the clause `c`.
---@param s string The string to be searched.
---@param c string The expected string to be found in `s`.
---@return boolean
function utils.strContains(s, c)
	return s:find(c) ~= nil
end

---Returns `true` if the string `s` starts with the clause `c`.
---@param s string The string to be searched.
---@param c string The expected beginning of the string `s`.
---@return boolean
function utils.strStartsWith(s, c)
	return s:sub(1, c:len()) == c
end

---Returns `true` if the string `s` ends with the clause `c`.
---@param s string The string to be searched.
---@param c string The expected ending of the string `s`.
---@return boolean
function utils.strEndsWith(s, c)
	return s:sub(s:len() - c:len() + 1) == c
end

---Trims whitespace from both the beginning and the end of a given string, and returns the result.
---Currently supported whitespace characters are `" "` and `"\t"`.
---@param s string A string to be truncated.
---@return string
function utils.strTrim(s)
	-- truncate leading whitespace
	while s:sub(1, 1) == " " or s:sub(1, 1) == "\t" do
        s = s:sub(2)
    end
	-- truncate trailing whitespace
	while s:sub(s:len(), s:len()) == " " or s:sub(s:len(), s:len()) == "\t" do
        s = s:sub(1, s:len() - 1)
    end

	return s
end

---Trims a line from a trailing comment.
---The only supported comment marker is `//`.
---
---Example: `"abcdef   // ghijkl"` will be truncated to `"abcdef"`.
---@param s string A string to be truncated.
---@return string
function utils.strTrimComment(s)
	-- truncate the comment part and trim
	return utils.strTrim(utils.strSplit(s, "//")[1])
end

---Strips the formatted text from formatting, if exists.
---@param s string|table A formatted string. If an unformatted string is passed, this function returns that string.
---@return string
function utils.strUnformat(s)
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

---Checks whether the whole string is inside a single pair of brackets.
---For example, `(abcdef)` and `(abc(def))` will return `true`, but `(ab)cd(ef)` and `a(bcdef)` will return `false`.
---@param s string The string to be checked.
---@return boolean
function utils.strIsInWholeBracket(s)
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

---Strips the extension from a path to a file.
---@param path string The path to have its extension stripped.
---@return string
function utils.pathStripExtension(path)
	local spl = utils.strSplit(path, ".")
	spl[#spl] = nil
	return utils.strJoin(spl, ".")
end

---Returns a single isolated line from the traceback at the given depth.
---The input string must contain the `"stack traceback:"` line. Lines are counted starting at that line.
---@param traceback string The raw traceback string.
---@param depth integer? The line index to get. Defaults to 1.
---@return string
function utils.isolateTracebackLine(traceback, depth)
	depth = depth or 1
	local lines = utils.strSplit(traceback, "\n")
	local stIndex = assert(utils.iTableGetValueIndex(lines, "stack traceback:"), "Provided traceback does not contain the \"stack traceback:\" line!")
	return utils.strTrim(lines[stIndex + depth])
end

---A simple function which makes JSON formatting nicer.
---@param s string Raw JSON input to be formatted.
---@return string
function utils.jsonBeautify(s)
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
			if not strModePrev and c == "\"" and pc ~= "\\" then
                strMode = false
            end
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

---Takes a table with a required `key` string field and optional `ctrl` and `shift` boolean fields.
---Returns a human-readable shortcut name.
---@param shortcut Shortcut The shortcut to be turned into a string.
---@return string
function utils.getShortcutString(shortcut)
	local value = string.format("[%s]", shortcut.key)
	if shortcut.shift then
		value = "Shift + " .. value
	end
	if shortcut.ctrl then
		value = "Ctrl + " .. value
	end
	return value
end

--####################################--
---------------- M A T H ---------------
--####################################--

---Returns an index of the provided weight list, randomly picked from that list.
---For example, providing `{1, 2, 3}` will return `1` 1/6 of the time, `2` 2/6 of the time and `3` 3/6 of the time.
---@param weights table A list of integers, which depict the weights.
---@return integer
function utils.weightedRandom(weights)
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

---Separates thousands, millions, billions, etc. of a number with commas.
---@param n number The number to be formatted.
---@return string
function utils.formatNumber(n)
	local text = ""
	local s = tostring(n)
	local l = s:len()
	for i = 1, l do
		text = text .. s:sub(i, i)
		if l - i > 0 and (l - i) % 3 == 0 then text = text .. "," end
	end
	return text
end

---Returns `true` if the given position is inside of a box of given position and size.
---If the point lies anywhere on the box's edge, the check will still pass.
---@param x number The X coordinate of the point which is checked against.
---@param y number The Y coordinate of the point which is checked against.
---@param bx number The X position of the top left corner of the box.
---@param by number The Y position of the top left corner of the box.
---@param bw number The width of the box.
---@param bh number The height of the box.
---@return boolean
function utils.isPointInsideBox(x, y, bx, by, bw, bh)
	return x >= bx and y >= by and x <= (bx + bw) and y <= (by + bh)
end

---Returns `true` if the given position is inside of a box of given position and size.
---If the point lies anywhere on the box's edge, the check will fail.
---@param x number The X coordinate of the point which is checked against.
---@param y number The Y coordinate of the point which is checked against.
---@param bx number The X position of the top left corner of the box.
---@param by number The Y position of the top left corner of the box.
---@param bw number The width of the box.
---@param bh number The height of the box.
---@return boolean
function utils.isPointInsideBoxExcl(x, y, bx, by, bw, bh)
	return x > bx and y > by and x < (bx + bw) and y < (by + bh)
end

-- One-dimensional cubic Beazier curve.
-- More info: http://www.demofox.org/bezcubic1d.html
-- The given expression can be simplified, because we are defining A = 0 and D = 1.
-- The shortened expression: y = B * 3x(1-x)^2 + C * 3x^2(1-x) + x^3
-- x is t, B is p1 and C is p2.
function utils.bzLerp(t, p1, p2)
	local b = p1 * (3 * t * ((1 - t) ^ 2))
	local c = p2 * (3 * (t ^ 2) * (1 - t))
	local d = t ^ 3
	return b + c + d
end

---Returns `true` if two ranges of numbers intersect (at least one number is common).
---@param s1 number The start of the first range.
---@param e1 number The end of the first range.
---@param s2 number The start of the second range.
---@param e2 number The end of the second range.
---@return boolean
function utils.doRangesIntersect(s1, e1, s2, e2)
	return s1 <= e2 and s2 <= e1
end

---Returns `true` if the first range of numbers is fully contained within the second range.
---This function does NOT return `true` if the second range is contained in the first range!
---@param s1 number The start of the first range.
---@param e1 number The end of the first range.
---@param s2 number The start of the second range.
---@param e2 number The end of the second range.
---@return boolean
function utils.areRangesContained(s1, e1, s2, e2)
	return s1 >= s2 and e1 <= e2
end

---Returns `true` if the first box intersects the second box in any way.
---@param x1 number X position of the top left corner of the first box.
---@param y1 number Y position of the top left corner of the first box.
---@param w1 number Width of the first box.
---@param h1 number Height of the first box.
---@param x2 number X position of the top left corner of the second box.
---@param y2 number Y position of the top left corner of the second box.
---@param w2 number Width of the second box.
---@param h2 number Height of the second box.
---@return boolean
function utils.doBoxesIntersect(x1, y1, w1, h1, x2, y2, w2, h2)
	assert(w1 >= 0 and h1 >= 0 and w2 >= 0 and h2 >= 0, "Illegal boxes passed to `_Utils.doBoxesIntersect()`! You must normalize the boxes first using `_Utils.normalizeBox(x, y, w, h)`.")
	return utils.doRangesIntersect(x1, x1 + w1, x2, x2 + w2) and utils.doRangesIntersect(y1, y1 + h1, y2, y2 + h2)
end

---Returns `true` if the first box is fully contained in the second box.
---This function does NOT return `true` if the second box is contained in the first box instead!
---@param x1 number X position of the top left corner of the first box.
---@param y1 number Y position of the top left corner of the first box.
---@param w1 number Width of the first box.
---@param h1 number Height of the first box.
---@param x2 number X position of the top left corner of the second box.
---@param y2 number Y position of the top left corner of the second box.
---@param w2 number Width of the second box.
---@param h2 number Height of the second box.
---@return boolean
function utils.areBoxesContained(x1, y1, w1, h1, x2, y2, w2, h2)
	assert(w1 >= 0 and h1 >= 0 and w2 >= 0 and h2 >= 0, "Illegal boxes passed to `_Utils.doBoxesIntersect()`! You must normalize the boxes first using `_Utils.normalizeBox(x, y, w, h)`.")
	return utils.areRangesContained(x1, x1 + w1, x2, x2 + w2) and utils.areRangesContained(y1, y1 + h1, y2, y2 + h2)
end

---Normalizes a box to make sure it does not have a negative width and/or height.
---@param x number X position of the top left corner of the box.
---@param y number Y position of the top left corner of the box.
---@param w number Width of the box.
---@param h number Height of the box.
---@return number, number, number, number
function utils.normalizeBox(x, y, w, h)
	return math.min(x, x + w), math.min(y, y + h), math.abs(w), math.abs(h)
end

---Clamps a number `n` into range `<a, b>`.
---@param n number The number to be clamped.
---@param a number? The minimum possible value. Defaults to `0`.
---@param b number? The maximum possible value. Defaults to `1`.
---@return number
function utils.clamp(n, a, b)
	return math.min(math.max(n, a or 0), b or 1)
end

---Interpolates a number from `a` to `b` based on time `t`.
---When `t = 0`, `a` is returned, and when `t = 1`, `b` is returned.
---@param a number The value for `t = 0`.
---@param b number The value for `t = 1`.
---@param t number The time parameter.
---@return number
function utils.lerp(a, b, t)
	return a * (1 - t) + b * t
end

---Interpolates a number from `a` to `b` based on **clamped** time `t`.
---The result for `t < 0` is the same as `t = 0`, and the result for `t > 1` is the same as `t = 1`.
---@param a number The value for `t <= 0`.
---@param b number The value for `t >= 1`.
---@param t number The time parameter.
---@return number
function utils.lerpc(a, b, t)
	return utils.lerp(a, b, utils.clamp(t))
end

---Interpolates a number from `a` to `b` based on time `t` in range from `t1` to `t2`.
---@param a number The value for `t = t1`.
---@param b number The value for `t = t2`.
---@param t1 number The time for which `a` is returned.
---@param t2 number The time for which `b` is returned.
---@param t number The time parameter.
---@return number
function utils.map(a, b, t1, t2, t)
	return utils.lerp(a, b, (t - t1) / (t2 - t1))
end

---Interpolates a number from `a` to `b` based on **clamped** time `t` in range from `t1` to `t2`.
---The result for `t < t1` is the same as `t = t1`, and the result for `t > t2` is the same as `t = t2`.
---@param a number The value for `t <= t1`.
---@param b number The value for `t >= t2`.
---@param t1 number The time for which `a` is returned.
---@param t2 number The time for which `b` is returned.
---@param t number The time parameter.
---@return number
function utils.mapc(a, b, t1, t2, t)
	return utils.lerpc(a, b, (t - t1) / (t2 - t1))
end

---Returns a value in range from `-1` to `1` based on the sine wave.
---@param frequency number The frequency of the wave.
---@param speed number The speed of the wave.
---@param offset number The offset of the wave.
---@param time number The time.
---@return number
function utils.getWavePoint(frequency, speed, offset, time)
	return math.sin(((offset - speed * time) / frequency) % 1 * math.pi * 2)
end

---Returns `true` if both provided values are close enough to be considered equal. Useful for places where there is floating point imprecision.
---@param a number The first number to compare.
---@param b number The second number to compare.
---@param e number? The margin of error. Defaults to `1e-9`.
---@return boolean
function utils.almostEqual(a, b, e)
	e = e or 1e-9
	return a > b - e and a < b + e
end

---Returns `true` or `false` depending on whether `b`-th bit of number `n` is a `1` or a `0`.
---@param n integer The number to be checked.
---@param b integer The bit of the number `n` to be checked.
---@return boolean
function utils.getBit(n, b)
	return math.floor((n % (2 ^ b)) / (2 ^ (b - 1))) ~= 0
end

--####################################################--
---------------- C O L O R E D   T E X T ---------------
--####################################################--

---It is currently not possible to accurately describe this type using Luadoc.
---A table with alternating values: color in format of `{r, g, b}` and text which should be drawn using that color.
---Example: `{{1, 0, 0}, "red", {0, 1, 0}, "green", {1, 1, 1}, "white"}`
---@alias ColoredText table

---Splits a colored string `s` with the delimiter being `k` and returns a list of results.
---@param s ColoredText A LOVE Colored Text to be split.
---@param k string A delimiter which determines where to split `s`.
---@return ColoredText[]
function utils.ctextSplit(s, k)
	local result = {}
	for i = 2, #s, 2 do
		local color = s[i - 1]
		local substrs = utils.strSplit(s[i], k)
		for j, substr in ipairs(substrs) do
			-- The first chunk of this color should be merged with the last chunk of the previous color.
			-- Otherwise, create a new chunk.
			if j > 1 or #result == 0 then
				table.insert(result, {})
			end
			table.insert(result[#result], color)
			table.insert(result[#result], substr)
		end
	end
	return result
end

---Adds in-place a new text segment to the provided chunk of colored text.
---@param ctext ColoredText The colored text to be added to.
---@param text string|ColoredText The text or colored text to be added.
---@param color RawColor? The color of the new segment. If not specified, color of the previous segment will be used.
function utils.ctextAdd(ctext, text, color)
	local prevColor = ctext[#ctext - 1]
	local sameColor = color and prevColor and utils.areTablesIdentical(color, prevColor)
	if type(text) == "table" then
		utils.tableAddInplace(ctext, text)
	else
		if color and not sameColor then
			table.insert(ctext, color)
			table.insert(ctext, text)
		else
			if #ctext == 0 then
				-- If the colored text was empty, the first segment will be white.
				table.insert(ctext, {1, 1, 1})
				table.insert(ctext, text)
			else
				ctext[#ctext] = ctext[#ctext] .. text
			end
		end
	end
end

---Returns a substring of Colored Text.
---@param ctext ColoredText The colored text to be split.
---@param i integer The first character, 1-indexed.
---@param j integer The last character to be included in the returned string, 1-indexed, inclusive.
---@return ColoredText
function utils.ctextSub(ctext, i, j)
	local n = 0
	local result = {}
	for k = 1, #ctext, 2 do
		local color = ctext[k]
		local text = ctext[k + 1]
		local l = #text
		if i <= n + l then
			local subtext = text:sub(math.max(i - n, 1), math.min(j - n, l))
			utils.ctextAdd(result, subtext, color)
			if j <= n + l then
				break
			end
		end
		n = n + l
	end
	return result
end

---Returns the total length of Colored Text in bytes.
---@param ctext ColoredText The colored text to be calculated length of.
---@return integer
function utils.ctextLen(ctext)
	local l = 0
	for k = 1, #ctext, 2 do
		l = l + #ctext[k + 1]
	end
	return l
end

---Returns whether the provided value is a valid colored text.
---Empty tables are not considered colored text.
---@param value any The value to be checked.
---@return boolean
function utils.tableIsCtext(value)
	if type(value) ~= "table" or #value == 0 then
		return false
	end

	for i, v in ipairs(value) do
		if i % 2 == 1 then
			-- Must be a color.
			if type(v) ~= "table" or #v ~= 3 then
				return false
			end
		else
			-- Must be a string.
			if type(v) ~= "string" then
				return false
			end
		end
	end
	return true
end

--####################################################--
---------------- P R E T T Y   P R I N T ---------------
--####################################################--

local white = {1, 1, 1}
local blue = {0.2, 0.8, 1}
local yellow = {1, 0.7, 0.2}
local red = {1, 0, 0}
local green = {0, 1, 0.2}
local gray = {0.6, 0.6, 0.6}

---Turns any value into colored text.
---@param value any The value to be visualized.
---@param indent integer? The indent at which this value is located. Does not change the result if the value is not a table. Defaults to 0.
---@param usedTables table[]? Internally used for checking circular references.
---@return ColoredText
function utils.prettifyValue(value, indent, usedTables)
	indent = indent or 0
	usedTables = usedTables or {}
	if type(value) == "table" then
		if utils.tableIsCtext(value) then
			local ctext = {}
			utils.ctextAdd(ctext, "<\"", yellow)
			utils.ctextAdd(ctext, value)
			utils.ctextAdd(ctext, "\">", yellow)
			return ctext
		elseif utils.isValueInTable(usedTables, value) then
			return {red, "<circular reference>"}
		else
			return utils.prettifyTable(value, indent, usedTables)
		end
	elseif type(value) == "string" then
		return {blue, "\"" .. value .. "\""}
	elseif type(value) == "number" then
		return {yellow, tostring(value)}
	elseif type(value) == "boolean" then
		return value and {green, "true"} or {red, "false"}
	elseif type(value) == "nil" then
		return {gray, "nil"}
	end
	return {white, tostring(value)}
end

---Turns a table into colored text showing what is the contents of the table.
---Use `utils.prettifyValue()` instead!
---@param tbl table The table to be prettified.
---@param indent integer? How far should the output be indented. Defaults to 0.
---@param usedTables table[]? Internally used for checking circular references.
---@return ColoredText
function utils.prettifyTable(tbl, indent, usedTables)
	indent = indent or 0
	usedTables = usedTables or {}
	table.insert(usedTables, tbl)
	local result = {}

	-- Determine the properties of the table.
	local keys = utils.tableGetSortedKeys(tbl)
	local isArray = keys[1] == 1 and keys[#keys] == #keys
	local hasTables = false
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			hasTables = true
			break
		end
	end
	-- The `"type"` key will be always first.
	if utils.isValueInTable(keys, "type") then
		utils.removeValueFromTable(keys, "type")
		table.insert(keys, 1, "type")
	end

	utils.ctextAdd(result, isArray and "[" or "{", white)
	if hasTables then
		utils.ctextAdd(result, "\n", white)
	end
	for i, key in ipairs(keys) do
		local value = tbl[key]
		local valueText = utils.prettifyValue(value, indent + 1, usedTables)
		if hasTables then
			utils.ctextAdd(result, string.rep("    ", indent + 1), white)
		end
		if not isArray then
			utils.ctextAdd(result, key, key == "type" and yellow or white)
			utils.ctextAdd(result, ": ", white)
		end
		utils.ctextAdd(result, valueText)
		if i < #keys then
			utils.ctextAdd(result, ",", white)
			if not hasTables then
				utils.ctextAdd(result, " ", white)
			end
		end
		if hasTables then
			utils.ctextAdd(result, "\n", white)
		end
	end
	if hasTables then
		utils.ctextAdd(result, string.rep("    ", indent), white)
	end
	utils.ctextAdd(result, isArray and "]" or "}", white)
	return result
end

--##############################################################--
---------------- O P E N S M C E - S P E C I F I C ---------------
--##############################################################--

local Color = require("src.Essentials.Color")

---Returns a Color which lies on a selected point of the rainbow hue range.
---@param t number A point on the range, where 0 gives red, 0.333 gives green, 0.667 gives blue and 1 gives red again (wraps on both sides).
---@return Color
function utils.getRainbowColor(t)
	t = t * 3
	local r = utils.clamp(2 * (1 - math.abs(t % 3))) + utils.clamp(2 * (1 - math.abs((t % 3) - 3)))
	local g = utils.clamp(2 * (1 - math.abs((t % 3) - 1)))
	local b = utils.clamp(2 * (1 - math.abs((t % 3) - 2)))
	return Color(r, g, b)
end

return utils