local class = require "com/class"
local UIManager = class:derive("UIManager")

local strmethods = require("src/strmethods")

local UIWidget = require("src/UI/Widget")



function UIManager:new()
  self.widgets = {splash = nil, main = nil}
  self.widgetVariables = {}

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

    musicVolume = function(music, volume) game:getMusic(music):setVolume(volume) end,

    profileNewGame = function() game.runtimeManager.profile:newGame() end,
    profileLevelAdvance = function() game.runtimeManager.profile:advanceLevel() end,
    profileGetLevel = function() return game.runtimeManager.profile:getCurrentLevelConfig() end,
    profileGetNextLevel = function() return game.runtimeManager.profile:getNextLevelConfig() end,
    profileHighscoreWrite = function() self:profileHighscoreWrite() end,

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
	if game:sessionExists() then
    self.widgetVariables.player = game.runtimeManager.profile.name
    self.widgetVariables.scoreAnim = numStr(game.session.scoreDisplay)
    if not self.widgetVariables.progress then
      self.widgetVariables.progress = 0
    end
    if game.runtimeManager.profile:getSession() then
  		self.widgetVariables.lives = game.runtimeManager.profile:getLives()
  		self.widgetVariables.coins = game.runtimeManager.profile:getCoins()
  		self.widgetVariables.score = game.runtimeManager.profile:getScore()
  		self.widgetVariables.scoreStr = numStr(self.widgetVariables.score)
  		self.widgetVariables.levelName = game.runtimeManager.profile:getCurrentLevelConfig().name
  		self.widgetVariables.levelMapName = game.runtimeManager.profile.mapData.name
  		self.widgetVariables.stageName = game.configManager.config.stageNamesTEMP[game.runtimeManager.profile:getCurrentLevelConfig().stage]
    else
  		self.widgetVariables.lives = 0
  		self.widgetVariables.coins = 0
  		self.widgetVariables.score = 0
  		self.widgetVariables.scoreStr = ""
  		self.widgetVariables.levelName = ""
  		self.widgetVariables.levelMapName = ""
  		self.widgetVariables.stageName = ""
    end
	end

	if game:levelExists() then
		self.widgetVariables.progress = game.session.level.destroyedSpheres / game.session.level.target
		self.widgetVariables.levelScore = numStr(game.session.level.score)
		self.widgetVariables.levelShots = game.session.level.spheresShot
		self.widgetVariables.levelCoins = game.session.level.coins
		self.widgetVariables.levelGems = game.session.level.gems
		self.widgetVariables.levelChains = game.session.level.sphereChainsSpawned
		self.widgetVariables.levelMaxCombo = game.session.level.maxCombo
		self.widgetVariables.levelMaxChain = game.session.level.maxChain
	end

	-- Widgets
	for i, layer in ipairs(game.configManager.config.hudLayerOrder) do
		for widgetN, widget in pairs(self.widgets) do
			widget:draw(layer, self.widgetVariables)
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



function UIManager:executeCallback(callbackType)
  local f = self.script[callbackType]
  if f then
    f(self.scriptFunctions)
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
