-- Remove all potentially malicious OS functions, to prevent any external scripts
-- from causing damage by, for example, loading a game with a os.execute("format c:") line
-- in its UI script.

-- TODO: Use proper sandboxing instead.

os = {
	time = os.time,
	date = os.date,
	clock = os.clock
}

-- Enable Advanced Sound Library.
love.audio.newAdvancedSource = require("com.asl")

-- toolbox lol
local t = love.timer.getTime()
print(string.format("update took %dus", (love.timer.getTime() - t) * 1000000))


-- INCLUDE ZONE

-- custom error handler
require("crash")

-- global utility methods
_Utils = require("com.utils")
_ConfigUtils = require("src.Configs.utils")

-- performance profiler
PROF_CAPTURE = true
_Profiler = require("com.jprof")

local json = require("com.json")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")

local Log = require("src.Log")
local Debug = require("src.Debug")

local Game = require("src.Game")
local EditorMain = require("src.BootScreen.EditorMain")
local BootScreen = require("src.BootScreen.BootScreen")

local ExpressionVariables = require("src.ExpressionVariables")
local Settings = require("src.Settings")

local DiscordRichPresence = require("src.DiscordRichPresence")
local Network = require("src.Network")
local ThreadManager = require("src.ThreadManager")



-- CONSTANT ZONE
_VERSION = "v0.48.0"
_VERSION_NAME = "Beta 4.9.0-dev"
_DISCORD_APPLICATION_ID = "797956172539887657"
_START_TIME = love.timer.getTime()

-- Colors
_COLORS = {
	red = {1, 0.2, 0.2},
	purple = {1, 0.2, 1},
	green = {0.2, 1, 0.2},
	aqua = {0.2, 1, 1},
	white = {1, 1, 1},
	yellow = {1, 1, 0.2}
}

-- Fonts
_FONT = _Utils.loadFont("assets/dejavusans.ttf")
_FONT_MED = _Utils.loadFont("assets/dejavusans.ttf", 14)
_FONT_BIG = _Utils.loadFont("assets/dejavusans.ttf", 18)
_FONT_GIANT = _Utils.loadFont("assets/dejavusans.ttf", 30)
_FONT_CONSOLE = _Utils.loadFont("assets/unifont.ttf", 16)

-- Set this to a string of your choice. This will be only printed in log files and is not used anywhere else.
-- You can automate this in i.e. a script by simply adding a `_BUILD_NUMBER = "<your number>"` line at the end of this main.lua file.
_BUILD_NUMBER = "unknown"





-- GLOBAL ZONE
_DisplaySize = Vec2(800, 600)
_DisplayFullscreen = false
_MousePos = Vec2(0, 0)
_KeyModifiers = {lshift = false, lctrl = false, lalt = false, rshift = false, rctrl = false, ralt = false}
-- File system prefix. On Windows defaults to "", on Android defaults to "/sdcard/".
_FSPrefix = ""

---@type Game|BootScreen|EditorMain
_Game = nil

---@type Log
_Log = nil

---@type Debug
_Debug = nil

_Vars = ExpressionVariables()
_Network = Network()
_ThreadManager = ThreadManager()



_TotalTime = 0
_TimeScale = 1

---@type Settings
_EngineSettings = nil

---@type DiscordRichPresence
_DiscordRPC = nil








-- CALLBACK ZONE

function love.load(args)
	-- Initialize RNG for Boot Screen
	local _ = math.randomseed(os.time())

	-- Initialize some classes
	_Log = Log()
	_Debug = Debug()
	_EngineSettings = Settings("settings.json")
	_DiscordRPC = DiscordRichPresence()

	-- Parse commandline arguments.
	local parsedArgs = {}
	local currentArg = nil
	for i, arg in ipairs(args) do
		if _Utils.strStartsWith(arg, "-") then
			currentArg = arg:sub(2)
			parsedArgs[currentArg] = true
		elseif currentArg then
			parsedArgs[currentArg] = arg
			currentArg = nil
		end
	end
	
    -- If autoload.txt exists, load the game name from there
    local autoload = _Utils.loadFile("autoload.txt") or nil
	-- Overwrite autoload if a -g command is used.
	if parsedArgs.g then
		autoload = parsedArgs.g
	end
	if autoload then
        _LoadGame(autoload)
    else
		_LoadBootScreen()
	end
	--for k, v in pairs(love.graphics.getSystemLimits()) do print(k, v) end
	_Profiler.connect()
end

function love.update(dt)
	_Debug:profUpdateStart()

	_MousePos = _PosFromScreen(Vec2(love.mouse.getPosition()))
	if _Game then
		_Game:update(dt * _TimeScale)
	end

	_Log:update(dt)
	_Debug:update(dt)
	_DiscordRPC:update(dt)
	_ThreadManager:update(dt)

	-- rainbow effect for the shooter and console cursor blink; to be phased out soon
	_TotalTime = _TotalTime + dt

	_Debug:profUpdateStop()
	_Profiler.netFlush()
end

function love.draw()
	_Profiler.push("frame")
	--dbg:profDrawStart()

	-- Main
	if _Game then
		_Game:draw()
	end

	-- Tests
	_Debug:draw()

	--dbg:profDrawStop()
	_Profiler.pop("frame")
end

function love.mousepressed(x, y, button)
	if _Game then _Game:mousepressed(x, y, button) end
	_Debug:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
	if _Game then _Game:mousereleased(x, y, button) end
	_Debug:mousereleased(x, y, button)
end

function love.wheelmoved(x, y)
	if _Game then _Game:wheelmoved(x, y) end
	_Debug:wheelmoved(x, y)
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
	_Log:printt("main", "User-caused Exit...")
	if _Game and _Game.quit then _Game:quit(true) end
	_DiscordRPC:disconnect()
	_Log:save(true)
	_Profiler.write("performance.jprof")
end



-- FUNCTION ZONE
function _LoadGame(gameName)
	_Game = Game(gameName)
	_Game:init()
end

function _LoadGameEditor(gameName)
	_Game = EditorMain(gameName)
	_Game:init()
end

function _LoadBootScreen()
	_Game = BootScreen()
	_Game:init()
end






---Sets the window settings: resolution, whether it can be changed, and its title.
---@param resolution Vector2 The new window resolution.
---@param resizable boolean Whether the window can be resized.
---@param title string The window title.
---@param maximized boolean? If set, the window will be maximized.
function _SetResolution(resolution, resizable, title, maximized)
	love.window.setMode(resolution.x, resolution.y, {resizable = resizable})
	if maximized then
		love.window.maximize()
	end
	love.window.setTitle(title)
	_DisplaySize = resolution
end

---Returns the X offset of actual screen contents.
---The game is scaled so the vertical axis is always fully covered. This means that on the X axis, the contents need to be positioned
---in such a way that the contents are exactly in the center.
---@param force boolean? Whether the returned value should be scaled with the window even if the canvas rendering is enabled.
---@return number
function _GetDisplayOffsetX(force)
	return (_DisplaySize.x - _Game:getNativeResolution().x * _GetResolutionScale(force)) / 2
end

---Returns the scale of screen contents, depending on the current window size.
---@param force boolean? Whether the returned value should be scaled with the window even if the canvas rendering is enabled.
---@return number
function _GetResolutionScale(force)
	if _Game.renderCanvas and not force then
		-- If all stuff is rendered on a canvas, the canvas itself will be scaled.
		return 1
	else
		return _DisplaySize.y / _Game:getNativeResolution().y
	end
end

---Returns the onscreen (or on-canvas if canvas rendering is enabled) position of the given logical point.
---@param pos Vector2 The logical point of which the onscreen position will be returned.
---@return Vector2
function _PosOnScreen(pos)
	if _Game.renderCanvas then
		-- If all stuff is rendered on a canvas, the canvas itself will be scaled and positioned.
		return pos
	else
		return pos * _GetResolutionScale() + Vec2(_GetDisplayOffsetX(), 0)
	end
end

---Returns the logical position of the given onscreen point.
---@param pos Vector2 The onscreen point of which the logical position will be returned.
---@return Vector2
function _PosFromScreen(pos)
	return (pos - Vec2(_GetDisplayOffsetX(true), 0)) / _GetResolutionScale(true)
end



---Returns precise time amount since this program has been launched.
---The output is more precise than the `_TotalTime` field.
---@return number
function _GetPreciseTime()
	return love.timer.getTime() - _START_TIME
end



---Used internally as a common part of `_GetNewestVersion` and `_GetNewestVersionThreaded`.
---Don't call this function directly. Instead, use one of the aforementioned functions.
---@see _GetNewestVersion
---@see _GetNewestVersionThreaded
---@param result table HTTPS request result.
---@return string?
function _ParseNewestVersion(result)
	if result.code == 200 and result.body then
		-- Trim everything before the first square bracket.
		while result.body:sub(1, 1) ~= "[" do
			result.body = result.body:sub(2)
		end
		-- And everything after the last square bracket.
		while result.body:sub(-1) ~= "]" do
			result.body = result.body:sub(1, -2)
		end
		result.body = json.decode(result.body)
		return result.body[1].name
	end
	return nil
end



---Checks online and returns the newest engine version tag available (i.e. `v0.47.0`). Returns `nil` on failure (for example, when you go offline).
---@return string?
function _GetNewestVersion()
	local result = _Network:get("https://api.github.com/repos/jakubg1/OpenSMCE/tags")
	return _ParseNewestVersion(result)
end



---Checks online and executes a function with the newest engine version tag available (i.e. `v0.47.0`) as an argument or `nil` on failure (for example, when you go offline).
---Threaded version: non-blocking call.
---@param onFinish function A function which will be called once the checking process is finished. A version argument is passed.
---@param caller any? An optional instance of any class on which the function will be executed. Useful if you don't want to create anonymous functions.
function _GetNewestVersionThreaded(onFinish, caller)
	_Network:getThreaded("https://api.github.com/repos/jakubg1/OpenSMCE/tags", false, function(result)
		if caller then
			onFinish(caller, _ParseNewestVersion(result))
		else
			onFinish(_ParseNewestVersion(result))
		end
	end)
end



---Returns a path relative to the executable, based on currently loaded game's name.
---Rough implementation, but it works for now.
---@param data string The path to be resolved.
---@return string
function _ParsePath(data)
	assert(data, "Used _ParsePath with nil data - fix me!")
	return _FSPrefix .. "games/" .. _Game.name .. "/" .. data
end

---Returns a path relative to the executable, based on currently loaded game's name.
---This is a variant which puts dots instead of slashes for the purposes of script loading.
---@param data string The path to be resolved. Note that any slashes will NOT be converted.
---@return string?
function _ParsePathDots(data)
	if not data then
		return nil
	end
	return _FSPrefix .. "games." .. _Game.name .. "." .. data
end



---Legacy number parsing function, used only by Particles.
---A number of different types can be provided:
--- - Passing `nil` will return `nil`.
--- - Passing a number will return that number.
--- - Passing a string will return its numeric value.
--- - Passing a table will check its `type` field:
---   - `"randomSign"` will return the `value` field with its sign flipped half of the time.
---   - `"randomInt"` will return a random integer from `min` to `max`.
---   - `"randomFloat"` will return a random number from `min` to `max`.
---   - `"expr_graph"` will load a list from the `points` field (each entry is an object with `x` and `y` fields) and will find the Y value for the given X.
---
---Please use Expressions instead.
---@param data number|string|table? Data to be processed.
---@return number?
function _ParseNumber(data)
	if not data then
		return nil
	end
	if type(data) == "number" then
		return data
	end
	if type(data) == "string" then
		return tonumber(data)
	end
	if data.type == "randomSign" then
		local value = _ParseNumber(data.value)
		return math.random() < 0.5 and -value or value
	end
	if data.type == "randomInt" then
		local min = _ParseNumber(data.min)
		local max = _ParseNumber(data.max)
		return math.random(min, max)
	end
	if data.type == "randomFloat" then
		local min = _ParseNumber(data.min)
		local max = _ParseNumber(data.max)
		return min + math.random() * (max - min)
	end
	if data.type == "expr_graph" then
		local value = _ParseNumber(data.value)
		local points = {}
		for i, point in ipairs(data.points) do
			points[i] = _ParseVec2(point)
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
end



---Turns a `{x = X, y = Y}` table into a Vector2.
---If `nil` is provided, `nil` will be returned.
---@param data table? The table to be converted.
---@return Vector2?
function _ParseVec2(data)
	if not data then
		return nil
	end
	return Vec2(_ParseNumber(data.x), _ParseNumber(data.y))
end



---Turns a `{r = R, g = G, b = B}` table into a Color.
---If `nil` is provided, `nil` will be returned.
---@param data table? The table to be converted.
---@return Color?
function _ParseColor(data)
	if not data then
		return nil
	end
	return Color(_ParseNumber(data.r), _ParseNumber(data.g), _ParseNumber(data.b))
end
