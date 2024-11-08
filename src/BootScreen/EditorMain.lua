local class = require "com.class"

---@class EditorMain
---@overload fun(bootScreen):EditorMain
local EditorMain = class:derive("EditorMain")

local Vec2 = require("src.Essentials.Vector2")
local Button = require("src.BootScreen.UI.Button")

local ConfigManager = require("src.ConfigManager")
local ResourceManager = require("src.ResourceManager")



---Constructs a new instance of Game Editor.
---@param name string The name of the game, equivalent to the folder name in `games` directory.
function EditorMain:new(name)
	self.name = name

	self.nativeResolution = Vec2(1280, 720)

	self.configManager = nil
	self.resourceManager = nil

	-- buttons
	self.menuBtn = Button("Quit", _FONT_BIG, Vec2(1170, 4), Vec2(100, 24), function() _LoadBootScreen() end)

	-- other UI stuff
	self.resourceListOffset = 0
end



---Initializes the editor and all of its components.
function EditorMain:init()
	_Log:printt("EditorMain", "Editing game: " .. self.name)

	-- Step 1. Load the config
	self.configManager = ConfigManager()
	self.configManager:loadStuffBeforeResources()

	-- Step 2. Initialize the window
	_SetResolution(self:getNativeResolution(), false, "OpenSMCE [" .. _VERSION .. "] - Game Editor - " .. self.name)

	-- Step 3. Create a resource bank
	self.resourceManager = ResourceManager()
	self.resourceManager:startLoadCounter("main")
	self.resourceManager:scanResources()
	self.resourceManager:stopLoadCounter("main")
end



function EditorMain:update(dt)
	self.resourceManager:update(dt)
	-- buttons
	self.menuBtn:update(dt)
end



function EditorMain:draw()
	-- White color
	love.graphics.setColor(1, 1, 1)

	-----------------------------
	-- HEADER
	-----------------------------
	love.graphics.setFont(_FONT_BIG)
	love.graphics.print("Game Editor", 10, 4)
	love.graphics.setFont(_FONT)
	love.graphics.print(string.format("Editing: games/%s/", self.name), 10, 24)

	-----------------------------
	-- LEFT BAR
	-----------------------------
	if self.resourceManager:getLoadProgress("main") < 1 then
		love.graphics.print("Loading...", 15, 35)
	end
	local spriteList = self.resourceManager:getAssetList("sprite")
	for i, key in ipairs(spriteList) do
		love.graphics.print(key, 20, 50 + (i - 1) * 15 - self.resourceListOffset)
	end

	-----------------------------
	-- SETTING LIST
	-----------------------------
	self.menuBtn:draw()
end



---Returns the native resolution of the Game Editor, which is always 800 by 600.
---@return Vector2
function EditorMain:getNativeResolution()
	return self.nativeResolution
end



---Returns the effective sound volume. In the editor, it's always 1.
---@return number
function EditorMain:getEffectiveSoundVolume()
	return 1
end



---Returns the effective music volume. In the editor, it's always 1.
---@return number
function EditorMain:getEffectiveMusicVolume()
	return 1
end



function EditorMain:mousepressed(x, y, button)
	-- STUB
end

function EditorMain:mousereleased(x, y, button)
	-- Buttons
	self.menuBtn:mousereleased(x, y, button)
end

function EditorMain:wheelmoved(x, y)
	self.resourceListOffset = self.resourceListOffset - y * 30
end

function EditorMain:keypressed(key)
	-- STUB
end

function EditorMain:keyreleased(key)
	-- STUB
end

function EditorMain:textinput(t)
	-- STUB
end



return EditorMain
