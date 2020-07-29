local class = require "class"
local Game = class:derive("Game")

local Vec2 = require("Essentials/Vector2")

local Timer = require("Timer")

local ResourceBank = require("ResourceBank")
local Session = require("Session")

local UIWidget = require("UI/Widget")
local ParticleManager = require("Particle/Manager")
local Sprite = require("Sprite")

function Game:new(name)
	self.name = name
	
	self.resourceBank = nil
	self.session = nil
	
	self.widgets = {splash = nil, main = nil}
	self.widgetVariables = {}
	
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
	
	-- Step 6. Set up the splash widget
	self.widgets.splash = UIWidget("Splash", loadJson(parsePath("ui/splash.json")))
	self.widgets.splash:show()
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
	self.widgets.main = UIWidget("Main", loadJson(parsePath("ui/hud.json")))
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
	if self:sessionExists() then
		self.session:draw()
		
		self.widgetVariables.lives = self.session.profile:getLives()
		self.widgetVariables.coins = self.session.profile:getCoins()
		self.widgetVariables.score = numStr(self.session.scoreDisplay)
		self.widgetVariables.player = self.session.profile.name
		for i, entry in ipairs(self.session.highscores.entries) do
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
	
	for i, layer in ipairs(self.config.hudLayerOrder) do
		for widgetN, widget in pairs(self.widgets) do
			widget:draw(layer, self.widgetVariables)
		end
	end
	
	if self.particleManager then self.particleManager:draw() end
	
	if gameDebugVisible then self:drawDebugInfo() end
end

function Game:drawDebugInfo()
	if self:levelExists() then
		-- Debug screen
		local p = posOnScreen(Vec2())
		
		local s = ""
		s = s .. "LevelScore = " .. tostring(self.session.level.score) .. "\n"
		if self.session.profile:getCurrentLevel() then
			s = s .. "LevelRecord = " .. tostring(self.session.profile:getCurrentLevel().score) .. "\n"
		else
			s = s .. "LevelRecord = ---\n"
		end
		s = s .. "ParticleSpawner# = " .. tostring(self.particleManager:getParticleSpawnerCount()) .. "\n"
		s = s .. "Particle# = " .. tostring(self.particleManager:getParticlePieceCount()) .. "\n"
		if self:sessionExists() then
			s = s .. "SphereColors:" .. "\n"
			for i = 1, 9 do
				s = s .. tostring(i) .. " -> " .. self.session.sphereColorCounts[i] .. ", " .. self.session.dangerSphereColorCounts[i] .. "\n"
			end
		end
		
		love.graphics.setColor(1, 1, 1)
		love.graphics.print(s, p.x, p.y)
	end
end



function Game:mousepressed(x, y, button)
	if button == 1 then
		for widgetN, widget in pairs(self.widgets) do
			widget:click()
		end
		
		if self:levelExists() then self.session.level.shooter:shoot() end
	elseif button == 2 then
		if self:levelExists() then self.session.level.shooter:swapColors() end
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
	-- pause
	if key == "space" and self:levelExists() then self.session.level:togglePause() end
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
	self.particleManager:useSpawnerData(name, pos)
end

function Game:getWidget(names)
	local widget = self.widgets[names[1]]
	for i, name in ipairs(names) do if i > 1 then widget = widget.children[name] end end
	return widget
end



return Game