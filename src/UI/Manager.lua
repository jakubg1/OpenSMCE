local class = require "com.class"
local UIWidget = require("src.UI.Widget")

---@class UIManager
---@overload fun():UIManager
local UIManager = class:derive("UIManager")

---Constructs the UI Manager.
function UIManager:new()
    ---@type table<string, UIWidget?>
    self.widgets = {splash = nil, root = nil}

    self.script = nil
    self.scriptFunctions = {
        loadMain = function() _Game:loadMain() end,
        initSession = function() _Game:initSession() end,
        sessionTerminate = function() _Game:gameOver() end,
        loadingGetProgress = function() return _Res:getLoadProgress("main") end,

        levelStart = function() _Game:startLevel() end,
        levelRestartMusic = function() _Game.level:restartMusic() end,
        levelContinue = function() _Game.level:continueSequence() end,
        levelPause = function() _Game.level:setPause(true) end,
        levelUnpause = function() _Game.level:setPause(false) end,
        levelRestart = function() _Game.level:tryAgain() end,
        levelEnd = function() _Game:endLevel() end,
        levelWin = function() _Game:winLevel() end,
        levelSave = function() _Game:saveLevel() end,
        quit = function() _Game:quit() end,

        levelExists = function() return _Game.level end,
        levelGetProgress = function(n) return _Game.level:getObjectiveProgress(n or 1) end,
        levelGetObjectives = function() return _Game.level.objectives end,
        levelGetScore = function() return _Game.level.score end,
        levelGetShots = function() return _Game.level.spheresShot end,
        levelGetCoins = function() return _Game.level.coins end,
        levelGetGems = function() return _Game.level.gems end,
        levelGetChains = function() return _Game.level.sphereChainsSpawned end,
        levelGetStreak = function() return _Game.level.streak end,
        levelGetMaxStreak = function() return _Game.level.maxStreak end,
        levelGetMaxCascade = function() return _Game.level.maxCascade end,
        levelGetNewRecord = function() return _Game.level:hasNewScoreRecord() end,
        levelGetAccuracy = function() return _Game.level:getShotAccuracy() end,

        levelExecuteScoreEvent = function(event, x, y) _Game.level:executeScoreEvent(_Res:getScoreEventConfig(event), x, y) end,

        musicVolume = function(music, volume, duration) _Res:getMusic(music):play(volume, duration) end,
        musicStop = function(music, duration) _Res:getMusic(music):stop(duration) end,
        playSound = function(sound) _Res:getSoundEvent(sound):play() end,

        profileMSet = function(name) _Game.runtimeManager.profileManager:setCurrentProfile(name) end,
        profileMCreate = function(name) return _Game.runtimeManager.profileManager:createProfile(name) end,
        profileMDelete = function(name) _Game.runtimeManager.profileManager:deleteProfile(name) end,

        profileMGetNameOrder = function() return _Game.runtimeManager.profileManager.order end,

        profileNewGame = function(checkpoint, difficulty) _Game:getProfile():newGame(checkpoint, _Res:getDifficultyConfig(difficulty)) end,
        profileDeleteGame = function() _Game:getProfile():deleteGame() end,
        profileLevelAdvance = function() _Game:getSession():advanceLevel() end,
        profileHighscoreWrite = function() return _Game:getSession():writeHighscore() end,

        profileGetExists = function() return _Game:getProfile() ~= nil end,
        profileGetName = function() return _Game:getProfile().name end,
        profileGetLives = function() return _Game:getSession():getLives() end,
        profileGetCoins = function() return _Game:getSession():getCoins() end,
        profileGetScore = function() return _Game:getSession():getScore() end,
        profileGetSession = function() return _Game:getSession() end,
        profileGetLevel = function() return _Game:getSession():getTotalLevel() end,
        profileGetLevelData = function() return _Game:getSession():getLevelData() end,
        profileGetLevelName = function() return _Game:getSession():getLevelName() end,
        profileGetSavedLevel = function() return _Game:getSession():getLevelSaveData() end,
        profileGetMap = function() return _Game:getSession():getMapData() end,
        profileGetLatestCheckpoint = function() return _Game:getSession():getLatestCheckpoint() end,
        profileGetUnlockedCheckpoints = function(levelSet) return _Game:getProfile():getUnlockedCheckpoints(_Res:getLevelSetConfig(levelSet)) end,
        profileIsCheckpointUnlocked = function(levelSet, n) return _Game:getProfile():isCheckpointUnlocked(_Res:getLevelSetConfig(levelSet), n) end,
        profileIsCheckpointUpcoming = function() return _Game:getSession():isCheckpointUpcoming() end,

        profileSetVariable = function(name, value) _Game:getProfile():setVariable(name, value) end,
        profileGetVariable = function(name) return _Game:getProfile():getVariable(name) end,

        highscoreReset = function() _Game.runtimeManager.highscores:reset() end,
        highscoreGetEntry = function(n) return _Game.runtimeManager.highscores:getEntry(n) end,

        configGetMapData = function(name) return _Game.configManager:getMapData(name) end,
        configGetLevelData = function(levelSet, n) return _Res:getLevelSetConfig(levelSet).levelOrder[n].level end,
        configGetLevelName = function(levelSet, n) return _Res:getLevelSetConfig(levelSet).levelOrder[n].name end,
        configGetLevelCount = function(levelSet) return #_Res:getLevelSetConfig(levelSet).levelOrder end,
        configGetCheckpointID = function(levelSet, n) return _Game:getProfile():getCheckpointData(_Res:getLevelSetConfig(levelSet))[n].levelID end,
        configGetCheckpointLevel = function(levelSet, n) return _Game:getProfile():getCheckpointLevelN(_Res:getLevelSetConfig(levelSet), n) end,
        configGetCheckpointCount = function(levelSet) return #_Game:getProfile():getCheckpointData(_Res:getLevelSetConfig(levelSet)) end,

        optionsGetMusicVolume = function() return _Game.runtimeManager.options:getMusicVolume() end,
        optionsGetSoundVolume = function() return _Game.runtimeManager.options:getSoundVolume() end,
        optionsGetFullscreen = function() return _Game.runtimeManager.options:getFullscreen() end,
        optionsGetMute = function() return _Game.runtimeManager.options:getMute() end,
        optionsSetMusicVolume = function(volume) _Game.runtimeManager.options:setMusicVolume(volume) end,
        optionsSetSoundVolume = function(volume) _Game.runtimeManager.options:setSoundVolume(volume) end,
        optionsSetFullscreen = function(fullscreen) _Game.runtimeManager.options:setFullscreen(fullscreen) end,
        optionsSetMute = function(mute) _Game.runtimeManager.options:setMute(mute) end,


        getWidgetN = function(names) return self:getWidgetN(names) end,
        getWidgetListN = function(names) return self:getWidgetListN(names) end,
        resetActive = function() self:resetActive() end
    }

    self.hasFocus = true
end

---Initializes the splash screen, loads the UI Script and fires the `init` UI Script callback.
function UIManager:initSplash()
    self.widgets.splash = UIWidget("ui/splash.json")

    self.script = require(_ParsePathDots("ui.script"))
    self:executeCallback("init")
end

---Destroys the splash screen and loads the main game UI structure.
function UIManager:init()
    -- Cleanup the splash
    self.widgets.splash = nil

    -- Setup the UI
    self.widgets.root = UIWidget("ui/toplevel.json")
end

---Updates the UI Manager.
---@param dt number Time delta in seconds.
function UIManager:update(dt)
    -- despite being called since the splash screen starts, scripts are loaded when the main game widgets are loaded, and therefore this tick is called only after such event happens
    self:executeCallback("tick")

    if self.hasFocus ~= love.window.hasFocus() then
        self.hasFocus = love.window.hasFocus()
        if not self.hasFocus then
            self:executeCallback("lostFocus")
        end
    end

    for widgetN, widget in pairs(self.widgets) do
        widget:update(dt)
    end
end

---Draws all UI elements on the screen.
function UIManager:draw()
    _Debug.uiWidgetCount = 0
    -- Draw the UI widgets.
    for widgetN, widget in pairs(self.widgets) do
        widget:draw()
    end
end

---Executed when a mouse button is pressed.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button.
function UIManager:mousepressed(x, y, button)
    if button == 1 then
        for widgetN, widget in pairs(self.widgets) do
            widget:click()
        end
    end
end

---Executed when a mouse button is released.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button.
function UIManager:mousereleased(x, y, button)
    if button == 1 then
        for widgetN, widget in pairs(self.widgets) do
            widget:unclick()
        end
        self:executeCallback("click")
    end
end

---Executed when a key is pressed.
---@param key string The key code.
function UIManager:keypressed(key)
    for widgetN, widget in pairs(self.widgets) do
        widget:keypressed(key)
    end
end

---Executed when text is entered.
---@param t string The entered text.
function UIManager:textinput(t)
    for widgetN, widget in pairs(self.widgets) do
        widget:textinput(t)
    end
end

---Executes a UI script callback function, if it exists. Does nothing if the function does not exist in the UI script.
---@param name string The function name.
---@param parameters any[]? If specified, this is a list of parameters which will be passed to the executed function as a list.
function UIManager:executeCallback(name, parameters)
    local f = self.script[name]
    if f then
        f(self.scriptFunctions, parameters)
    end
end

---Deactivates all Widgets, which means they are no longer interactable.
function UIManager:resetActive()
    for widgetN, widget in pairs(self.widgets) do
        widget:resetActive()
    end
end

---Returns whether any meaningful UI widget like a button has been hovered.
---@return boolean
function UIManager:isButtonHovered()
    if _Debug.uiDebug:isHovered() then
        return false
    end
    for widgetN, widget in pairs(self.widgets) do
        if widget:isButtonHovered() then
            return true
        end
    end
    return false
end

---Returns a widget by its path. If no widget exists at the given location, returns `nil`.
---@param names string[] Path to the widget represented as a list of widget names to traverse through, starting from one of the root widget names.
---@return UIWidget?
function UIManager:getWidget(names)
    local widget = self.widgets[names[1]]
    for i, name in ipairs(names) do
        if i > 1 then
            if not widget then
                --error("Could not find a widget: \"" .. strJoin(names, "/") .. "\"")
                return
            end
            widget = widget:getChildN(name)
        end
    end
    return widget
end

---Returns a widget by its path. If no widget exists at the given location, returns `nil`.
---@param names string Path to the widget represented as widget names separated by slashes, starting from one of the root widget names.
---@return UIWidget?
function UIManager:getWidgetN(names)
    return self:getWidget(_Utils.strSplit(names, "/"))
end

---Returns a list of children widgets of the widget by its path. The child names must start at `1` and be a sequence of numbers.
---For example, if `root/List` is provided, the function will return a list of nodes at `root/List/1`, `root/List/2` and so on.
---@param names string Path to the widget represented as widget names separated by slashes, starting from one of the root widget names.
---@return UIWidget[]
function UIManager:getWidgetListN(names)
    local widgets = {}
    local i = 1
    while self:getWidgetN(names .. "/" .. tostring(i)) do
        widgets[i] = self:getWidgetN(names .. "/" .. tostring(i))
        i = i + 1
    end
    return widgets
end

return UIManager
