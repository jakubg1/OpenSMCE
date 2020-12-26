local class = require "com/class"
local Game = class:derive("Game")

local strmethods = require("src/strmethods")

local Vec2 = require("src/Essentials/Vector2")

local Timer = require("src/Timer")

local ResourceBank = require("src/ResourceBank")
local RuntimeManager = require("src/RuntimeManager")
local Session = require("src/Session")

local UIWidget = require("src/UI/Widget")
local ParticleManager = require("src/Particle/Manager")
local Sprite = require("src/Sprite")

function Game:new(name)
	self.name = name
	
	self.hasFocus = false
	
	self.resourceBank = nil
	self.runtimeManager = nil
	self.session = nil
	
	self.widgets = {splash = nil, main = nil}
	self.widgetVariables = {}
	self.widgetCallbacks = {}
	
	self.particleManager = nil
	
	self.sphereSprites = {}
	self.nextSphereSprites = {}
	
	
	-- revert to original font size
	love.graphics.setFont(love.graphics.newFont())
end

function Game:init()
	print("Selected game: " .. self.name)
	
	-- Step 1. Load the config
	self.config = loadJson(parsePath("config.json"))
	
	-- Step 2. Initialize the window
	love.window.setTitle(self.config.general.windowTitle or ("OpenSMCE [" .. VERSION .. "] - " .. self.name))
	love.window.setMode(self.config.general.nativeResolution.x, self.config.general.nativeResolution.y, {resizable = true})
	
	-- Step 3. Initialize RNG and timer
	self.timer = Timer()
	math.randomseed(os.time())
	
	-- Step 4. Create a resource bank
	self.resourceBank = ResourceBank()
	
	-- Step 5. Load initial resources (enough to start up the splash screen)
	self.resourceBank:loadList(self.config.loadList)
	
	-- Step 6. Create a runtime manager
	self.runtimeManager = RuntimeManager()
	self.satMode = self.runtimeManager.profile.data.session.ultimatelySatisfyingMode
	
	-- Step 7. Set up the splash widget
	self.widgets.splash = UIWidget("Splash", loadJson(parsePath("ui/splash.json")))
	self.widgets.splash:show()
	self.widgets.splash:setActive()
	self:getMusic("menu"):setVolume(1)
end

function Game:loadMain()
	-- Loads all game resources
	self.resourceBank:stepLoadList(self.config.resourceList)
end

function Game:initSession()
	-- Cleanup the splash
	self.widgets.splash = nil
	
	-- Setup the UI and particles
	self.widgets.root = UIWidget("Root", loadJson(parsePath("ui/root.json")))
	self:parseUIScript(loadFile(parsePath("ui/script.txt")))
	self.particleManager = ParticleManager()
	
	-- Setup the legacy sphere sprites
	for i = 0, 7 do
		if i > 0 then self.sphereSprites[i] = Sprite("sprites/sphere.json", {color = i}) end
		self.nextSphereSprites[i] = Sprite("sprites/next_sphere.json", {color = i})
	end
	self.sphereSprites[-3] = Sprite("sprites/sphere_lightning.json")
	self.sphereSprites[-2] = Sprite("sprites/sphere_fire.json")
	self.sphereSprites[-1] = Sprite("sprites/sphere_wild.json")
	self.sphereSprites[0] = Sprite("sprites/sphere_vise.json")
	self.nextSphereSprites[-3] = Sprite("sprites/next_sphere_lightning.json")
	self.nextSphereSprites[-2] = Sprite("sprites/next_sphere_fire.json")
	self.nextSphereSprites[-1] = Sprite("sprites/next_sphere_wild.json")
	
	self.session = Session()
	self.session:init()
end

function Game:update(dt) -- callback from main.lua
	self.timer:update(dt)
	for i = 1, self.timer:getFrameCount() do
		self:tick(self.timer.frameLength)
	end
end

function Game:tick(dt) -- always with 1/60 seconds
	-- despite being called since the splash screen starts, scripts are loaded when the main game widgets are loaded, and therefore this tick is called only after such event happens
	self:executeCallback("tick")
	
	if self.hasFocus ~= love.window.hasFocus() then
		self.hasFocus = love.window.hasFocus()
		if not self.hasFocus then
			self:executeCallback("lostFocus")
		end
	end
	
	self.resourceBank:update(dt)
	
	if self:sessionExists() then
		self.session:update(dt)
	end
	
	-- TODO: HARDCODED - make it more flexible
	if self.widgets.splash then
		-- splash progress bar
		self.widgets.splash.children.Frame.children.Progress.widget.valueData = self.resourceBank.stepLoadProcessedObjs / self.resourceBank.stepLoadTotalObjs
		-- splash play button
		if self.widgets.splash.children.Frame.children.Progress.widget.value == 1 then
			self.widgets.splash.children.Frame.children.Button_Play:show()
		end
	end
	
	for widgetN, widget in pairs(self.widgets) do
		widget:update(dt)
	end
	
	for i, sphereSprite in pairs(self.sphereSprites) do sphereSprite:update(dt) end
	
	if self.particleManager then self.particleManager:update(dt) end
end

function Game:sessionExists()
	return self.session
end

function Game:levelExists()
	return self.session and self.session.level
end



function Game:draw()
	-- Session and level
	if self:sessionExists() then
		self.session:draw()
		
		self.widgetVariables.lives = self.runtimeManager.profile:getLives()
		self.widgetVariables.coins = self.runtimeManager.profile:getCoins()
		self.widgetVariables.score = numStr(self.session.scoreDisplay)
		self.widgetVariables.player = self.runtimeManager.profile.name
		for i, entry in ipairs(self.runtimeManager.highscores.data.entries) do
			self.widgetVariables["highscore" .. tostring(i) .. "score"] = numStr(entry.score)
			self.widgetVariables["highscore" .. tostring(i) .. "name"] = entry.name
			self.widgetVariables["highscore" .. tostring(i) .. "level"] = entry.level
		end
		if not self.widgetVariables.progress then
			self.widgetVariables.progress = 0
		end
	end
	
	if self:levelExists() then
		self.widgetVariables.progress = self.session.level.destroyedSpheres / self.session.level.target
		self.widgetVariables.levelName = self.session.level.name
		self.widgetVariables.levelMapName = self.session.level.map.name
		self.widgetVariables.levelScore = numStr(self.session.level.score)
		self.widgetVariables.levelShots = self.session.level.spheresShot
		self.widgetVariables.levelCoins = self.session.level.coins
		self.widgetVariables.levelGems = self.session.level.gems
		self.widgetVariables.levelChains = self.session.level.sphereChainsSpawned
		self.widgetVariables.levelMaxCombo = self.session.level.maxCombo
		self.widgetVariables.levelMaxChain = self.session.level.maxChain
	end
	
	-- Widgets
	dbg:profDraw2Start()
	for i, layer in ipairs(self.config.hudLayerOrder) do
		for widgetN, widget in pairs(self.widgets) do
			widget:draw(layer, self.widgetVariables)
		end
	end
	dbg:profDraw2Stop()
	
	-- Particles
	if self.particleManager then self.particleManager:draw() end
	
	-- Borders
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", 0, 0, getDisplayOffsetX(), displaySize.y)
	love.graphics.rectangle("fill", displaySize.x - getDisplayOffsetX(), 0, getDisplayOffsetX(), displaySize.y)
end



function Game:mousepressed(x, y, button)
	if button == 1 then
		for widgetN, widget in pairs(self.widgets) do
			widget:click()
		end
		
		if self:levelExists() and mousePos.y < self.session.level.shooter.pos.y then self.session.level.shooter:shoot() end
	elseif button == 2 then
		if self:levelExists() and mousePos.y < self.session.level.shooter.pos.y then self.session.level.shooter:swapColors() end
	end
end

function Game:mousereleased(x, y, button)
	if button == 1 then
		for widgetN, widget in pairs(self.widgets) do
			widget:unclick()
		end
	end
end

function Game:keypressed(key)
	for widgetN, widget in pairs(self.widgets) do
		widget:keypressed(key)
	end
	-- shooter
	if self:levelExists() then
		local shooter = self.session.level.shooter
		if key == "left" then shooter.moveKeys.left = true end
		if key == "right" then shooter.moveKeys.right = true end
		if key == "up" then shooter:shoot() end
		if key == "down" then shooter:swapColors() end
	end
end

function Game:keyreleased(key)
	-- shooter
	if self:levelExists() then
		local shooter = self.session.level.shooter
		if key == "left" then shooter.moveKeys.left = false end
		if key == "right" then shooter.moveKeys.right = false end
	end
end

function Game:quit()
	if self:levelExists() then self.session.level:save() end
	self.runtimeManager:save()
end



function Game:playSound(name, pitch)
	self.resourceBank:getSound(self.config.general.soundEvents[name]):play(pitch)
end

function Game:stopSound(name)
	self.resourceBank:getSound(self.config.general.soundEvents[name]):stop()
end

function Game:getMusic(name)
	return self.resourceBank:getMusic(self.config.general.music[name])
end

function Game:spawnParticle(name, pos)
	return self.particleManager:spawnParticlePacket(name, pos)
end

function Game:addCallback(callbackType, event)
	if not self.widgetCallbacks[callbackType] then self.widgetCallbacks[callbackType] = {} end
	table.insert(self.widgetCallbacks[callbackType], event)
end

function Game:executeCallback(callbackType)
	self:executeEvents(self.widgetCallbacks[callbackType])
end

function Game:resetActive()
	for widgetN, widget in pairs(self.widgets) do
		widget:resetActive()
	end
end

function Game:setFullscreen(fullscreen)
	if fullscreen == love.window.getFullscreen() then return end
	if fullscreen then
		local _, _, flags = love.window.getMode()
		displaySize = Vec2(love.window.getDesktopDimensions(flags.display))
	else
		displaySize = NATIVE_RESOLUTION
	end
	love.window.setMode(displaySize.x, displaySize.y, {fullscreen = fullscreen, resizable = true})
end



function Game:getWidget(names)
	-- local s = ""
	-- for i, name in ipairs(names) do if i > 1 then s = s .. "/" .. name else s = s .. name end end
	-- print("Trying to get widget: " .. s)
	
	local widget = self.widgets[names[1]]
	for i, name in ipairs(names) do if i > 1 then
		widget = widget.children[name]
		if not widget then
			error("Could not find a widget: " .. strJoin(names, "/"))
		end
	end end
	return widget
end

function Game:parseUIScript(script)
	local s = strSplit(script, "\n")
	
	-- the current Widget we are editing
	local type = ""
	local widget = nil
	local widgetAction = nil
	
	for i, l in ipairs(s) do
		-- truncate the comment part
		l = strSplit(l, "//")[1]
		-- truncate leading whitespace
		while l:sub(1, 1) == " " or l:sub(1, 1) == "\t" do l = l:sub(2) end
		-- truncate trailing whitespace
		while l:sub(l:len(), l:len()) == " " or l:sub(l:len(), l:len()) == "\t" do l = l:sub(1, l:len() - 1) end
		-- omit empty lines and comments
		if l:len() > 0 then
			local t = strSplit(l, " ")
			if t[2] == "->" then
				-- new widget definition
				local t2 = strSplit(t[1], ".")
				widget = self:getWidget(strSplit(t2[1], "/"))
				widgetAction = t2[2]
				type = "action"
			elseif t[2] == ">>" then
				-- new widget definition
				widgetAction = t[1]
				type = "callback"
			else
				-- adding an event to the most recently defined widget
				local t2 = strSplit(l, ":")
				local event = self:prepareEvent(t2[1], strSplit(t2[2], ","))
				if type == "action" then
					widget:addAction(widgetAction, event)
				elseif type == "callback" then
					self:addCallback(widgetAction, event)
				end
			end
			--print(l)
		end
	end
end

function Game:prepareEvent(eventType, params)
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

function Game:parseCondition(s)
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

function Game:executeEvents(events)
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

function Game:executeEvent(event)
	-- main stuff
	if event.type == "print" then
		print(event.text)
	elseif event.type == "loadMain" then
		self:loadMain()
	elseif event.type == "sessionInit" then
		self:initSession()
	elseif event.type == "levelStart" then
		self.session:startLevel()
	elseif event.type == "levelBegin" then
		self.session.level:begin()
	elseif event.type == "levelBeginLoad" then
		self.session.level:beginLoad()
	elseif event.type == "levelPause" then
		self.session.level:setPause(true)
	elseif event.type == "levelUnpause" then
		self.session.level:setPause(false)
	elseif event.type == "levelRestart" then
		self.session.level:tryAgain()
	elseif event.type == "levelEnd" then
		self.session.level:unsave()
		self.session.level = nil
	elseif event.type == "levelWin" then
		self.session.level:win()
		self.session.level = nil
	elseif event.type == "levelSave" then
		self.session.level:save()
		self.session.level = nil
	elseif event.type == "quit" then
		love.event.quit()
	
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
		self:getMusic(event.music):setVolume(event.volume)
	
	-- profile stuff
	elseif event.type == "profileHighscoreWrite" then
		local success = self.runtimeManager.profile:writeHighscore()
		if success then
			self:executeCallback("profileHighscoreWriteSuccess")
		else
			self:executeCallback("profileHighscoreWriteFail")
		end
	
	-- options stuff
	elseif event.type == "optionsLoad" then
		-- TODO: HARDCODED - make it more flexible
		self:getWidget({"root", "Menu_Options", "Frame", "Slot_music", "Slider_Music"}).widget:setValue(self.runtimeManager.options:getMusicVolume())
		self:getWidget({"root", "Menu_Options", "Frame", "Slot_sfx", "Slider_Effects"}).widget:setValue(self.runtimeManager.options:getSoundVolume())
		self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Fullscreen"}).widget:setState(self.runtimeManager.options:getFullscreen())
		self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Mute"}).widget:setState(self.runtimeManager.options:getMute())
	elseif event.type == "optionsSave" then
		-- TODO: HARDCODED - make it more flexible
		self.runtimeManager.options:setMusicVolume(self:getWidget({"root", "Menu_Options", "Frame", "Slot_music", "Slider_Music"}).widget.value)
		self.runtimeManager.options:setSoundVolume(self:getWidget({"root", "Menu_Options", "Frame", "Slot_sfx", "Slider_Effects"}).widget.value)
		self.runtimeManager.options:setFullscreen(self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Fullscreen"}).widget.state)
		self.runtimeManager.options:setMute(self:getWidget({"root", "Menu_Options", "Frame", "Toggle_Mute"}).widget.state)
	end
end

function Game:checkCondition(condition)
	if condition.type == "widget" then
		if condition.property == "visible" then
			return self:getWidget(condition.widget):getVisible() == condition.value
		elseif condition.property == "buttonActive" then
			local w = self:getWidget(condition.widget)
			return (w:getVisible() and w.active and w.widget.enableForced) == condition.value
		end
	elseif condition.type == "level" then
		if condition.property == "paused" then
			return self.session.level.pause == condition.value
		elseif condition.property == "started" then
			return self.session.level.started == condition.value
		end
	end
end



return Game