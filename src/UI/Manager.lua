local class = require "com/class"
local UIManager = class:derive("UIManager")

local strmethods = require("src/strmethods")

local UIWidget = require("src/UI/Widget")



function UIManager:new()
  self.widgets = {splash = nil, main = nil}

  self.script = nil
  self.scriptFunctions = {
    loadMain = function() game:loadMain() end,
    initSession = function() game:initSession() end,

    levelStart = function() game.session:startLevel() end,
    levelBegin = function() game.session.level:begin() end,
    levelBeginLoad = function() game.session.level:beginLoad() end,
    levelPause = function() game.session.level:setPause(true) end,
    levelUnpause = function() game.session.level:setPause(false) end,
    levelRestart = function() game.session.level:tryAgain() end,
    levelEnd = function() game.session:levelEnd() end,
    levelWin = function() game.session:levelWin() end,
    levelSave = function() game.session:levelSave() end,
    quit = function() game:quit() end,

    levelExists = function() return game:levelExists() end,
    levelGetProgress = function() return game.session.level.destroyedSpheres / game.session.level.target end,
    levelGetScore = function() return game.session.level.score end,
    levelGetShots = function() return game.session.level.spheresShot end,
    levelGetCoins = function() return game.session.level.coins end,
    levelGetGems = function() return game.session.level.gems end,
    levelGetChains = function() return game.session.level.sphereChainsSpawned end,
    levelGetMaxCombo = function() return game.session.level.maxCombo end,
    levelGetMaxChain = function() return game.session.level.maxChain end,

    musicVolume = function(music, volume) game:getMusic(music):setVolume(volume) end,

    profileNewGame = function(checkpoint) game.runtimeManager.profile:newGame(checkpoint) end,
    profileDeleteGame = function() game.runtimeManager.profile:deleteGame() end,
    profileLevelAdvance = function() game.runtimeManager.profile:advanceLevel() end,
    profileHighscoreWrite = function() self:profileHighscoreWrite() end,

    profileGetName = function() return game.runtimeManager.profile.name end,
    profileGetLives = function() return game.runtimeManager.profile:getLives() end,
    profileGetCoins = function() return game.runtimeManager.profile:getCoins() end,
    profileGetScore = function() return game.runtimeManager.profile:getScore() end,
    profileGetSession = function() return game.runtimeManager.profile:getSession() end,
    profileGetLevelN = function() return game.runtimeManager.profile:getLevel() end,
    profileGetLevel = function() return game.runtimeManager.profile:getCurrentLevelConfig() end,
    profileGetNextLevel = function() return game.runtimeManager.profile:getNextLevelConfig() end,
    profileGetSavedLevel = function() return game.runtimeManager.profile:getSavedLevel() end,
    profileGetMap = function() return game.runtimeManager.profile:getMapData() end,
    profileGetCheckpoint = function() return game.runtimeManager.profile:getCurrentCheckpointConfig() end,
    profileGetUnlockedCheckpoints = function() return game.runtimeManager.profile:getUnlockedCheckpoints() end,
    profileIsCheckpointUnlocked = function(n) return game.runtimeManager.profile:isCheckpointUnlocked(n) end,

    highscoreGetEntry = function(n) return game.runtimeManager.highscores:getEntry(n) end,

    configGetLevelData = function(n) return game.configManager.config.levels[n] end,
    configGetLevelData2 = function(n) return game.configManager.levels[n] end,
    configGetMapData = function(name) return game.configManager.maps[name] end,
    configGetCheckpointData = function(n) return game.configManager.config.checkpoints[n] end,

    optionsLoad = function() self:optionsLoad() end,
    optionsSave = function() self:optionsSave() end,


    getWidgetN = function(names) return self:getWidgetN(names) end,
    resetActive = function() self:resetActive() end
  }
end

function UIManager:initSplash()
  self.widgets.splash = UIWidget("Splash", loadJson(parsePath("ui/splash.json")))
  self.widgets.splash:show()
  self.widgets.splash:setActive()
  game:getMusic("menu"):setVolume(1)

  self.script = require(parsePath("ui/script"))
end

function UIManager:init()
	-- Cleanup the splash
	self.widgets.splash = nil

	-- Setup the UI
	self.widgets.root = UIWidget("Root", loadJson(parsePath("ui/root.json")))
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

	-- TODO: HARDCODED - make it more flexible
	if self.widgets.splash then
		-- splash progress bar
		self.widgets.splash.children.Frame.children.Progress.widget.valueData = game.resourceManager.stepLoadProcessedObjs / game.resourceManager.stepLoadTotalObjs
		-- splash play button
		if self.widgets.splash.children.Frame.children.Progress.widget.value == 1 then
			self.widgets.splash.children.Frame.children.Button_Play:show()
		end
	end

	for widgetN, widget in pairs(self.widgets) do
		widget:update(dt)
	end
end

function UIManager:draw()
	-- Widgets
	for widgetN, widget in pairs(self.widgets) do
		widget:generateDrawData()
	end
	for i, layer in ipairs(game.configManager.config.hudLayerOrder) do
		for widgetN, widget in pairs(self.widgets) do
			widget:draw(layer)
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
	end
end

function UIManager:keypressed(key)
	for widgetN, widget in pairs(self.widgets) do
		widget:keypressed(key)
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
  return self:getWidget(strSplit(names, "/"))
end

function UIManager:profileHighscoreWrite()
  local success = game.runtimeManager.profile:writeHighscore()
  if success then
    self:executeCallback("profileHighscoreWriteSuccess")
  else
    self:executeCallback("profileHighscoreWriteFail")
  end
end

function UIManager:optionsLoad()
  -- TODO: HARDCODED - make it more flexible
  self:getWidget({"root", "Menu_Options", "Frame", "Slot_music", "Slider_Music"}).widget:setValue(game.runtimeManager.options:getMusicVolume())
  self:getWidget({"root", "Menu_Options", "Frame", "Slot_sfx", "Slider_Effects"}).widget:setValue(game.runtimeManager.options:getSoundVolume())
  self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Fullscreen"}).widget:setState(game.runtimeManager.options:getFullscreen())
  self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Mute"}).widget:setState(game.runtimeManager.options:getMute())
end

function UIManager:optionsSave()
  -- TODO: HARDCODED - make it more flexible
  game.runtimeManager.options:setMusicVolume(self:getWidget({"root", "Menu_Options", "Frame", "Slot_music", "Slider_Music"}).widget.value)
  game.runtimeManager.options:setSoundVolume(self:getWidget({"root", "Menu_Options", "Frame", "Slot_sfx", "Slider_Effects"}).widget.value)
  game.runtimeManager.options:setFullscreen(self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Fullscreen"}).widget.state)
  game.runtimeManager.options:setMute(self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Mute"}).widget.state)
end

function UIManager:checkCondition(condition)
	if condition.type == "widget" then
		if condition.property == "visible" then
			return self:getWidget(condition.widget):isVisible() == condition.value
		elseif condition.property == "buttonActive" then
			return self:getWidget(condition.widget):isActive() == condition.value
		end
	elseif condition.type == "level" then
		if condition.property == "paused" then
			return game.session.level.pause == condition.value
		elseif condition.property == "started" then
			return game.session.level.started == condition.value
		end
	end
end



return UIManager
