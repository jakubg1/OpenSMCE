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
-- TODO: Including this library creates a thread which cannot be killed and makes restarting impossible.
-- Add some means to shut the thread down before uncommenting.
--love.audio.newAdvancedSource = require("com.asl")

-- This flag controls the experimental feature of ASL.
-- This changes the way music is handled in the levels (the music is sped up when in danger)
-- and changes all created music tracks to use advanced sources.
-- ASL brings features like time stretching, but at the cost of much higher resource usage.
--
-- At some point, the ASL library will be debugged and fixed as it is the only reasonable way to bring this feature
-- into the engine.
_DFLAG_ASL = false

-- toolbox lol
local t = love.timer.getTime()
print(string.format("update took %dus", (love.timer.getTime() - t) * 1000000))


-- INCLUDE ZONE

-- custom error handler
require("crash")

-- global utility methods
_Utils = require("com.utils")
_V = require("com.vectorutils")
_ConfigUtils = require("src.Configs.utils")

-- performance profiler
PROF_CAPTURE = true
_Profiler = require("com.jprof")

local json = require("com.json")

local Log = require("src.Log")
local Debug = require("src.Debug")
local Display = require("src.Display")
local Renderer = require("src.Renderer")
local ResourceManager = require("src.ResourceManager")

local Game = require("src.Game")
local EditorMain = require("src.BootScreen.EditorMain")
local BootScreen = require("src.BootScreen.BootScreen")
local TestMain = require("src.BootScreen.TestMain")

local ExpressionVariables = require("src.ExpressionVariables")
local Settings = require("src.Settings")

local DiscordRichPresence = require("src.DiscordRichPresence")
local Network = require("src.Network")
local ThreadManager = require("src.ThreadManager")

_VERSION = "v0.52.0"
_VERSION_NAME = "Beta 4.12.0-dev"
_DISCORD_APPLICATION_ID = "797956172539887657"
_START_TIME = love.timer.getTime()

-- Colors
_COLORS = {
	white = {1, 1, 1},
	red = {1, 0, 0},
	green = {0, 1, 0.2},
	orange = {1, 0.7, 0.2},
	blue = {0.2, 0.8, 1},
	lightRed = {1, 0.4, 0.2},
	purple = {1, 0.2, 1},
	yellow = {1, 1, 0.2},
	aqua = {0.3, 1, 1},
	darkAqua = {0.15, 0.5, 0.6},
	sky = {0.1, 0.4, 0.7},
	gray = {0.3, 0.3, 0.3},
	black = {0, 0, 0}
}

-- Fonts
_FONT = _Utils.loadFont("assets/dejavusans.ttf") or love.graphics.newFont()
_FONT_MED = _Utils.loadFont("assets/dejavusans.ttf", 14) or love.graphics.newFont(14)
_FONT_BIG = _Utils.loadFont("assets/dejavusans.ttf", 18) or love.graphics.newFont(18)
_FONT_GIANT = _Utils.loadFont("assets/dejavusans.ttf", 30) or love.graphics.newFont(30)
_FONT_CONSOLE = _Utils.loadFont("assets/unifont.ttf", 16) or love.graphics.newFont(14)

-- Set this to a string of your choice. This will be only printed in log files and is not used anywhere else.
-- You can automate this in i.e. a script by simply adding a `_BUILD_NUMBER = "<your number>"` line at the end of this main.lua file.
_BUILD_NUMBER = "unknown"

_MouseX, _MouseY = 0, 0
-- File system prefix. On Windows defaults to "", on Android defaults to "/sdcard/".
_FSPrefix = ""

---@type Game|BootScreen|EditorMain
_Game = nil
---@type Log
_Log = nil
---@type Debug
_Debug = nil
---@type Display
_Display = nil
---@type Renderer
_Renderer = nil
---@type ResourceManager
_Res = nil
---@type ExpressionVariables
_Vars = nil
---@type Network
_Network = nil
---@type ThreadManager
_ThreadManager = nil
---@type Settings
_Settings = nil
---@type DiscordRichPresence
_DiscordRPC = nil

_TotalTime = 0
_TimeScale = 1

function love.load(args)
	-- Initialize RNG for Boot Screen
	math.randomseed(os.time())

	-- Initialize some classes
	_Settings = Settings()
	_Settings:load()
	_Log = Log()
	_Debug = Debug()
	_Display = Display()
	_Renderer = Renderer()
	_Res = ResourceManager()
	_Vars = ExpressionVariables()
	_Network = Network()
	_ThreadManager = ThreadManager()
	_DiscordRPC = DiscordRichPresence()

	-- Print system limits.
	_Log:printt("main", "System info:")
	for k, v in pairs(love.graphics.getSystemLimits()) do
		_Log:printt("main", string.format("%s = %s", k, v))
	end

	-- Parse commandline arguments.
	local parsedArgs = _ParseCommandLineArguments(args)

	if parsedArgs.h or parsedArgs.help then
		print("OpenSMCE Command Line Arguments")
		print("===============================")
		print("-g / --game <game>    Immediately starts the provided game from directory.")
		print("-t / --test           Opens the test suite and performs unit tests.")
		love.event.quit()
	elseif parsedArgs.t or parsedArgs.test then
		-- If the `-t` argument is provided, load the test suite.
		_LoadTestSuite()
	else
		-- If the `-g` argument is provided, that game will be immediately loaded and Boot Screen will be skipped.
		-- Otherwise, if the `autoload.txt` exists in the main directory, read the game name from it and load that game.
		local autoload = parsedArgs.g or parsedArgs.game or love.restart or _Utils.loadFile("autoload.txt")
		if autoload then
			_LoadGame(autoload)
		else
			_LoadBootScreen()
		end
		_Profiler.connect()
	end
end

function love.update(dt)
	_Debug:profUpdateStart()

	_MouseX, _MouseY = _Display:posFromScreen(love.mouse.getPosition())
	if _Game then
		_Game:update(dt * _TimeScale)
	end

	_Debug:update(dt)
	_Res:update(dt)
	_DiscordRPC:update(dt)
	_ThreadManager:update(dt)
	_Vars:clearVariableProviderCache()

	-- rainbow effect for the shooter and console cursor blink; to be phased out soon
	_TotalTime = _TotalTime + dt

	-- Temporary HACK because Linux: Update window size every frame
	love.resize(love.window.getMode())

	_Debug:profUpdateStop()
	_Profiler.netFlush()
end

function love.draw()
	_Profiler.push("frame")

	-- Main
	if _Game then
		_Game:draw()
	end

	-- Tests
	_Debug:draw()

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
	-- Backspace is treated exclusively and will trigger repeatedly when held.
	love.keyboard.setKeyRepeat(key == "backspace")

	if not _Debug.console.active then
		if _Game then _Game:keypressed(key) end
	end

	_Debug:keypressed(key)
end

function love.keyreleased(key)
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
	_Display:resize(w, h)
end

---Executed when LOVE2D is about to quit.
---@return boolean? abort If `true`, the engine will keep running.
function love.quit()
	if not _Game then
		-- No game or boot screen or editor has started in the first place (for example when using `--help`). Stop immediately.
		return false
	end
	_Log:printt("main", "User-caused Exit...")
	local canGoBack = _Game and not _Game.isBootScreen
	if _Game and _Game.quit then
		_Game:quit(not _Settings:getSetting("backToBootWithX"))
	end
	-- Do not quit the engine if pressing X should return to the boot screen.
	if _Settings:getSetting("backToBootWithX") and canGoBack then
		return true
	end
	_DiscordRPC:disconnect()
	_Debug:disconnect()
	_Profiler.write("performance.jprof")
end



-- FUNCTION ZONE

---Parses command-line arguments and returns a table.
---The arguments are parsed as follows:
--- - `-param` or `--param` will set the corresponding `param` field to `true`.
--- - `-param value` or `--param value` will set the corresponding `param` field to `"value"`.
---@param args string[] The raw list of strings containing all parameters.
---@return table<string, string|boolean>
function _ParseCommandLineArguments(args)
	local parsedArgs = {}
	local currentArg = nil
	for i, arg in ipairs(args) do
		if _Utils.strStartsWith(arg, "--") then
			currentArg = arg:sub(3)
			parsedArgs[currentArg] = true
		elseif _Utils.strStartsWith(arg, "-") then
			currentArg = arg:sub(2)
			parsedArgs[currentArg] = true
		elseif currentArg then
			parsedArgs[currentArg] = arg
			currentArg = nil
		end
	end

	return parsedArgs
end

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

function _LoadTestSuite()
	_Game = TestMain()
	_Game:init()
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
	if not result then
		-- Failsafe for love.js, as `_GetNewestVersionThreaded()` seems to struggle with delivering any result (threads not supported?)
		return
	end
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
---@return string
function _ParsePathDots(data)
	assert(data, "Used _ParsePathDots with nil data - fix me!")
	return _FSPrefix .. "games." .. _Game.name .. "." .. data
end
