local class = require "com/class"
local Game = class:derive("Game")

local strmethods = require("src/strmethods")

local Vec2 = require("src/Essentials/Vector2")

local Timer = require("src/Timer")

local ConfigManager = require("src/ConfigManager")
local ResourceManager = require("src/ResourceManager")
local GameModuleManager = require("src/GameModuleManager")
local RuntimeManager = require("src/RuntimeManager")
local Session = require("src/Session")

local UIManager = require("src/UI/Manager")
local ParticleManager = require("src/Particle/Manager")

function Game:new(name)
	self.name = name

	self.hasFocus = false

	self.configManager = nil
	self.resourceManager = nil
	self.gameModuleManager = nil
	self.runtimeManager = nil
	self.session = nil

	self.uiManager = nil
	self.particleManager = nil


	-- revert to original font size
	love.graphics.setFont(love.graphics.newFont())
end

function Game:init()
	print("Selected game: " .. self.name)

	-- Step 1. Load the config
	self.configManager = ConfigManager()

	-- Step 2. Initialize the window
	love.window.setTitle(self.configManager.config.general.windowTitle or ("OpenSMCE [" .. VERSION .. "] - " .. self.name))
	love.window.setMode(self.configManager.config.general.nativeResolution.x, self.configManager.config.general.nativeResolution.y, {resizable = true})

	-- Step 3. Initialize RNG and timer
	self.timer = Timer()
	math.randomseed(os.time())

	-- Step 4. Create a resource bank
	self.resourceManager = ResourceManager()

	-- Step 5. Load initial resources (enough to start up the splash screen)
	self.resourceManager:loadList(self.configManager.loadList)

	-- Step 6. Load game modules
	self.gameModuleManager = GameModuleManager()

	-- Step 7. Create a runtime manager
	self.runtimeManager = RuntimeManager()
	self.satMode = self.runtimeManager.profile.data.session and self.runtimeManager.profile.data.session.ultimatelySatisfyingMode

	-- Step 8. Set up the UI Manager
	self.uiManager = UIManager()
	self.uiManager:initSplash()
end

function Game:loadMain()
	-- Loads all game resources
	self.resourceManager:stepLoadList(self.configManager.resourceList)
end

function Game:initSession()
	-- Setup the UI and particles
	self.uiManager:init()
	self.particleManager = ParticleManager()

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
	self.resourceManager:update(dt)

	if self:sessionExists() then
		self.session:update(dt)
	end

	self.uiManager:update(dt)

	if self.particleManager then self.particleManager:update(dt) end

	-- Discord Rich Presence
	local p = self.runtimeManager.profile
	local line1 = "Playing: " .. self.name
	local line2 = ""
	if self:levelExists() then
		local l = self.session.level
		line2 = string.format("Level %s (%s), Score: %s, Lives: %s",
			p:getCurrentLevelConfig().name,
			l.won and "Complete!" or string.format("%s%%", math.floor((l.destroyedSpheres / l.target) * 100)),
			p:getScore(),
			p:getLives()
		)
		if l.pause then
			line1 = line1 .. " - Paused"
		end
	elseif p:getSession() then
		line2 = string.format("In menus, Score: %s, Lives: %s",
			p:getScore(),
			p:getLives()
		)
	else
		line2 = string.format("In menus")
	end
	discordRPC:setStatus(line1, line2)
end

function Game:sessionExists()
	return self.session
end

function Game:levelExists()
	return self.session and self.session.level
end



function Game:draw()
	dbg:profDraw2Start()

	-- Session and level
	if self:sessionExists() then
		self.session:draw()
	end
	dbg:profDraw2Checkpoint()

	-- Particles and UI
	if self.particleManager then self.particleManager:draw() end
	self.uiManager:draw()
	dbg:profDraw2Checkpoint()

	-- Borders
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", 0, 0, getDisplayOffsetX(), displaySize.y)
	love.graphics.rectangle("fill", displaySize.x - getDisplayOffsetX(), 0, getDisplayOffsetX(), displaySize.y)
	dbg:profDraw2Stop()
end



function Game:mousepressed(x, y, button)
	self.uiManager:mousepressed(x, y, button)

	if self:levelExists() and mousePos.y < self.session.level.shooter.pos.y then
		if button == 1 then
			self.session.level.shooter:shoot()
		elseif button == 2 then
			self.session.level.shooter:swapColors()
		end
	end
end

function Game:mousereleased(x, y, button)
	self.uiManager:mousereleased(x, y, button)
end

function Game:keypressed(key)
	self.uiManager:keypressed(key)
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

function Game:save()
	if self:levelExists() then self.session.level:save() end
	self.runtimeManager:save()
end



function Game:playSound(name, pitch, pos)
	local soundEvent = self.configManager.config.general.soundEvents[name]
	return self.resourceManager:getSound(soundEvent.sound):play(pitch, pos, soundEvent.loop)
end

function Game:stopSound(name)
	local soundEvent = self.configManager.config.general.soundEvents[name]
	self.resourceManager:getSound(soundEvent.sound):stop()
end

function Game:getMusic(name)
	return self.resourceManager:getMusic(self.configManager.config.general.music[name])
end

function Game:spawnParticle(name, pos)
	return self.particleManager:spawnParticlePacket(name, pos)
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

function Game:quit()
	self:save()
	self.resourceManager:unload()
	if engineSettings:getBackToBoot() then
		love.window.setMode(800, 600) -- reset window size
		loadBootScreen()
	else
		love.event.quit()
	end
end



return Game
