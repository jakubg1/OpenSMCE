local class = require "com/class"
local UIManager = class:derive("UIManager")

local strmethods = require("src/strmethods")

local UIWidget = require("src/UI/Widget")



function UIManager:new()
  self.widgets = {splash = nil, main = nil}
  self.widgetVariables = {}

  self.script = nil
  self.scriptFunctions = {
    levelBegin = function() game.session.level:begin() end,
    levelBeginLoad = function() game.session.level:beginLoad() end,
    levelPause = function() game.session.level:setPause(true) end,
    levelRestart = function() game.session.level:tryAgain() end,

    musicVolume = function(music, volume) game:getMusic(event.music):setVolume(event.volume) end,

    profileHighscoreWrite = function() self:profileHighscoreWrite() end,

    optionsLoad = function() self:optionsLoad() end,
    optionsSave = function() self:optionsSave() end,


    getWidgetN = function(names) return self:getWidgetN(names) end
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
	self:parseUIScript(loadFile(parsePath("ui/script.txt")))
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
		self.widgetVariables.lives = game.runtimeManager.profile:getLives()
		self.widgetVariables.coins = game.runtimeManager.profile:getCoins()
		self.widgetVariables.score = numStr(game.runtimeManager.profile:getScore())
		self.widgetVariables.scoreAnim = numStr(game.session.scoreDisplay)
		self.widgetVariables.player = game.runtimeManager.profile.name
		self.widgetVariables.levelName = game.runtimeManager.profile:getCurrentLevelConfig().name
		self.widgetVariables.levelMapName = game.runtimeManager.profile.mapData.name
		self.widgetVariables.stageName = game.configManager.config.stageNamesTEMP[game.runtimeManager.profile:getCurrentLevelConfig().stage]
		if not self.widgetVariables.progress then
			self.widgetVariables.progress = 0
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
  local f = self.script.callbacks[callbackType]
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

function UIManager:parseUIScript(script)
	local s = strSplit(script, "\n")

	-- the current Widget we are editing
	local type = ""
	local widget = nil
	local widgetAction = nil

	for i, l in ipairs(s) do
		-- truncate the comment part
		l = strTrimCom(l)
		-- omit empty lines and comments
		if l:len() > 0 then
			local t = strSplit(l, " ")
			if t[2] == "->" then
				-- new widget definition
				local t2 = strSplit(t[1], ".")
				widget = self:getWidget(strSplit(t2[1], "/"))
				widgetAction = t2[2]
				type = "action"
			else
				-- adding an event to the most recently defined widget
				local t2 = strSplit(l, ":")
				local event = self:prepareEvent(t2[1], strSplit(t2[2], ","))
				if type == "action" then
					widget:addAction(widgetAction, event)
				end
			end
			print(l)
		end
	end
end

function UIManager:prepareEvent(eventType, params)
	local event = {type = eventType}

	if eventType == "print" then
		event.text = params[1]
	elseif eventType == "wait" then
		event.widget = strSplit(params[1], "/")
		event.actionType = params[2]
	elseif eventType == "jump" then
		event.condition = self:parseCondition(params[1])
		event.steps = tonumber(params[2])
	elseif eventType == "widgetShow"
		or eventType == "widgetHide"
		or eventType == "widgetClean"
		or eventType == "widgetSetActive"
		or eventType == "widgetButtonDisable"
		or eventType == "widgetButtonEnable"
	then
		event.widget = strSplit(params[1], "/")
	elseif eventType == "musicVolume" then
		event.music = params[1]
		event.volume = tonumber(params[2])
	end

	return event
end

function UIManager:parseCondition(s)
	local condition = {}

	s = strSplit(s, "?")
	condition.type = s[1]

	if condition.type == "widget" then
		s = strSplit(s[2], "=")
		condition.value = s[2]
		s = strSplit(s[1], ".")
		condition.widget = strSplit(s[1], "/")
		condition.property = s[2]
		-- convert the value to boolean if necessary
		if condition.property == "visible" or condition.property == "buttonActive" then
			condition.value = condition.value == "true"
		end
	elseif condition.type == "level" then
		s = strSplit(s[2], "=")
		condition.property = s[1]
		condition.value = s[2]
		-- convert the value to boolean if necessary
		if condition.property == "paused" or condition.property == "started" then
			condition.value = condition.value == "true"
		end
	end

	print("Condition parsed")
	for k, v in pairs(condition) do
		print(k, v)
	end

	return condition
end

function UIManager:executeEvents(events)
	if not events then return end
	local jumpN = 0
	for i, event in ipairs(events) do
		if jumpN > 0 then
			jumpN = jumpN - 1
		else
			self:executeEvent(event)
			if event.type == "end" then
				break
			elseif event.type == "wait" then
				-- this event loop is ended, the remaining events are packed in a new action which is then put and flagged as one-time
				for j = i + 1, #events do
					-- we need to make a new table for the event because if we edited the original one, the events in the original action would be flagged and deleted too
					local remainingEvent = {}
					for k, v in pairs(events[j]) do remainingEvent[k] = v end
					remainingEvent.onetime = true
					-- put it in the target widget's action we're waiting for
					self:getWidget(event.widget):addAction(event.actionType, remainingEvent)
				end
				break
			elseif event.type == "jump" then
				if self:checkCondition(event.condition) then
					jumpN = jumpN + event.steps
				end
			end
		end
	end
	-- delete from this table events that were flagged as onetime - reverse iteration
	for i = #events, 1, -1 do
		if events[i].onetime then
			table.remove(events, i)
		end
	end
end

function UIManager:executeEvent(event)
	-- main stuff
	if event.type == "print" then
		print(event.text)
	elseif event.type == "loadMain" then
		game:loadMain()
	elseif event.type == "sessionInit" then
		game:initSession()
	elseif event.type == "levelStart" then
		game.session:startLevel()
	elseif event.type == "levelBegin" then
		game.session.level:begin()
	elseif event.type == "levelBeginLoad" then
		game.session.level:beginLoad()
	elseif event.type == "levelPause" then
		game.session.level:setPause(true)
	elseif event.type == "levelUnpause" then
		game.session.level:setPause(false)
	elseif event.type == "levelRestart" then
		game.session.level:tryAgain()
	elseif event.type == "levelEnd" then
		game.session.level:unsave()
		game.session.level = nil
	elseif event.type == "levelWin" then
		game.session.level:win()
		game.session.level = nil
	elseif event.type == "levelSave" then
		game.session.level:save()
		game.session.level = nil
	elseif event.type == "quit" then
		game:quit()

	-- widget stuff
	elseif event.type == "widgetShow" then
		self:getWidget(event.widget):show()
	elseif event.type == "widgetHide" then
		self:getWidget(event.widget):hide()
	elseif event.type == "widgetClean" then
		self:getWidget(event.widget):clean()
	elseif event.type == "widgetSetActive" then
		self:getWidget(event.widget):setActive()
	elseif event.type == "widgetButtonDisable" then
		self:getWidget(event.widget):buttonSetEnabled(false)
	elseif event.type == "widgetButtonEnable" then
		self:getWidget(event.widget):buttonSetEnabled(true)

	-- music stuff
	elseif event.type == "musicVolume" then
		game:getMusic(event.music):setVolume(event.volume)

	-- profile stuff
	elseif event.type == "profileNewGame" then
		game.runtimeManager.profile:newGame()
	elseif event.type == "profileLevelAdvance" then
		game.runtimeManager.profile:advanceLevel()
	elseif event.type == "profileHighscoreWrite" then
    self:profileHighscoreWrite()

	-- options stuff
	elseif event.type == "optionsLoad" then
    self:optionsLoad()
	elseif event.type == "optionsSave" then
    self:optionsSave()
	end
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
