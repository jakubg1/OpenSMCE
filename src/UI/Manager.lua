local class = require "com.class"

---@class UIManager
---@overload fun():UIManager
local UIManager = class:derive("UIManager")

local UIWidget = require("src.UI.Widget")



function UIManager:new()
  self.widgets = {splash = nil, root = nil}

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
    levelGetAccuracy = function() return _Game.session.level:getShotAccuracy() end,

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


    getWidgetN = function(names) return self:getWidgetN(names) end,
    resetActive = function() self:resetActive() end
  }
end

function UIManager:initSplash()
  self.widgets.splash = UIWidget("Splash", _LoadJson(_ParsePath("ui/splash.json")))

  self.script = require(_ParsePathDots("ui.script"))
  self:executeCallback("init")
end

function UIManager:init()
	-- Cleanup the splash
	self.widgets.splash = nil

	-- Setup the UI
	self.widgets.root = UIWidget("Root", _LoadJson(_ParsePath("ui/root.json")))
end

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

function UIManager:draw()
  -- This table will contain the order in which widgets will be drawn.
  local layers = {}
	for i, layer in ipairs(_Game.configManager.hudLayerOrder) do
    layers[layer] = {}
  end

  -- Let every widget write into that table.
	for widgetN, widget in pairs(self.widgets) do
		widget:generateDrawData(layers, widgetN)
	end

  _Debug.uiWidgetCount = 0
	for i, layer in ipairs(_Game.configManager.hudLayerOrder) do
		for j, names in ipairs(layers[layer]) do
			self:getWidget(names):draw()
		end
    if _Game.particleManager then
      _Game.particleManager:draw(layer)
    end
	end
end



function UIManager:mousepressed(x, y, button)
	if button == 1 then
		for widgetN, widget in pairs(self.widgets) do
			widget:click()
		end
  end
end

function UIManager:mousereleased(x, y, button)
	if button == 1 then
		for widgetN, widget in pairs(self.widgets) do
			widget:unclick()
		end
    self:executeCallback("click")
	end
end

function UIManager:keypressed(key)
	for widgetN, widget in pairs(self.widgets) do
		widget:keypressed(key)
	end
end

function UIManager:textinput(t)
  for widgetN, widget in pairs(self.widgets) do
    widget:textinput(t)
  end
end



function UIManager:executeCallback(data)
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

function UIManager:resetActive()
	for widgetN, widget in pairs(self.widgets) do
		widget:resetActive()
	end
end

---Returns whether any meaningful UI widget like a button has been hovered.
---@return boolean
function UIManager:isButtonHovered()
  for widgetN, widget in pairs(self.widgets) do
    if widget:isButtonHovered() then
      return true
    end
  end
  return false
end



function UIManager:getWidget(names)
	local widget = self.widgets[names[1]]
	for i, name in ipairs(names) do if i > 1 then
    if not widget then
      --error("Could not find a widget: \"" .. strJoin(names, "/") .. "\"")
      return
    end
		widget = widget.children[name]
	end end
	return widget
end

function UIManager:getWidgetN(names)
  return self:getWidget(_StrSplit(names, "/"))
end

function UIManager:optionsLoad()
  -- TODO: HARDCODED - make it more flexible
  self:getWidget({"root", "Menu_Options", "Frame", "Slot_music", "Slider_Music"}).widget:setValue(_Game.runtimeManager.options:getMusicVolume())
  self:getWidget({"root", "Menu_Options", "Frame", "Slot_sfx", "Slider_Effects"}).widget:setValue(_Game.runtimeManager.options:getSoundVolume())
  self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Fullscreen"}).widget:setState(_Game.runtimeManager.options:getFullscreen())
  self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Mute"}).widget:setState(_Game.runtimeManager.options:getMute())
end

function UIManager:optionsSave()
  -- TODO: HARDCODED - make it more flexible
  _Game.runtimeManager.options:setMusicVolume(self:getWidget({"root", "Menu_Options", "Frame", "Slot_music", "Slider_Music"}).widget.value)
  _Game.runtimeManager.options:setSoundVolume(self:getWidget({"root", "Menu_Options", "Frame", "Slot_sfx", "Slider_Effects"}).widget.value)
  _Game.runtimeManager.options:setFullscreen(self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Fullscreen"}).widget.state)
  _Game.runtimeManager.options:setMute(self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Mute"}).widget.state)
end



return UIManager
