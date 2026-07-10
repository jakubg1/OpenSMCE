local class = require "com.class"
local Timer = require("src.Timer")
local RuntimeManager = require("src.RuntimeManager")
local UIManager = require("src.UI.Manager")
local ParticleManager = require("src.Particle.Manager")
local Game = require("src.Game.Game")

---Main class for a Game. Handles everything the Game has to do.
---@class GameBase
---@overload fun(name):GameBase
local GameBase = class:derive("Game")

---Constructs a new instance of Game.
---@param name string The name of the game, equivalent to the folder name in `games` directory.
function GameBase:new(name)
	self.name = name

	self.runtimeManager = nil
	self.uiManager = nil
	self.particleManager = nil

	self.game = nil
end

---Initializes the game and all its components.
function GameBase:init()
	_Log:printt("Game", "Selected game: " .. self.name)

	-- Step 1. Load the config
	self.config = _Res:getGameConfig("config.json")

	-- Step 2. Initialize the window and canvas
	local ww, wh = self:getWindowResolution()
	_Display:setResolution(ww, wh, self.config.resizableWindow, self:getWindowTitle(), _Settings:getSetting("maximizeOnStart"))
	local w, h = self:getNativeResolution()
	_Display:setCanvas(w, h, self:getCanvasRenderingMode())
	_Renderer:setLayers(self.config.layers and self.config.layers.layers)

	-- Step 3. Initialize RNG and timer
	self.timer = Timer()
	math.randomseed(os.time())

	-- Step 4. Create a runtime manager
	self.runtimeManager = RuntimeManager()

	-- Step 5. Create a Particle Manager
	self.particleManager = ParticleManager()

	-- Step 6. Set up the UI Manager
	self.uiManager = UIManager()
	self.uiManager:loadScript()

	-- Step 7. Load the game
	self.game = Game(self)
end

---Loads all game resources.
function GameBase:loadResources()
	_Res:startLoadCounter("main")
	-- DEBUG: Make the game load everything on the fly
	--_Res.loadCounters.main = {queued = 1, loaded = 1, active = false, queueKeys = {}}
	_Res:scanResources()
	_Res:stopLoadCounter("main")
end

---Updates the game.
---@param dt number Delta time in seconds.
function GameBase:update(dt) -- callback from main.lua
	self.timer:update(dt)
	local frames, delta = self.timer:getFrameCount()
	for i = 1, frames do
		self:tick(delta)
	end

	self.game:update(dt)
end

---Updates the game logic. Contrary to `:update()`, this function will always have its delta time given as a multiple of 1/60.
---Or at least it should, as it ultimately depends on the timer configuration and leniency on framerate fluctuations.
---@param dt number Delta time in seconds.
function GameBase:tick(dt)
	-- DEBUG: Make the game crash at random
	if math.random() < 0.001 then
		--error("Surprise! Your Game Conceded!")
	end

	self.game:tick(dt)
	self.uiManager:update(dt)
	self.particleManager:update(dt)

	if self:isRichPresenceEnabled() then
		self:updateRichPresence()
	end
end

---Saves the game.
function GameBase:save()
	self.game:save()
	self.runtimeManager:save()
end

---Spawns and returns a particle packet.
---@param particleEffect ParticleEffectConfig The particle effect resource.
---@param x number The initial X position of the particle packet.
---@param y number The initial Y position of the particle packet.
---@param layer string The layer the particles are supposed to be drawn on.
---@return ParticlePacket
function GameBase:spawnParticle(particleEffect, x, y, layer)
	return self.particleManager:spawnParticlePacket(particleEffect, x, y, layer)
end

---Executes a Game Event.
---@param event GameEventConfig The game event to be executed.
---@param x number? The X position where the event should be executed.
---@param y number? The Y position where the event should be executed.
function GameBase:executeGameEvent(event, x, y)
	-- Abort the execution if any of the conditions are not met.
	if not _Utils.checkExpressions(event.conditions) then
		return
	end
	-- Execute the event.
	if event.type == "single" then
		self:executeGameEvent(event.event, x, y)
	elseif event.type == "sequence" then
		for i, subevent in ipairs(event.events) do
			self:executeGameEvent(subevent, x, y)
		end
	elseif event.type == "random" then
		self:executeGameEvent(event.events[math.random(#event.events)], x, y)
	elseif event.type == "playSound" then
		event.soundEvent:play()
	else
		-- This is not a builtin event. Let's pass it over to game-specific logic.
		self.game:executeGameEvent(event, x, y)
	end
end

---Returns the native resolution of this Game.
---@return integer, integer
function GameBase:getNativeResolution()
	return self.config.nativeResolution.x, self.config.nativeResolution.y
end

---Returns the default window resolution of this Game.
---@return integer, integer
function GameBase:getWindowResolution()
	if not self.config.windowResolution then
		return self:getNativeResolution()
	end
	return self.config.windowResolution.x, self.config.windowResolution.y
end

---Returns the game name if specified, else the internal (folder) name.
---@return string
function GameBase:getName()
	return self.config.name or self.name
end

---Returns the title the window should have.
---@return string
function GameBase:getWindowTitle()
	return self.config.windowTitle or string.format("OpenSMCE [%s] - %s", _VERSION, self:getName())
end

---Returns whether the Discord Rich Presence should be active in this game.
---@return boolean
function GameBase:isRichPresenceEnabled()
	return self.config.richPresence and self.config.richPresence.enabled
end

---Returns the Rich Presence Application ID for this game, if it exists.
---@return string?
function GameBase:getRichPresenceApplicationID()
	return self.config.richPresence and self.config.richPresence.applicationID
end

---Returns the canvas rendering mode, `"filtered"` by default.
---@return string
function GameBase:getCanvasRenderingMode()
	return self.config.canvasRenderingMode
end

---Returns the game's tick rate. Defaults to `60`.
---@return integer
function GameBase:getTickRate()
	return self.config.tickRate
end

---Translates a locale key to its value depending on the currently active locale and optionally fills in its parameters.
---@param key string The locale key. If not found, this string will be returned back.
---@param ... any Translation parameters, such as numbers.
---@return string
function GameBase:translate(key, ...)
	local text = self.config.locale and self.config.locale.keys[key] or key
	local success, result = pcall(function(...) return string.format(text, ...) end, ...)
	if success then
		return result
	end
	-- `string.format()` has failed, usually due to insufficient amount of parameters. Return the raw string.
	return text
end

---Updates the game's Rich Presence information.
function GameBase:updateRichPresence()
	_DiscordRPC:setStatus(self.game:getRichPresenceData())
end

---Draws the game contents.
function GameBase:draw()
	_Debug:profDrawStart()

	-- Start drawing on the debug canvas. All `love.graphics.*` calls will go there.
	_Display:startDebug()

	-- Game
	self.game:draw()
	_Debug:profDrawCheckpoint()

	-- Particles and UI
	self.uiManager:draw()
	self.particleManager:draw()
	_Debug:profDrawCheckpoint()

	-- Flush all accumulated render tasks and draw them on the display.
	_Display:start()
	_Renderer:flush()
	_Display:draw()

	-- Borders
	-- Not necessary; leaving this code for the future when the widescreen frame comes to the engine!
	--love.graphics.setColor(0, 0, 0)
	--love.graphics.rectangle("fill", 0, 0, _Display:getDisplayOffsetX(), _Display.size.y)
	--love.graphics.rectangle("fill", _Display.size.x - _Display:getDisplayOffsetX(), 0, _Display:getDisplayOffsetX(), _Display.size.y)

	-- Debug sprite atlas preview
	--love.graphics.setColor(1, 1, 1)
	--love.graphics.draw(_Res:getSpriteAtlas("sprite_atlases/spheres.json").canvas, 0, 0)

	_Debug:profDrawStop()
end

---Callback from `main.lua`.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button which was pressed.
function GameBase:mousepressed(x, y, button)
	if self.uiManager:isButtonHovered() then
		self.uiManager:mousepressed(x, y, button)
	else
		self.game:mousepressed(x, y, button)
	end
end

---Callback from `main.lua`.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button which was released.
function GameBase:mousereleased(x, y, button)
	self.uiManager:mousereleased(x, y, button)
	if not self.uiManager:isButtonHovered() then
		self.game:mousereleased(x, y, button)
	end
end

---Callback from `main.lua`.
---@param x integer The X delta of the scroll.
---@param y integer The Y delta of the scroll.
function GameBase:wheelmoved(x, y)
	-- STUB
end

---Callback from `main.lua`.
---@param key string The pressed key code.
function GameBase:keypressed(key)
	self.uiManager:keypressed(key)
	self.game:keypressed(key)
end

---Callback from `main.lua`.
---@param key string The released key code.
function GameBase:keyreleased(key)
	self.game:keyreleased(key)
end

---Callback from `main.lua`.
---@param t string Something which makes text going.
function GameBase:textinput(t)
	self.uiManager:textinput(t)
end

---Exits the game.
---@param forced boolean? If `true`, the engine will exit completely even if the "Return to Boot Screen" option is enabled.
function GameBase:quit(forced)
	self:save()
	_Res:reset()
	if _Settings:getSetting("backToBoot") and not forced then
		_LoadBootScreen()
	else
		love.event.quit()
	end
end

return GameBase
