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
local Session = require("src.Game.Session")

local UIManager = require("src.UI.Manager")
local UI2Manager = require("src.UI2.Manager")
local ParticleManager = require("src.Particle.Manager")



---Constructs a new instance of Game.
---@param name string The name of the game, equivalent to the folder name in `games` directory.
function Game:new(name)
	self.name = name

	self.hasFocus = false

	self.configManager = nil
	self.resourceManager = nil
	self.runtimeManager = nil
	self.session = nil

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
	_SetResolution(res, true, self.configManager:getWindowTitle())
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

	-- Step 6. Set up the UI Manager or the experimental UI2 Manager
	self.uiManager = self.configManager.config.useUI2 and UI2Manager() or UIManager()
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
	-- Load whatever needs loading the new way from config.
	self.configManager:loadStuffAfterResources()
	-- Setup the UI and particles
	self.uiManager:init()
	self.particleManager = ParticleManager()

	self.session = Session()
	self.session:init()
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

	if self:sessionExists() then
		self.session:update(dt)
	end

	if self:levelExists() then
		self.session.level.colorManager:dumpVariables()
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



---Updates the game's Rich Presence information.
function Game:updateRichPresence()
	local p = self:getCurrentProfile()
	local line1 = "Playing: " .. self.configManager:getGameName()
	local line2 = ""

	if self:levelExists() then
		local l = self.session.level
		line2 = string.format("Level %s (%s), Score: %s, Lives: %s",
			p:getLevelName(),
			l.won and "Complete!" or string.format("%s%%", math.floor((l:getObjectiveProgress(1)) * 100)),
			p:getScore(),
			p:getLives()
		)
		if l.pause then
			line1 = line1 .. " - Paused"
		end
	elseif p and p:getSession() then
		line2 = string.format("In menus, Score: %s, Lives: %s", p:getScore(), p:getLives())
	else
		line2 = string.format("In menus")
	end

	_DiscordRPC:setStatus(line1, line2)
end



---Returns... not really a boolean?! But acts like one. Don't mess with the programmer.
---Oh and by the way, this function is self-explanatory.
---@return Session|nil
function Game:sessionExists()
	return self.session
end



---This is even weirder. Don't ever try to use the returned result in any other way than a boolean!!!
---@return Level|nil
function Game:levelExists()
	return self.session and self.session.level
end



---Draws the game contents.
function Game:draw()
	_Debug:profDraw2Start()

	-- Start drawing on canvas (if canvas mode set)
	if self.renderCanvas then
		love.graphics.setCanvas({self.renderCanvas, stencil = true})
		love.graphics.clear()
	end

	-- Session and level
	if self:sessionExists() then
		self.session:draw()
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
	else
		if self:levelExists() then
			if button == 1 then
				self.session.level.shooter:shoot()
			elseif button == 2 then
				self.session.level.shooter:swapColors()
			end
		end
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
	-- shooter
	if self:levelExists() then
		local shooter = self.session.level.shooter
		if key == "left" then shooter.moveKeys.left = true end
		if key == "right" then shooter.moveKeys.right = true end
		if key == "up" then shooter:shoot() end
		if key == "down" then shooter:swapColors() end
	end
end



---Callback from `main.lua`.
---@param key string The released key code.
function Game:keyreleased(key)
	-- shooter
	if self:levelExists() then
		local shooter = self.session.level.shooter
		if key == "left" then shooter.moveKeys.left = false end
		if key == "right" then shooter.moveKeys.right = false end
	end
end



---Callback from `main.lua`.
---@param t string Something which makes text going.
function Game:textinput(t)
	self.uiManager:textinput(t)
end



---Saves the game.
function Game:save()
	if self:levelExists() then self.session.level:save() end
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
