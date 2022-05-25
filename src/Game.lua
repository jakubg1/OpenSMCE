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
	local res = self.configManager.config.native_resolution
	love.window.setMode(res.x, res.y, {resizable = true})
	love.window.setTitle(self.configManager:getWindowTitle())

	-- Step 3. Initialize RNG and timer
	self.timer = Timer()
	local _ = math.randomseed(os.time())

	-- Step 4. Create a resource bank
	self.resourceManager = ResourceManager()

	-- Step 5. Load initial resources (enough to start up the splash screen)
	self.resourceManager:loadList(self.configManager.loadList)

	-- Step 6. Load game modules
	self.gameModuleManager = GameModuleManager()

	-- Step 7. Create a runtime manager
	self.runtimeManager = RuntimeManager()
	local p = self:getCurrentProfile()
	self.satMode = p and p.ultimatelySatisfyingMode

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
		self:tick(self.timer.FRAME_LENGTH)
	end
end

function Game:tick(dt) -- always with 1/60 seconds
	self.resourceManager:update(dt)

	if self:sessionExists() then
		self.session:update(dt)
	end

	self.uiManager:update(dt)

	if self.particleManager then
		self.particleManager:update(dt)
	end

	if self.configManager.config.rich_presence.enabled then
		self:updateRichPresence()
	end
end

function Game:updateRichPresence()
	local p = self:getCurrentProfile()
	local line1 = "Playing: " .. self.configManager:getGameName()
	local line2 = ""

	if self:levelExists() then
		local l = self.session.level
		line2 = string.format("Level %s (%s), Score: %s, Lives: %s",
			p:getLevelData().name,
			l.won and "Complete!" or string.format("%s%%", math.floor((l.destroyedSpheres / l.target) * 100)),
			p:getScore(),
			p:getLives()
		)
		if l.pause then
			line1 = line1 .. " - Paused"
		end
	elseif p and p:getSession() then
		line2 = string.format("In menus, Score: %s, Lives: %s", p:getScore(), p:getLives())
	else
		line2 = string.format("In menus")
	end

	_DiscordRPC:setStatus(line1, line2)
end

function Game:sessionExists()
	return self.session
end

function Game:levelExists()
	return self.session and self.session.level
end



function Game:draw()
	_Debug:profDraw2Start()

	-- Session and level
	if self:sessionExists() then
		self.session:draw()
	end
	_Debug:profDraw2Checkpoint()

	-- Particles and UI
	if self.particleManager then self.particleManager:draw() end
	self.uiManager:draw()
	_Debug:profDraw2Checkpoint()

	-- Borders
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", 0, 0, _GetDisplayOffsetX(), _DisplaySize.y)
	love.graphics.rectangle("fill", _DisplaySize.x - _GetDisplayOffsetX(), 0, _GetDisplayOffsetX(), _DisplaySize.y)
	_Debug:profDraw2Stop()
end



function Game:mousepressed(x, y, button)
	self.uiManager:mousepressed(x, y, button)

	if self:levelExists() and _MousePos.y < self.session.level.shooter.pos.y then
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

function Game:textinput(t)
	self.uiManager:textinput(t)
end

function Game:save()
	if self:levelExists() then self.session.level:save() end
	self.runtimeManager:save()
end



function Game:playSound(name, pitch, pos)
	return self.resourceManager:getSoundEvent(name):play(pitch, pos)
end

function Game:getMusic(name)
	return self.resourceManager:getMusic(self.configManager.music[name])
end

function Game:getCurrentProfile()
	return self.runtimeManager.profileManager:getCurrentProfile()
end

function Game:spawnParticle(name, pos)
	return self.particleManager:spawnParticlePacket(name, pos)
end

function Game:setFullscreen(fullscreen)
	if fullscreen == love.window.getFullscreen() then return end
	if fullscreen then
		local _, _, flags = love.window.getMode()
		_DisplaySize = Vec2(love.window.getDesktopDimensions(flags.display))
	else
		_DisplaySize = _NATIVE_RESOLUTION
	end
	love.window.setMode(_DisplaySize.x, _DisplaySize.y, {fullscreen = fullscreen, resizable = true})
end

function Game:quit(forced)
	self:save()
	self.resourceManager:unload()
	if _EngineSettings:getBackToBoot() and not forced then
		love.window.setMode(800, 600) -- reset window size
		_LoadBootScreen()
	else
		love.event.quit()
	end
end



return Game
