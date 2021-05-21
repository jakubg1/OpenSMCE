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
VERSION = "v0.40.0"
VERSION_NAME = "Beta 4.0.0-DEV"
DISCORD_APPLICATION_ID = "797956172539887657"


-- TODO: at some point, get rid of this and make it configurable
NATIVE_RESOLUTION = Vec2(800, 600)





-- GLOBAL ZONE
displaySize = Vec2(800, 600)
displayFullscreen = false
mousePos = Vec2(0, 0)
keyModifiers = {lshift = false, lctrl = false, lalt = false, rshift = false, rctrl = false, ralt = false}

game = nil
dbg = nil

variableSet = {}

totalTime = 0
timeScale = 1








-- CALLBACK ZONE
function love.load()
	--local s = loadFile("test.txt")
	--print(s)
	--print(jsonBeautify(s))
	dbg = Debug()
	engineSettings = Settings("engine/settings.json")
	discordRPC = DiscordRichPresence()
	-- Init boot screen
	loadBootScreen()
end

function love.update(dt)
	dbg:profUpdateStart()

	mousePos = posFromScreen(Vec2(love.mouse.getPosition()))
	if game then game:update(dt * timeScale) end

	dbg:update(dt)
	discordRPC:update(dt)

	-- rainbow effect for the shooter and console cursor blink; to be phased out soon
	totalTime = totalTime + dt

	dbg:profUpdateStop()
end

function love.draw()
	--dbg:profDrawStart()

	-- Main
	if game then game:draw() end

	-- Tests
	dbg:draw()

	--dbg:profDrawStop()
end

function love.mousepressed(x, y, button)
	if game then game:mousepressed(x, y, button) end
end

function love.mousereleased(x, y, button)
	if game then game:mousereleased(x, y, button) end
end

function love.keypressed(key)
	for k, v in pairs(keyModifiers) do if key == k then keyModifiers[k] = true end end

	if not dbg.console.active then
		if game then game:keypressed(key) end
	end

	dbg:keypressed(key)
end

function love.keyreleased(key)
	for k, v in pairs(keyModifiers) do if key == k then keyModifiers[k] = false end end

	if not dbg.console.active then
		if game then game:keyreleased(key) end
	end

	dbg:keyreleased(key)
end

function love.textinput(t)
	dbg:textinput(t)
end

function love.resize(w, h)
	displaySize = Vec2(w, h)
end

function love.quit()
	print("[] User-caused Exit... []")
	discordRPC:disconnect()
end



-- FUNCTION ZONE
function loadGame(gameName)
	game = Game(gameName)
	game:init()
end

function loadBootScreen()
	game = BootScreen()
	game:init()
end






function getDisplayOffsetX()
	return (displaySize.x - NATIVE_RESOLUTION.x * getResolutionScale()) / 2
end

function getResolutionScale()
	return displaySize.y / NATIVE_RESOLUTION.y
end

function posOnScreen(pos)
	return pos * getResolutionScale() + Vec2(getDisplayOffsetX(), 0)
end

function posFromScreen(pos)
	return (pos - Vec2(getDisplayOffsetX(), 0)) / getResolutionScale()
end



function getRainbowColor(t)
	t = t * 3
	local r = math.min(math.max(2 * (1 - math.abs(t % 3)), 0), 1) + math.min(math.max(2 * (1 - math.abs((t % 3) - 3)), 0), 1)
	local g = math.min(math.max(2 * (1 - math.abs((t % 3) - 1)), 0), 1)
	local b = math.min(math.max(2 * (1 - math.abs((t % 3) - 2)), 0), 1)
	return Color(r, g, b)
end





function loadFile(path)
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

function loadJson(path)
	return json.decode(loadFile(path))
end

-- This function allows to load images from external sources.
-- This is an altered code from https://love2d.org/forums/viewtopic.php?t=85350#p221460
function loadImageData(path)
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

function loadImage(path)
	local imageData = loadImageData(path)
	if not imageData then error("LOAD IMAGE FAIL: " .. path) end
	local image = love.graphics.newImage(imageData)
	return image
end

-- This function allows to load sounds from external sources.
-- This is an altered code from the above function.
function loadSound(path, type)
	local f = io.open(path, "rb")
	if f then
		local data = f:read("*all")
		f:close()
		if data then
			-- to make everything work properly, we need to get the extension from the path, because it is used
			-- source: https://love2d.org/wiki/love.filesystem.newFileData
			local t = strSplit(path, ".")
			local extension = t[#t]
			data = love.filesystem.newFileData(data, "tempname." .. extension)
			data = love.sound.newSoundData(data)
			local sound = love.audio.newSource(data, type)
			return sound
		end
	end
end

function saveFile(path, data)
	local file = io.open(path, "w")
	io.output(file)
	io.write(data)
	io.close(file)
end

function saveJson(path, data)
	print("Saving JSON data to " .. path .. "...")
	saveFile(path, jsonBeautify(json.encode(data)))
end

function parseString(data, variables)
	if not data then return nil end
	if type(data) == "string" then return data end
	str = ""
	for i, compound in ipairs(data) do
		if type(compound) == "string" then
			str = str .. compound
		else
			if compound.type == "scoreFormat" then
				str = str .. numStr(parseNumber(compound.value, variables))
			elseif compound.type == "variable" then
				if not variables[compound.name] then
					-- print("FATAL: Invalid variable: " .. compound.name)
					-- print("Variables:")
					-- for k, v in pairs(variables) do print(k, v) end
					-- print("The game will crash now...")
				end
				str = str .. tostring(variables[compound.name])
			elseif compound.type == "highscoreData" then
				local place = parseNumber(compound.place, variables)
				str = str .. tostring(game.runtimeManager.highscores:getEntry(place)[compound.name])
			end
		end
	end
	return str
end

function parsePath(data, variables)
	if not data then return nil end
	return "games/" .. game.name .. "/" .. parseString(data, variables)
end

function parseNumber(data, variables, properties)
	if not data then return nil end
	if type(data) == "number" then return data end
	if type(data) == "string" then return tonumber(data) end
	if data.type == "variable" then return variables[data.name] end
	if data.type == "property" then return properties[data.name] end
	if data.type == "randomSign" then
		local value = parseNumber(data.value, variables, properties)
		return math.random() < 0.5 and -value or value
	end
	if data.type == "randomInt" then
		local min = parseNumber(data.min, variables, properties)
		local max = parseNumber(data.max, variables, properties)
		return math.random(min, max)
	end
	if data.type == "randomFloat" then
		local min = parseNumber(data.min, variables, properties)
		local max = parseNumber(data.max, variables, properties)
		return min + math.random() * (max - min)
	end
	if data.type == "expr_graph" then
		local value = parseNumber(data.value, variables, properties)
		local points = {}
		for i, point in ipairs(data.points) do
			points[i] = parseVec2(point, variables, properties)
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
		return tonumber(parseString(data.value, variables))
	end
end

function parseVec2(data, variables, properties)
	if not data then return nil end
	if data.type == "variable" then return variables[data.name] end
	return Vec2(parseNumber(data.x, variables, properties), parseNumber(data.y, variables, properties))
end

function parseColor(data, variables, properties)
	if not data then return nil end
	if data.type == "variable" then return variables[data.name] end
	return Color(parseNumber(data.r, variables, properties), parseNumber(data.g, variables, properties), parseNumber(data.b, variables, properties))
end

function numStr(n)
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
function bzLerp(t, p1, p2)
	local b = p1 * (3 * t * math.pow(1 - t, 2))
	local c = p2 * (math.pow(3 * t, 2) * (1 - t))
	local d = math.pow(x, 3)
	return b + c + d
end
