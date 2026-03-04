local class = require "com.class"
local Timer = require("src.Timer")
local RuntimeManager = require("src.RuntimeManager")
local ProfileManager = require("src.Game.ProfileManager")
local Highscores = require("src.Game.Highscores")
local Options = require("src.Game.Options")
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

	self.runtimeManager = nil
	self.profileManager = nil
	self.highscores = nil
	self.options = nil
	self.level = nil

	self.uiManager = nil
	self.particleManager = nil
end

---Initializes the game and all its components.
function Game:init()
	_Log:printt("Game", "Selected game: " .. self.name)

	-- Step 1. Load the config
	self.config = _Res:getGameConfig("config.json")
	self.gameplayConfig = _Res:getGameplayConfig("config/gameplay.json")

	-- Load map data.
	-- TODO: This is now only used for checking the map names without loading the map (UI script -> stage map).
	-- Find out how to do it better at some point. Hint: Luxor 2 free play map selection dialog.
	self.maps = {}
	local mapList = _Utils.getDirListing(_ParsePath("maps"), "dir")
	for i, mapName in ipairs(mapList) do
		local mapConfig = _Utils.loadJson(_ParsePath("maps/" .. mapName .. "/config.json"))
		if mapConfig then
			_Log:printt("Game", "Loading map data: " .. mapName)
			self.maps[mapName] = mapConfig
		end
	end

	-- Step 2. Initialize the window and canvas
	local ww, wh = self:getWindowResolution()
	_Display:setResolution(ww, wh, self.config.resizableWindow, self:getWindowTitle(), _Settings:getSetting("maximizeOnStart"))
	local w, h = self:getNativeResolution()
	_Display:setCanvas(w, h, self:getCanvasRenderingMode())
	_Renderer:setLayers(self.config.layers and self.config.layers.layers)

	-- Step 3. Initialize RNG and timer
	self.timer = Timer()
	math.randomseed(os.time())

	-- Step 4. Create a runtime manager and a few savestate-releated objects
	self.runtimeManager = RuntimeManager()
	self.profileManager = ProfileManager()
	self.highscores = Highscores()
	self.options = Options()
	self.runtimeManager:registerModule("profiles", self.profileManager)
	self.runtimeManager:registerModule("highscores", self.highscores)
	self.runtimeManager:registerModule("options", self.options)
	self.runtimeManager:load()

	-- Step 5. Create a Particle Manager
	self.particleManager = ParticleManager()

	-- Step 6. Set up the UI Manager
	self.uiManager = UIManager()
	self.uiManager:loadScript()
end

---Loads all game resources.
function Game:loadResources()
	_Res:startLoadCounter("main")
	-- DEBUG: Make the game load everything on the fly
	--_Res.loadCounters.main = {queued = 1, loaded = 1, active = false, queueKeys = {}}
	_Res:scanResources()
	_Res:stopLoadCounter("main")
end

---Updates the game.
---@param dt number Delta time in seconds.
function Game:update(dt) -- callback from main.lua
	self.timer:update(dt)
	local frames, delta = self.timer:getFrameCount()
	for i = 1, frames do
		self:tick(delta)
	end

	_Display:setFullscreen(self.options:getSetting("fullscreen"))
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
	self.particleManager:update(dt)

	if self:isRichPresenceEnabled() then
		self:updateRichPresence()
	end
end

---Starts a new Level from the current Profile, or loads one in progress if it has one.
---This also executes an appropriate entry in the UI script if the current level set's entry is a UI Script one. Yep, it's a mess.
---This function is intended to be called ONLY from UI scripts, using the UI Manager as a proxy.
function Game:startLevel()
	local session = assert(self:getSession(), "Attempt to start a level when no game is ongoing!")
	local entry = session:getLevelEntry()
	if entry.type == "uiScript" then
		_Game.uiManager:executeCallback(entry.callback)
	else
		self.level = Level(session:getLevelData())
		local savedLevelData = session:getLevelSaveData()
		if savedLevelData then
			-- Load existing level.
			_CriticalLoad = true
			self.level:deserialize(savedLevelData)
			_CriticalLoad = false
			self.uiManager:executeCallback("levelLoaded")
		else
			-- Start a new level.
			self.level:reset()
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
---@param layer string The layer the particles are supposed to be drawn on.
---@return ParticlePacket
function Game:spawnParticle(particleEffect, x, y, layer)
	return self.particleManager:spawnParticlePacket(particleEffect, x, y, layer)
end

---Executes a Game Event.
---@param event GameEventConfig The game event to be executed.
---@param x number? The X position where the event should be executed.
---@param y number? The Y position where the event should be executed.
function Game:executeGameEvent(event, x, y)
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
	return self.config.nativeResolution.x, self.config.nativeResolution.y
end

---Returns the default window resolution of this Game.
---@return integer, integer
function Game:getWindowResolution()
	if not self.config.windowResolution then
		return self:getNativeResolution()
	end
	return self.config.windowResolution.x, self.config.windowResolution.y
end

---Returns the currently selected Profile.
---@return Profile
function Game:getProfile()
	return self.profileManager:getCurrentProfile()
end

---Returns the ongoing Session for the currently selected Profile, if it exists.
---@return ProfileSession?
function Game:getSession()
	local profile = self:getProfile()
	return profile and profile:getSession()
end

---Returns the game name if specified, else the internal (folder) name.
---@return string
function Game:getName()
	return self.config.name or self.name
end

---Returns the title the window should have.
---@return string
function Game:getWindowTitle()
	return self.config.windowTitle or string.format("OpenSMCE [%s] - %s", _VERSION, self:getName())
end

---Returns whether the Discord Rich Presence should be active in this game.
---@return boolean
function Game:isRichPresenceEnabled()
	return self.config.richPresence and self.config.richPresence.enabled
end

---Returns the Rich Presence Application ID for this game, if it exists.
---@return string?
function Game:getRichPresenceApplicationID()
	return self.config.richPresence and self.config.richPresence.applicationID
end

---Returns the canvas rendering mode, `"filtered"` by default.
---@return string
function Game:getCanvasRenderingMode()
	return self.config.canvasRenderingMode
end

---Returns the game's tick rate. Defaults to `60`.
---@return integer
function Game:getTickRate()
	return self.config.tickRate
end

---Gets map data by map name from `config.json` in the respective map directory.
---If no such map exists, throws an error.
---@param name string The map directory name.
---@return table
function Game:getMapData(name)
	-- TODO/HARD: Currently, loading a map config also causes all of the related map assets to load.
	-- Find a way to load resources only partially without dependencies or find a way to load resource only when they're needed.
	--return _Res:getMapConfig("maps/" .. name .. "/config.json")
	return assert(self.maps[name], string.format("Map '%s' not found", name))
end

---Translates a locale key to its value depending on the currently active locale and optionally fills in its parameters.
---@param key string The locale key. If not found, this string will be returned back.
---@param ... any Translation parameters, such as numbers.
---@return string
function Game:translate(key, ...)
	local text = self.config.locale and self.config.locale.keys[key] or key
	local success, result = pcall(function(...) return string.format(text, ...) end, ...)
	if success then
		return result
	end
	-- `string.format()` has failed, usually due to insufficient amount of parameters. Return the raw string.
	return text
end

---Updates the game's Rich Presence information.
function Game:updateRichPresence()
	local session = self:getSession()
	local line1 = "Playing: " .. self:getName()
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
	if self.level and not self.uiManager:isButtonHovered() then
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
	_Res:reset()
	if _Settings:getSetting("backToBoot") and not forced then
		_LoadBootScreen()
	else
		love.event.quit()
	end
end

return Game
