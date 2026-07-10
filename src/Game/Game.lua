local Class = require("com.class")
local ProfileManager = require("src.Game.ProfileManager")
local Highscores = require("src.Game.Highscores")
local Options = require("src.Game.Options")
local Level = require("src.Game.Level")

---Represents the specific game logic, which is specific to a single game (not universal for the engine).
---This specific class contains logic for the SM (sphere matching) part of the engine.
---@class Game : Class
---@overload fun(base: GameBase): Game
local Game = Class:derive("Game")

---Constructs a Game.
---@param base GameBase The base game.
function Game:new(base)
    self.base = base

	-- Step 1. Load the config
	self.gameplayConfig = _Res:getGameplayConfig("config/gameplay.json")

	-- Step 2. Load map data.
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

	-- Step 3. Register a few savestate-releated objects
	self.profileManager = ProfileManager()
	self.highscores = Highscores()
	self.options = Options()
	self.base.runtimeManager:registerModule("profiles", self.profileManager)
	self.base.runtimeManager:registerModule("highscores", self.highscores)
	self.base.runtimeManager:registerModule("options", self.options)
	self.base.runtimeManager:load()

    -- Step 4. Allocate any other variables
	self.level = nil
end

---Updates the game.
---@param dt number Delta time in seconds.
function Game:update(dt)
	_Display:setFullscreen(self.options:getSetting("fullscreen"))
end

---Updates the game logic. Contrary to `:update()`, this function will always have its delta time given as a multiple of 1/60.
---Or at least it should, as it ultimately depends on the timer configuration and leniency on framerate fluctuations.
---@param dt number Delta time in seconds.
function Game:tick(dt)
	if self.level then
		self.level:update(dt)
	end

	if self:getProfile() then
		self:getProfile():dumpVariables()
	end
end

---Executes a Game Event, if it has not been catched by the base game class.
---The event conditions have been already checked by the base class.
---@param event GameEventConfig The game event to be executed.
---@param x number? The X position where the event should be executed.
---@param y number? The Y position where the event should be executed.
function Game:executeGameEvent(event, x, y)
    -- Session events
	local session = self:getSession()
    if session then
        if event.type == "setCoins" then
            session:setCoins(event.value:evaluate())
        end
    end
    -- Level events
	local level = self:getLevel()
    if level then
        if event.type == "setLevelVariable" then
            level:setVariable(event.variable, event.value:evaluate())
        elseif event.type == "setLevelTimer" then
            level:setTimer(event.timer, event.time:evaluate())
        elseif event.type == "addToTimerSeries" then
            level:addToTimerSeries(event.timerSeries, event.time:evaluate())
        elseif event.type == "clearTimerSeries" then
            level:clearTimerSeries(event.timerSeries)
        elseif event.type == "collectibleEffect" then
            level:applyEffect(event.collectibleEffect)
        elseif event.type == "scoreEvent" then
            level:executeScoreEvent(event.scoreEvent)
        end
    end
end

---Starts a new Level from the current Profile, or loads one in progress if it has one.
---This also executes an appropriate entry in the UI script if the current level set's entry is a UI Script one. Yep, it's a mess.
---This function is intended to be called ONLY from UI scripts, using the UI Manager as a proxy.
function Game:startLevel()
	local session = assert(self:getSession(), "Attempt to start a level when no game is ongoing!")
	local entry = session:getLevelEntry()
	if entry.type == "uiScript" then
		self.base.uiManager:executeCallback(entry.callback)
	else
		self.level = Level(session:getLevelData())
		local savedLevelData = session:getLevelSaveData()
		if savedLevelData then
			-- Load existing level.
			_CriticalLoad = true
			self.level:deserialize(savedLevelData)
			_CriticalLoad = false
			self.base.uiManager:executeCallback("levelLoaded")
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
	self.base.uiManager:executeCallback("gameOver")
end

---Saves the game.
function Game:save()
	if self.level then
		self.level:save()
	end
end

---Returns the current level, if it exists.
---@return Level?
function Game:getLevel()
    return self.level
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

---Returns two text lines which will be displayed in the Discord's Rich Presence status for this game.
---@return string, string
function Game:getRichPresenceData()
	local session = self:getSession()
	local line1 = "Playing: " .. self.base:getName()
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

    return line1, line2
end

---Draws game-specific items.
function Game:draw()
	if self.level then
		self.level:draw()
	end
end

---Executed when a mouse button is pressed.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button.
function Game:mousepressed(x, y, button)
	if self.level then
		self.level:mousepressed(x, y, button)
	end
end

---Executed when a mouse button is released.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button.
function Game:mousereleased(x, y, button)
	if self.level then
		self.level:mousereleased(x, y, button)
	end
end

---Executed when a mouse wheel is scrolled.
---@param x integer The X wheel movement.
---@param y integer The Y wheel movement.
function Game:wheelmoved(x, y)
	-- STUB
end

---Executed when a key is pressed.
---@param key string The key code.
function Game:keypressed(key)
	if self.level then
		self.level:keypressed(key)
	end
end

---Executed when a key is released.
---@param key string The key code.
function Game:keyreleased(key)
	if self.level then
		self.level:keyreleased(key)
	end
end

return Game