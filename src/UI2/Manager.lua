local class = require "com/class"

---@class UI2Manager
---@overload fun():UI2Manager
local UI2Manager = class:derive("UI2Manager")

-- Place your imports here
local UI2Node = require("src/UI2/Node")
local UI2Sequence = require("src/UI2/Sequence")



---Constructs the UI2Manager.
function UI2Manager:new()
    self.rootNodes = {}
    self.activeSequences = {}

    self.hasFocus = true

    self.script = nil
    self.scriptFunctions = {
        loadMain = function() _Game:loadMain() end,
        initSession = function() _Game:initSession() end,
        loadingGetProgress = function() return _Game.resourceManager.stepLoadProcessedObjs / _Game.resourceManager.stepLoadTotalObjs end,

        levelStart = function() _Game.session:startLevel() end,
        levelBegin = function() _Game.session.level:begin() end,
        levelBeginLoad = function() _Game.session.level:beginLoad() end,
        levelPause = function() _Game.session.level:setPause(true) end,
        levelUnpause = function() _Game.session.level:setPause(false) end,
        levelRestart = function() _Game.session.level:tryAgain() end,
        levelEnd = function() _Game.session:levelEnd() end,
        levelWin = function() _Game.session:levelWin() end,
        levelSave = function() _Game.session:levelSave() end,
        quit = function() _Game:quit() end,

        levelExists = function() return _Game:levelExists() end,
        levelGetProgress = function(n) return _Game.session.level:getObjectiveProgress(n or 1) end,
        levelGetObjectives = function() return _Game.session.level.objectives end,
        levelGetScore = function() return _Game.session.level.score end,
        levelGetShots = function() return _Game.session.level.spheresShot end,
        levelGetCoins = function() return _Game.session.level.coins end,
        levelGetGems = function() return _Game.session.level.gems end,
        levelGetChains = function() return _Game.session.level.sphereChainsSpawned end,
        levelGetMaxCombo = function() return _Game.session.level.maxCombo end,
        levelGetMaxChain = function() return _Game.session.level.maxChain end,
        levelGetNewRecord = function() return _Game.session.level:hasNewScoreRecord() end,
        levelGetCombo = function() return _Game.session.level.combo end,

        musicVolume = function(music, volume) _Game:getMusic(music):setVolume(volume) end,

        profileMSet = function(name) _Game.runtimeManager.profileManager:setCurrentProfile(name) end,
        profileMCreate = function(name) return _Game.runtimeManager.profileManager:createProfile(name) end,
        profileMDelete = function(name) _Game.runtimeManager.profileManager:deleteProfile(name) end,

        profileMGetNameOrder = function() return _Game.runtimeManager.profileManager.order end,

        profileNewGame = function(checkpoint) _Game:getCurrentProfile():newGame(checkpoint) end,
        profileDeleteGame = function() _Game:getCurrentProfile():deleteGame() end,
        profileLevelAdvance = function() _Game:getCurrentProfile():advanceLevel() end,
        profileHighscoreWrite = function() return _Game:getCurrentProfile():writeHighscore() end,

        profileGetExists = function() return _Game:getCurrentProfile() ~= nil end,
        profileGetName = function() return _Game:getCurrentProfile().name end,
        profileGetLives = function() return _Game:getCurrentProfile():getLives() end,
        profileGetCoins = function() return _Game:getCurrentProfile():getCoins() end,
        profileGetScore = function() return _Game:getCurrentProfile():getScore() end,
        profileGetSession = function() return _Game:getCurrentProfile():getSession() end,
        profileGetLevelN = function() return _Game:getCurrentProfile():getLevel() end,
        profileGetLevel = function() return _Game:getCurrentProfile():getLevelData() end,
        profileGetLevelName = function() return _Game:getCurrentProfile():getLevelName() end,
        profileGetSavedLevel = function() return _Game:getCurrentProfile():getSavedLevel() end,
        profileGetMap = function() return _Game:getCurrentProfile():getMapData() end,
        profileGetLatestCheckpoint = function() return _Game:getCurrentProfile():getLatestCheckpoint() end,
        profileGetUnlockedCheckpoints = function() return _Game:getCurrentProfile():getUnlockedCheckpoints() end,
        profileIsCheckpointUnlocked = function(n) return _Game:getCurrentProfile():isCheckpointUnlocked(n) end,
        profileIsCheckpointUpcoming = function() return _Game:getCurrentProfile():isCheckpointUpcoming() end,

        profileSetVariable = function(name, value) _Game:getCurrentProfile():setVariable(name, value) end,
        profileGetVariable = function(name) return _Game:getCurrentProfile():getVariable(name) end,

        highscoreReset = function() _Game.runtimeManager.highscores:reset() end,
        highscoreGetEntry = function(n) return _Game.runtimeManager.highscores:getEntry(n) end,

        configGetLevelData = function(n) return _Game.configManager.levels[n] end,
        configGetMapData = function(name) return _Game.configManager.maps[name] end,
        configGetLevelID = function(n) return _Game.configManager.levelSet.levelOrder[n].level end,
        configGetLevelName = function(n) return _Game.configManager.levelSet.levelOrder[n].name end,
        configGetCheckpointID = function(n) return _Game.configManager.levelSet.checkpoints[n] end,
        configGetCheckpointLevel = function(n) return _Game.configManager:getCheckpointLevelN(n) end,

        optionsLoad = function() self:optionsLoad() end,
        optionsSave = function() self:optionsSave() end,


        getWidgetN = function(path) return self:getNode(path) end,
        playSequence = function(name) self:playSequence(name) end,
        resetActive = function() self:resetActive() end
    }
end



---Initializes the Splash Screen and the UI script. An `init` callback is fired as well.
---All Splash Screen's assets must be already loaded, i.e. specified in `config/loadlist.json`.
function UI2Manager:initSplash()
    self:loadRootNode("splash")

    self.script = require(_ParsePath("ui2/script"))
    self:executeCallback("init")
end



---Deinitializes the Splash Screen and loads actual UI.
function UI2Manager:init()
    self.rootNodes.splash = nil
    self:loadRootNode("root")
end



---Updates all Sequences, Nodes and Widgets as well as fires certain UI script callbacks.
---@param dt number Delta time in seconds.
function UI2Manager:update(dt)
    -- Fire a tick callback.
	self:executeCallback("tick")

    -- Fire a lostFocus callback if the window has lost the focus (minimized etc).
	if self.hasFocus ~= love.window.hasFocus() then
		self.hasFocus = love.window.hasFocus()
		if not self.hasFocus then
			self:executeCallback("lostFocus")
		end
	end

    -- Update sequences.
    for i = #self.activeSequences, 1, -1 do
        local sequence = self.activeSequences[i]
        sequence:update(dt)
        if sequence:isFinished() then
            table.remove(self.activeSequences, i)
        end
    end

    -- Update nodes and widgets.
    for nodeN, node in pairs(self.rootNodes) do
        node:update(dt)
    end
end



---Loads a Root Node from a file `ui2/layouts/<name>.json`.
---@param name string The root node name.
function UI2Manager:loadRootNode(name)
    self.rootNodes[name] = UI2Node(self, _Game.resourceManager:getUINodeConfig("ui2/layouts/" .. name .. ".json"), name)
end



---Returns a Node with a given path, if it exists.
---@param path string The path to the Node, starting with "root" or "splash" depending on the currently active root node, and next nodes separated by slashes.
---@return UI2Node?
function UI2Manager:getNode(path)
    local names = _StrSplit(path, "/")
    local node = self.rootNodes[names[1]]
    for i, name in ipairs(names) do
        if i > 1 then
            node = node:getChild(name)
        end
        if not node then
            return nil
        end
    end
    return node
end



---Activates a given Node and all its children.
---@param path string The path to the Node.
---@param append boolean? Whether the already activated Nodes should remain active.
function UI2Manager:setActive(path, append)
    self:getNode(path):setActive(append)
end



---Deactivates all Nodes.
function UI2Manager:resetActive()
    for nodeN, node in pairs(self.rootNodes) do
        node:resetActive()
    end
end



---Executes a UI script callback.
---@param data string|table Can be either a string or a table.
--- - In case of a string, it's the name of a callback. No parameters will be passed.
--- - In case of a table, there are two fields:
---   - `name` - The name of a callback, as if it was a string.
---   - `params` - Data which should be passed along with the callback. Can be of any type and will come as a second parameter in the appropriate UI script callback. 
function UI2Manager:executeCallback(data)
    local name = ""
    local params = {}
    if type(data) == "string" then
        name = data
    else
        name = data.name
        params = data.parameters
    end
    local f = self.script[name]
    if f then
        f(self.scriptFunctions, params)
    end
end



---Plays a Sequence with a given name.
---@param name string The Sequence to be activated.
function UI2Manager:playSequence(name)
    name = "ui2/sequences/" .. name .. ".json"
    table.insert(self.activeSequences, UI2Sequence(self, _Game.resourceManager:getUISequenceConfig(name)))
end



---Injects the game options to a hardcoded set of Nodes.
function UI2Manager:optionsLoad()
    -- TODO: HARDCODED - make it more flexible
    --[[
    self:getNode("root/Menu_Options/Frame/Slot_music/Slider_Music").widget:setValue(_Game.runtimeManager.options:getMusicVolume())
    self:getNode("root/Menu_Options/Frame/Slot_sfx/Slider_Effects").widget:setValue(_Game.runtimeManager.options:getSoundVolume())
    self:getNode("root/Menu_Options/Frame/Toggle_Fullscreen").widget:setState(_Game.runtimeManager.options:getFullscreen())
    self:getNode("root/Menu_Options/Frame/Toggle_Mute").widget:setState(_Game.runtimeManager.options:getMute())
    ]]
end



---Translates the current settings of Nodes to the game options and overwrites them.
function UI2Manager:optionsSave()
    -- TODO: HARDCODED - make it more flexible
    --[[
    _Game.runtimeManager.options:setMusicVolume(self:getNode("root/Menu_Options/Frame/Slot_music/Slider_Music").widget.value)
    _Game.runtimeManager.options:setSoundVolume(self:getNode("root/Menu_Options/Frame/Slot_sfx/Slider_Effects").widget.value)
    _Game.runtimeManager.options:setFullscreen(self:getNode("root/Menu_Options/Frame/Toggle_Fullscreen").widget.state)
    _Game.runtimeManager.options:setMute(self:getNode("root/Menu_Options/Frame/Toggle_Mute").widget.state)
    ]]
end



---Draws the UI on the screen.
function UI2Manager:draw()
    -- This table will contain the order in which the nodes will be drawn.
    local layers = {}
    for i, layer in ipairs(_Game.configManager.hudLayerOrder) do
        layers[layer] = {}
    end

    -- Let every Node write into that table.
    for nodeN, node in pairs(self.rootNodes) do
        node:generateDrawData(layers)
    end

    _Debug.uiWidgetCount = 0
    for i, layer in ipairs(_Game.configManager.hudLayerOrder) do
        for j, node in ipairs(layers[layer]) do
            node:draw()
        end
        if _Game.particleManager then
            _Game.particleManager:draw(layer)
        end
    end
end



---Callback from Game.lua.
---@see Game.mousepressed
---@param x number
---@param y number
---@param button number
function UI2Manager:mousepressed(x, y, button)
    for nodeN, node in pairs(self.rootNodes) do
        node:mousepressed(x, y, button)
    end
end



---Callback from Game.lua.
---@see Game.mousereleased
---@param x number
---@param y number
---@param button number
function UI2Manager:mousereleased(x, y, button)
    for nodeN, node in pairs(self.rootNodes) do
        node:mousereleased(x, y, button)
    end
    --self:executeCallback("click")
end



---Callback from Game.lua.
---@see Game.keypressed
---@param key string
function UI2Manager:keypressed(key)
    for nodeN, node in pairs(self.rootNodes) do
		node:keypressed(key)
	end
end



---Callback from Game.lua.
---@see Game.textinput
---@param t string
function UI2Manager:textinput(t)
    for nodeN, node in pairs(self.rootNodes) do
        node:textinput(t)
    end
end



return UI2Manager