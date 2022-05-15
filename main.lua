-- INCLUDE ZONE

-- custom error handler
require("crash")

local json = require("com/json")
local strmethods = require("src/strmethods")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")

local Debug = require("src/Kernel/Debug")

local BootScreen = require("src/Kernel/BootScreen")
local Game = require("src/Game")

local Settings = require("src/Kernel/Settings")

local DiscordRichPresence = require("src/DiscordRichPresence")



-- CONSTANT ZONE
_VERSION = "v0.43.0"
_VERSION_NAME = "Beta 4.3.0"
_DISCORD_APPLICATION_ID = "797956172539887657"


-- TODO: at some point, get rid of this and make it configurable
_NATIVE_RESOLUTION = Vec2(800, 600)





-- GLOBAL ZONE
_DisplaySize = Vec2(800, 600)
_DisplayFullscreen = false
_MousePos = Vec2(0, 0)
_KeyModifiers = {lshift = false, lctrl = false, lalt = false, rshift = false, rctrl = false, ralt = false}
-- File system prefix. On Windows defaults to "", on Android defaults to "/sdcard/".
_FSPrefix = ""

_Game = nil
_Debug = nil

_VariableSet = {}

_TotalTime = 0
_TimeScale = 1



_EngineSettings = nil
_DiscordRPC = nil








-- CALLBACK ZONE
function love.load()
	--local s = loadFile("test.txt")
	--print(s)
	--print(jsonBeautify(s))

	-- Initialize RNG for Boot Screen
	local _ = math.randomseed(os.time())

	_Debug = Debug()
	_EngineSettings = Settings("engine/settings.json")
	_DiscordRPC = DiscordRichPresence()
	
	-- Init boot screen
	_LoadBootScreen()
end

function love.update(dt)
	_Debug:profUpdateStart()

	_MousePos = _PosFromScreen(Vec2(love.mouse.getPosition()))
	if _Game then _Game:update(dt * _TimeScale) end

	_Debug:update(dt)
	_DiscordRPC:update(dt)

	-- rainbow effect for the shooter and console cursor blink; to be phased out soon
	_TotalTime = _TotalTime + dt

	_Debug:profUpdateStop()
end

function love.draw()
	--dbg:profDrawStart()

	-- Main
	if _Game then _Game:draw() end

	-- Tests
	_Debug:draw()

	--dbg:profDrawStop()
end

function love.mousepressed(x, y, button)
	if _Game then _Game:mousepressed(x, y, button) end
end

function love.mousereleased(x, y, button)
	if _Game then _Game:mousereleased(x, y, button) end
end

function love.keypressed(key)
	for k, v in pairs(_KeyModifiers) do if key == k then _KeyModifiers[k] = true end end
	-- Backspace is treated exclusively and will trigger repeatedly when held.
	love.keyboard.setKeyRepeat(key == "backspace")

	if not _Debug.console.active then
		if _Game then _Game:keypressed(key) end
	end

	_Debug:keypressed(key)
end

function love.keyreleased(key)
	for k, v in pairs(_KeyModifiers) do if key == k then _KeyModifiers[k] = false end end

	if not _Debug.console.active then
		if _Game then _Game:keyreleased(key) end
	end

	_Debug:keyreleased(key)
end

function love.textinput(t)
	if not _Debug.console.active then
		if _Game then _Game:textinput(t) end
	end

	_Debug:textinput(t)
end

function love.resize(w, h)
	_DisplaySize = Vec2(w, h)
end

function love.quit()
	print("[] User-caused Exit... []")
	if _Game and _Game.quit then _Game:quit(true) end
	_DiscordRPC:disconnect()
end



-- FUNCTION ZONE
function _LoadGame(gameName)
	_Game = Game(gameName)
	_Game:init()
end

function _LoadBootScreen()
	_Game = BootScreen()
	_Game:init()
end






function _GetDisplayOffsetX()
	return (_DisplaySize.x - _NATIVE_RESOLUTION.x * _GetResolutionScale()) / 2
end

function _GetResolutionScale()
	return _DisplaySize.y / _NATIVE_RESOLUTION.y
end

function _PosOnScreen(pos)
	return pos * _GetResolutionScale() + Vec2(_GetDisplayOffsetX(), 0)
end

function _PosFromScreen(pos)
	return (pos - Vec2(_GetDisplayOffsetX(), 0)) / _GetResolutionScale()
end



function _GetRainbowColor(t)
	t = t * 3
	local r = math.min(math.max(2 * (1 - math.abs(t % 3)), 0), 1) + math.min(math.max(2 * (1 - math.abs((t % 3) - 3)), 0), 1)
	local g = math.min(math.max(2 * (1 - math.abs((t % 3) - 1)), 0), 1)
	local b = math.min(math.max(2 * (1 - math.abs((t % 3) - 2)), 0), 1)
	return Color(r, g, b)
end





function _LoadFile(path)
	local file = io.open(path, "r")
	if not file then
		print("WARNING: File \"" .. path .. "\" does not exist. Expect errors!")
		return
	end
	io.input(file)
	local contents = io.read("*a")
	io.close(file)
	return contents
end

function _LoadJson(path)
	local contents = _LoadFile(path)
	assert(contents, string.format("Could not JSON-decode: %s, file does not exist", path))
	local data = json.decode(contents)
	assert(data, string.format("Could not JSON-decode: %s, error in file contents", path))
	return data
end

-- This function allows to load images from external sources.
-- This is an altered code from https://love2d.org/forums/viewtopic.php?t=85350#p221460
function _LoadImageData(path)
	local f = io.open(path, "rb")
	if f then
		local data = f:read("*all")
		f:close()
		if data then
			data = love.filesystem.newFileData(data, "tempname")
			data = love.image.newImageData(data)
			return data
		end
	end
end

function _LoadImage(path)
	local imageData = _LoadImageData(path)
	if not imageData then error("LOAD IMAGE FAIL: " .. path) end
	local image = love.graphics.newImage(imageData)
	return image
end

-- This function allows to load sounds from external sources.
-- This is an altered code from the above function.
function _LoadSound(path, type)
	local f = io.open(path, "rb")
	if f then
		local data = f:read("*all")
		f:close()
		if data then
			-- to make everything work properly, we need to get the extension from the path, because it is used
			-- source: https://love2d.org/wiki/love.filesystem.newFileData
			local t = _StrSplit(path, ".")
			local extension = t[#t]
			data = love.filesystem.newFileData(data, "tempname." .. extension)
			data = love.sound.newSoundData(data)
			local sound = love.audio.newSource(data, type)
			return sound
		end
	end
end

function _SaveFile(path, data)
	local file = io.open(path, "w")
	io.output(file)
	io.write(data)
	io.close(file)
end

function _SaveJson(path, data)
	print("Saving JSON data to " .. path .. "...")
	_SaveFile(path, _JsonBeautify(json.encode(data)))
end

function _GetDirListing(path, filter, extFilter, recursive, pathRec)
	-- Returns a list of directories and/or files in a given path.
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
		if love.filesystem.getInfo(p).type == "directory" then
			if filter == "all" then
				table.insert(result, pathRec .. item .. "/")
			elseif filter == "dir" then
				table.insert(result, pathRec .. item)
			end
			if recursive then
				for j, file in ipairs(_GetDirListing(path, filter, extFilter, true, pathRec .. item .. "/")) do
					table.insert(result, file)
				end
			end
		else
			if filter == "all" or filter == "file" and (not extFilter or item:sub(item:len() - extFilter:len(), item:len()) == extFilter) then
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



function _ParseString(data, variables)
	if not data then return nil end
	if type(data) == "string" then return data end
	local str = ""
	for i, compound in ipairs(data) do
		if type(compound) == "string" then
			str = str .. compound
		else
			if compound.type == "scoreFormat" then
				str = str .. _NumStr(_ParseNumber(compound.value, variables))
			elseif compound.type == "variable" then
				if not variables[compound.name] then
					-- print("FATAL: Invalid variable: " .. compound.name)
					-- print("Variables:")
					-- for k, v in pairs(variables) do print(k, v) end
					-- print("The game will crash now...")
				end
				str = str .. tostring(variables[compound.name])
			end
		end
	end
	return str
end

function _ParsePath(data, variables)
	if not data then return nil end
	return _FSPrefix .. "games/" .. _Game.name .. "/" .. _ParseString(data, variables)
end

function _ParseNumber(data, variables, properties)
	if not data then return nil end
	if type(data) == "number" then return data end
	if type(data) == "string" then return tonumber(data) end
	if data.type == "variable" then return variables[data.name] end
	if data.type == "property" then return properties[data.name] end
	if data.type == "randomSign" then
		local value = _ParseNumber(data.value, variables, properties)
		return math.random() < 0.5 and -value or value
	end
	if data.type == "randomInt" then
		local min = _ParseNumber(data.min, variables, properties)
		local max = _ParseNumber(data.max, variables, properties)
		return math.random(min, max)
	end
	if data.type == "randomFloat" then
		local min = _ParseNumber(data.min, variables, properties)
		local max = _ParseNumber(data.max, variables, properties)
		return min + math.random() * (max - min)
	end
	if data.type == "expr_graph" then
		local value = _ParseNumber(data.value, variables, properties)
		local points = {}
		for i, point in ipairs(data.points) do
			points[i] = _ParseVec2(point, variables, properties)
		end
		for i, point in ipairs(points) do
			if value < point.x then
				local prevPoint = points[i - 1]
				if prevPoint and point.x - prevPoint.x > 0 then
					local t = (point.x - value) / (point.x - prevPoint.x)
					return prevPoint.y * t + point.y * (1 - t)
				end
				return point.y
			end
		end
		return points[#points].y
	end
	if data.type == "fromString" then
		return tonumber(_ParseString(data.value, variables))
	end
end

function _ParseVec2(data, variables, properties)
	if not data then return nil end
	if data.type == "variable" then return variables[data.name] end
	return Vec2(_ParseNumber(data.x, variables, properties), _ParseNumber(data.y, variables, properties))
end

function _ParseColor(data, variables, properties)
	if not data then return nil end
	if data.type == "variable" then return variables[data.name] end
	return Color(_ParseNumber(data.r, variables, properties), _ParseNumber(data.g, variables, properties), _ParseNumber(data.b, variables, properties))
end

function _NumStr(n)
	local text = ""
	local s = tostring(n)
	local l = s:len()
	for i = 1, l do
		text = text .. s:sub(i, i)
		if l - i > 0 and (l - i) % 3 == 0 then text = text .. "," end
	end
	return text
end

-- One-dimensional cubic Beazier curve.
-- More info: http://www.demofox.org/bezcubic1d.html
-- The given expression can be simplified, because we are defining A = 0 and D = 1.
-- The shortened expression: y = B * 3x(1-x)^2 + C * 3x^2(1-x) + x^3
-- x is t, B is p1 and C is p2.
function _BzLerp(t, p1, p2)
	local b = p1 * (3 * t * math.pow(1 - t, 2))
	local c = p2 * (3 * math.pow(t, 2) * (1 - t))
	local d = math.pow(t, 3)
	return b + c + d
end
