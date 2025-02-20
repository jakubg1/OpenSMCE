local class = require "com.class"

---Main class for a Game. Handles everything the Game has to do.
---@class Game
---@overload fun(name):Game
local Game = class:derive("Game")



local Vec2 = require("src.Essentials.Vector2")

local Timer = require("src.Timer")

local ConfigManager = require("src.ConfigManager")
local ResourceManager = require("src.ResourceManager")
local RuntimeManager = require("src.Game.RuntimeManager")
local Level = require("src.Game.Level")

local UIManager = require("src.UI.Manager")
local ParticleManager = require("src.Particle.Manager")



---Constructs a new instance of Game.
---@param name string The name of the game, equivalent to the folder name in `games` directory.
function Game:new(name)
	self.name = name

	self.hasFocus = false

	self.configManager = nil
	self.resourceManager = nil
	self.runtimeManager = nil
	self.level = nil

	self.uiManager = nil
	self.particleManager = nil


	-- revert to original font size
	love.graphics.setFont(_FONT)
end



---Initializes the game and all its components.
function Game:init()
	_Log:printt("Game", "Selected game: " .. self.name)

	-- Step 1. Load the config
	self.configManager = ConfigManager()

	-- Step 2. Initialize the window and canvas if necessary
	local res = self:getNativeResolution()
	_SetResolution(res, true, self.configManager:getWindowTitle(), true)
	if self.configManager:isCanvasRenderingEnabled() then
		self.renderCanvas = love.graphics.newCanvas(res.x, res.y)
		if self.configManager:getCanvasRenderingMode() == "pixel" then
			self.renderCanvas:setFilter("nearest", "nearest")
		end
	end

	-- Step 3. Initialize RNG and timer
	self.timer = Timer()
	local _ = math.randomseed(os.time())

	-- Step 4. Create a resource bank
	self.resourceManager = ResourceManager()

	-- Step 5. Create a runtime manager
	self.runtimeManager = RuntimeManager()

	-- Step 6. Set up the UI Manager
	self.uiManager = UIManager()
	self.uiManager:initSplash()
end



---Loads all game resources.
function Game:loadMain()
	self.resourceManager:startLoadCounter("main")
	self.resourceManager:scanResources()
	self.resourceManager:stopLoadCounter("main")
end



---Initializes the game session, as well as UI and particle managers.
function Game:initSession()
	-- Setup the UI and particles.
	self.uiManager:init()
	self.particleManager = ParticleManager()

	_Game.uiManager:executeCallback("sessionInit")
end



---Updates the game.
---@param dt number Delta time in seconds.
function Game:update(dt) -- callback from main.lua
	self.timer:update(dt)
	for i = 1, self.timer:getFrameCount() do
		self:tick(self.timer.FRAME_LENGTH)
	end
end



---Updates the game logic. Contrary to `:update()`, this function will always have its delta time given as a multiple of 1/60.
---@param dt number Delta time in seconds.
function Game:tick(dt) -- always with 1/60 seconds
	self.resourceManager:update(dt)

	if self.level then
		self.level:update(dt)
	end

	if self:getCurrentProfile() then
		self:getCurrentProfile():dumpVariables()
	end

	self.uiManager:update(dt)

	if self.particleManager then
		self.particleManager:update(dt)
	end

	if self.configManager.config.richPresence.enabled then
		self:updateRichPresence()
	end
end



---Starts a new Level from the current Profile, or loads one in progress if it has one.
---This also executes an appropriate entry in the UI script if the current level set's entry is a UI Script one. Yep, it's a mess.
---This function is intended to be called ONLY from UI scripts, using the UI Manager as a proxy.
function Game:startLevel()
	local profile = self:getCurrentProfile()
	if profile:getLevelEntry().type == "uiScript" then
		_Game.uiManager:executeCallback(profile:getLevelEntry().callback)
	else
		self.level = Level(profile:getLevelData())
		local savedLevelData = profile:getSavedLevel()
	if savedLevelData then
		self.level:deserialize(savedLevelData)
		self.uiManager:executeCallback("levelLoaded")
	else
		self.uiManager:executeCallback("levelStart")
		end
	end
end

---Destroys the level along with its save data.
---This function is intended to be called ONLY from UI scripts, using the UI Manager as a proxy.
function Game:endLevel()
	self.level:unsave()
	self.level:destroy()
	self.level = nil
end

---Destroys the level and marks it as won.
---This function is intended to be called ONLY from UI scripts, using the UI Manager as a proxy.
function Game:winLevel()
	self.level:win()
	self:endLevel()
end

---Destroys the level and saves it for the future.
---This function is intended to be called ONLY from UI scripts, using the UI Manager as a proxy.
function Game:saveLevel()
	self.level:save()
	self.level:destroy()
	self.level = nil
end

---Destroys the level and triggers a `gameOver` callback in the UI script.
---This function is intended to be called ONLY from UI scripts, using the UI Manager as a proxy.
function Game:gameOver()
	self:endLevel()
	self.uiManager:executeCallback("gameOver")
end



---Updates the game's Rich Presence information.
function Game:updateRichPresence()
	local profile = self:getCurrentProfile()
	local line1 = "Playing: " .. self.configManager:getGameName()
	local line2 = ""

	if self.level then
				line2 = string.format("Level %s (%s), Score: %s, Lives: %s",
			profile:getLevelName(),
			self.level.won and "Complete!" or string.format("%s%%", math.floor((self.level:getObjectiveProgress(1)) * 100)),
			profile:getScore(),
			profile:getLives()
		)
		if self.level.pause then
			line1 = line1 .. " - Paused"
		end
	elseif profile and profile:getSession() then
		line2 = string.format("In menus, Score: %s, Lives: %s", profile:getScore(), profile:getLives())
	else
		line2 = string.format("In menus")
	end

	_DiscordRPC:setStatus(line1, line2)
end



---Draws the game contents.
function Game:draw()
	_Debug:profDraw2Start()

	-- Start drawing on canvas (if canvas mode set)
	if self.renderCanvas then
		love.graphics.setCanvas({self.renderCanvas, stencil = true})
		love.graphics.clear()
	end

	-- Level
	if self.level then
		self.level:draw()
	end
	_Debug:profDraw2Checkpoint()

	-- Particles and UI
	if self.particleManager then
		self.particleManager:draw()
	end
	self.uiManager:draw()
	_Debug:profDraw2Checkpoint()

	-- Finish drawing on canvas (if canvas mode set)
	if self.renderCanvas then
		love.graphics.setCanvas()
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(self.renderCanvas, _GetDisplayOffsetX(true), 0, 0, _GetResolutionScale(true))
	end

	-- Borders
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", 0, 0, _GetDisplayOffsetX(true), _DisplaySize.y)
	love.graphics.rectangle("fill", _DisplaySize.x - _GetDisplayOffsetX(true), 0, _GetDisplayOffsetX(true), _DisplaySize.y)

	love.graphics.setColor(1, 1, 1)
	--self.resourceManager:getSprite("sprites/game/ball_1.json").img:draw(0, 0)
	_Debug:profDraw2Stop()
end



---Callback from `main.lua`.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button which was pressed.
function Game:mousepressed(x, y, button)
	if self.uiManager:isButtonHovered() then
		self.uiManager:mousepressed(x, y, button)
	elseif self.level then
		self.level:mousepressed(x, y, button)
	end
end



---Callback from `main.lua`.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button which was released.
function Game:mousereleased(x, y, button)
	self.uiManager:mousereleased(x, y, button)
end



---Callback from `main.lua`.
---@param x integer The X delta of the scroll.
---@param y integer The Y delta of the scroll.
function Game:wheelmoved(x, y)
	-- STUB
end



---Callback from `main.lua`.
---@param key string The pressed key code.
function Game:keypressed(key)
	self.uiManager:keypressed(key)
	if self.level then
		self.level:keypressed(key)
	end
end



---Callback from `main.lua`.
---@param key string The released key code.
function Game:keyreleased(key)
	if self.level then
		self.level:keyreleased(key)
	end
end



---Callback from `main.lua`.
---@param t string Something which makes text going.
function Game:textinput(t)
	self.uiManager:textinput(t)
end



---Saves the game.
function Game:save()
	if self.level then
		self.level:save()
	end
	self.runtimeManager:save()
end



---Plays a sound and returns its instance for modification.
---@param name string|SoundEvent The name of the Sound Effect to be played.
---@param pos Vector2? The position of the sound.
---@return SoundInstanceList
function Game:playSound(name, pos)
	-- TODO: Unmangle this code. Will the string representation be still necessary after we fully move to Config Classes?
	if type(name) == "string" then
		return self.resourceManager:getSoundEvent(name):play(pos)
	else
		return name:play(pos)
	end
end



---Returns the currently selected Profile.
---@return Profile
function Game:getCurrentProfile()
	return self.runtimeManager.profileManager:getCurrentProfile()
end



---Spawns and returns a particle packet.
---@param name string The name of a particle packet.
---@param pos Vector2 The position for the particle packet to be spawned.
---@param layer string? The layer the particles are supposed to be drawn on. If `nil`, they will be drawn as a part of the game, and not UI.
---@return ParticlePacket
function Game:spawnParticle(name, pos, layer)
	return self.particleManager:spawnParticlePacket(name, pos, layer)
end



---Returns the native resolution of this Game.
---@return Vector2
function Game:getNativeResolution()
	return self.configManager:getNativeResolution()
end



---Returns the effective sound volume, dictated by the game options.
---@return number
function Game:getEffectiveSoundVolume()
	return self.runtimeManager.options:getEffectiveSoundVolume()
end



---Returns the effective music volume, dictated by the game options.
---@return number
function Game:getEffectiveMusicVolume()
	return self.runtimeManager.options:getEffectiveMusicVolume()
end



---Enables or disables fullscreen.
---@param fullscreen boolean Whether the fullscreen mode should be active.
function Game:setFullscreen(fullscreen)
	if fullscreen == love.window.getFullscreen() then return end
	if fullscreen then
		local _, _, flags = love.window.getMode()
		_DisplaySize = Vec2(love.window.getDesktopDimensions(flags.display))
	else
		_DisplaySize = self:getNativeResolution()
	end
	love.window.setMode(_DisplaySize.x, _DisplaySize.y, {fullscreen = fullscreen, resizable = true})
end



---Exits the game.
---@param forced boolean? If `true`, the engine will exit completely even if the "Return to Boot Screen" option is enabled.
function Game:quit(forced)
	self:save()
	self.resourceManager:unload()
	if _EngineSettings:getBackToBoot() and not forced then
		love.window.setMode(800, 600) -- reset window size
		_LoadBootScreen()
	else
		love.event.quit()
	end
end



return Game
