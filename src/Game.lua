local class = require "com.class"
local Timer = require("src.Timer")
local ConfigManager = require("src.ConfigManager")
local RuntimeManager = require("src.Game.RuntimeManager")
local Level = require("src.Game.Level")
local UIManager = require("src.UI.Manager")
local ParticleManager = require("src.Particle.Manager")

---Main class for a Game. Handles everything the Game has to do.
---@class Game
---@overload fun(name):Game
local Game = class:derive("Game")

---Constructs a new instance of Game.
---@param name string The name of the game, equivalent to the folder name in `games` directory.
function Game:new(name)
	self.name = name

	self.configManager = nil
	self.runtimeManager = nil
	self.level = nil

	self.uiManager = nil
	self.particleManager = nil
end

---Initializes the game and all its components.
function Game:init()
	_Log:printt("Game", "Selected game: " .. self.name)

	-- Step 1. Load the config
	self.configManager = ConfigManager()
	self.configManager:load()

	-- Step 2. Initialize the window and canvas
	local w, h = self:getNativeResolution()
	_Display:setResolution(w, h, true, self.configManager:getWindowTitle(), _EngineSettings:getMaximizeOnStart())
	_Display:setCanvas(w, h, self.configManager:getCanvasRenderingMode())
	_Renderer:setLayers(self.configManager.hudLayerOrder)

	-- Step 3. Initialize RNG and timer
	self.timer = Timer()
	math.randomseed(os.time())

	-- Step 4. Create a runtime manager
	self.runtimeManager = RuntimeManager()

	-- Step 5. Set up the UI Manager
	self.uiManager = UIManager()
	self.uiManager:initSplash()
end

---Loads all game resources.
function Game:loadMain()
	_Res:startLoadCounter("main")
	-- DEBUG: Make the game load everything on the fly
	--_Res.loadCounters.main = {queued = 1, loaded = 1, active = false, queueKeys = {}}
	_Res:scanResources()
	_Res:stopLoadCounter("main")
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
	local frames, delta = self.timer:getFrameCount()
	for i = 1, frames do
		self:tick(delta)
	end
end

---Updates the game logic. Contrary to `:update()`, this function will always have its delta time given as a multiple of 1/60.
---@param dt number Delta time in seconds.
function Game:tick(dt) -- always with 1/60 seconds
	if self.level then
		self.level:update(dt)
	end

	if self:getProfile() then
		self:getProfile():dumpVariables()
	end

	self.uiManager:update(dt)

	if self.particleManager then
		self.particleManager:update(dt)
	end

	if self.configManager:isRichPresenceEnabled() then
		self:updateRichPresence()
	end
end

---Starts a new Level from the current Profile, or loads one in progress if it has one.
---This also executes an appropriate entry in the UI script if the current level set's entry is a UI Script one. Yep, it's a mess.
---This function is intended to be called ONLY from UI scripts, using the UI Manager as a proxy.
function Game:startLevel()
	local session = assert(self:getSession(), "Attempt to start a level when no game is ongoing!")
	if session:getLevelEntry().type == "uiScript" then
		_Game.uiManager:executeCallback(session:getLevelEntry().callback)
	else
		self.level = Level(session:getLevelData())
		local savedLevelData = session:getLevelSaveData()
		if savedLevelData then
			-- Load existing level.
			self.level:deserialize(savedLevelData)
			self.uiManager:executeCallback("levelLoaded")
		else
			-- Start a new level.
			self.level:resetSequence()
			session:saveRollback()
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

---Saves the game.
function Game:save()
	if self.level then
		self.level:save()
	end
	self.runtimeManager:save()
end

---Spawns and returns a particle packet.
---@param particleEffect ParticleEffectConfig The particle effect resource.
---@param x number The initial X position of the particle packet.
---@param y number The initial Y position of the particle packet.
---@param layer string? The layer the particles are supposed to be drawn on. If `nil`, they will be drawn as a part of the game instead.
---@return ParticlePacket
function Game:spawnParticle(particleEffect, x, y, layer)
	return self.particleManager:spawnParticlePacket(particleEffect, x, y, layer or "MAIN")
end

---Executes a Game Event.
---@param event GameEventConfig The game event to be executed.
function Game:executeGameEvent(event)
	-- Abort the execution if any of the conditions are not met.
	if not _Utils.checkExpressions(event.conditions) then
		return
	end
	-- Execute the event.
	if event.type == "single" then
		self:executeGameEvent(event.event)
	elseif event.type == "sequence" then
		for i, subevent in ipairs(event.events) do
			self:executeGameEvent(subevent)
		end
	elseif event.type == "random" then
		self:executeGameEvent(event.events[math.random(#event.events)])
	elseif event.type == "setCoins" then
		local session = self:getSession()
		if not session then
			return
		end
		session:setCoins(event.value:evaluate())
	elseif event.type == "setLevelVariable" then
		if not self.level then
			return
		end
		self.level:setVariable(event.variable, event.value:evaluate())
	elseif event.type == "setLevelTimer" then
		if not self.level then
			return
		end
		self.level:setTimer(event.timer, event.time:evaluate())
	elseif event.type == "addToTimerSeries" then
		if not self.level then
			return
		end
		self.level:addToTimerSeries(event.timerSeries, event.time:evaluate())
	elseif event.type == "clearTimerSeries" then
		if not self.level then
			return
		end
		self.level:clearTimerSeries(event.timerSeries)
	elseif event.type == "collectibleEffect" then
		if not self.level then
			return
		end
		self.level:applyEffect(event.collectibleEffect)
	elseif event.type == "scoreEvent" then
		if not self.level then
			return
		end
		self.level:executeScoreEvent(event.scoreEvent)
	elseif event.type == "playSound" then
		event.soundEvent:play()
	end
end

---Returns the native resolution of this Game.
---@return integer, integer
function Game:getNativeResolution()
	return self.configManager:getNativeResolution()
end

---Returns the currently selected Profile.
---@return Profile
function Game:getProfile()
	return self.runtimeManager.profileManager:getCurrentProfile()
end

---Returns the ongoing Session for the currently selected Profile, if it exists.
---@return ProfileSession?
function Game:getSession()
	local profile = self:getProfile()
	return profile and profile:getSession()
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

---Updates the game's Rich Presence information.
function Game:updateRichPresence()
	local session = self:getSession()
	local line1 = "Playing: " .. self.configManager:getGameName()
	local line2 = ""

	if session then
		if self.level then
			line2 = string.format("Level %s (%s), Score: %s",
				session:getLevelName(),
				string.format("%s%%", math.floor((self.level:getObjectiveProgress(1)) * 100)),
				session:getScore()
			)
			if session:getLives() then
				line2 = line2 .. string.format(", Lives: %s", session:getLives())
			end
			if self.level.pause then
				line1 = line1 .. " - Paused"
			end
		else
			line2 = string.format("In menus, Score: %s", session:getScore())
			if session:getLives() then
				line2 = line2 .. string.format(", Lives: %s", session:getLives())
			end
		end
	else
		line2 = string.format("In menus")
	end

	_DiscordRPC:setStatus(line1, line2)
end

---Draws the game contents.
function Game:draw()
	_Debug:profDrawStart()

	-- Start drawing on the debug canvas. All `love.graphics.*` calls will go there.
	_Display:startDebug()

	-- Level
	if self.level then
		self.level:draw()
	end
	_Debug:profDrawCheckpoint()

	-- Particles and UI
	if self.particleManager then
		self.particleManager:draw()
	end
	self.uiManager:draw()
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
	if self.uiManager:isButtonHovered() then
		self.uiManager:mousereleased(x, y, button)
	elseif self.level then
		self.level:mousereleased(x, y, button)
	end
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

---Exits the game.
---@param forced boolean? If `true`, the engine will exit completely even if the "Return to Boot Screen" option is enabled.
function Game:quit(forced)
	self:save()
	_Res:unloadAllResources()
	if _EngineSettings:getBackToBoot() and not forced then
		_LoadBootScreen()
	else
		love.event.quit()
	end
end

return Game
