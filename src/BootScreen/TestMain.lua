local class = require "com.class"

---@class TestMain
---@overload fun():TestMain
local TestMain = class:derive("TestMain")

local Vec2 = require("src.Essentials.Vector2")

---Constructs a new instance of Test Suite.
---This is the class which manages Tests, runs them and displays the results.
function TestMain:new()
	self.nativeResolution = Vec2(800, 600)

	self.TEST_LOCATION = "src/Tests"
	self.modules = {}
end

---Initializes the editor and all of its components.
function TestMain:init()
	_Log:printt("TestMain", "Testing mode")

	-- Step 1. Initialize the window
	_Display:setResolution(self:getNativeResolution(), false, "OpenSMCE [" .. _VERSION .. "] - Test Suite")

	-- Step 2. Get all test files
	self.modules = self:getModules()

	-- Step 3. Test all modules
	self:testAllModules()
end

---Enumerates and loads all test modules from the `src/Tests` directory into a table.
---The returned table is a list of modules, each of them having the `name` and `functions` properties.
---Each item in the `functions` property is a table with `f`, `result`, `message` and `traceback` fields.
---@return [{name: string, functions: table}]
function TestMain:getModules()
	local modules = {}
	local names = _Utils.getDirListing(self.TEST_LOCATION, "file", ".lua")
	for i, name in ipairs(names) do
		local fns = require(self.TEST_LOCATION .. "/" .. _Utils.pathStripExtension(name))
		local functions = {}
		for fName, fn in pairs(fns) do
			functions[fName] = {f = fn, result = nil, message = nil, traceback = nil}
		end
		modules[i] = {name = name, functions = functions}
	end
	return modules
end

---Tests all modules.
function TestMain:testAllModules()
	for i, mod in ipairs(self.modules) do
		for name, testcase in pairs(mod.functions) do
			self:testCase(testcase, name)
		end
	end
end

---Tests the provided testcase and updates its `result`, `message` and `traceback` fields accordingly.
---@param testcase table The testcase to be tested.
---@param name string The name of the testcase.
function TestMain:testCase(testcase, name)
	local success, result = xpcall(testcase.f, debug.traceback)
	if success then
		if result ~= false then
			-- `nil` is considered a success.
			testcase.result = true
		else
			testcase.result = false
			testcase.message = "Unsatisfying result!"
		end
	else
		if result then
			_Log:printt("TEST SUITE", ("Testcase \"%s\" failed! Traceback:"):format(name))
			_Log:printt("TEST SUITE", result)
			testcase.result = false
			testcase.message = _Utils.strSplit(result, "\n")[1]
			testcase.traceback = result
		else
			_Log:printt("TEST SUITE", ("Testcase \"%s\" failed with no traceback :("):format(name))
			testcase.result = false
			testcase.message = "No traceback! Something went horribly wrong..."
			testcase.traceback = nil
		end
	end
end

---Updates the Test Suite's onscreen components.
---@param dt number Time delta, in seconds.
function TestMain:update(dt)
end

---Draws the Test Suite's interface on the screen.
function TestMain:draw()
	-- White color
	love.graphics.setColor(1, 1, 1)

	-- HEADER
	love.graphics.setFont(_FONT_BIG)
	love.graphics.print("Test Suite", 10, 4)

	local y = 40
	for i, mod in ipairs(self.modules) do
		-- Test file header
		love.graphics.setFont(_FONT_BIG)
		love.graphics.print(mod.name, 15, y)
		y = y + 25
		for fName, item in pairs(mod.functions) do
			-- Test result entry
			love.graphics.setFont(_FONT)
			love.graphics.print(fName .. "()", 30, y)
			if item.result == true then
				love.graphics.setColor(0.1, 0.9, 0.2)
				love.graphics.print("PASSED", 200, y)
			elseif item.result == false then
				love.graphics.setColor(1, 0.2, 0.2)
				love.graphics.print("FAILED", 200, y)
			else
				love.graphics.setColor(0.4, 0.4, 0.4)
				love.graphics.print("UNTESTED", 200, y)
			end
			love.graphics.setColor(1, 1, 1)
			if item.message then
				love.graphics.print(item.message, 260, y)
			end
			y = y + 15
		end
	end
end

---Returns the native resolution of the Test Suite.
---@return Vector2
function TestMain:getNativeResolution()
	return self.nativeResolution
end

---Returns the effective sound volume. In the editor, it's always 1.
---@return number
function TestMain:getEffectiveSoundVolume()
	return 1
end

---Returns the effective music volume. In the editor, it's always 1.
---@return number
function TestMain:getEffectiveMusicVolume()
	return 1
end

function TestMain:mousepressed(x, y, button)
	-- STUB
end

function TestMain:mousereleased(x, y, button)
	-- STUB
end

function TestMain:wheelmoved(x, y)
	-- STUB
end

function TestMain:keypressed(key)
	-- STUB
end

function TestMain:keyreleased(key)
	-- STUB
end

function TestMain:textinput(t)
	-- STUB
end

return TestMain
