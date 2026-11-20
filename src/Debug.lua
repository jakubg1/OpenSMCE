local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")
local Profiler = require("src.Profiler")
local Console = require("src.Console")
local UIDebug = require("src.UITreeDebug")
local NetworkingTest = require("src.NetworkingTest.NetworkingTest")
local Expression = require("src.Expression")
local SphereSelectorResult = require("src.Game.SphereSelectorResult")
local SphereChain = require("src.Game.SphereChain")

---@class Debug : Class
---@overload fun():Debug
local Debug = class:derive("Debug")

---Constructs a Debug class.
function Debug:new()
	self.console = Console()
	self.console:setFont(_FONT_CONSOLE)

	-- Register global commands.
	self.console:addCommand("t", "Adjusts the speed scale of the game. 1 = default.", {{name = "scale", type = "number"}}, self.commandSpeedScale, self)
	self.console:addCommand("crash", "Crashes the game.", {}, self.commandCrash, self)
	self.console:addCommand("expr", "Evaluates an Expression.", {{name = "expression", type = "string", greedy = true}}, self.commandExpr, self)
	self.console:addCommand("exprt", "Breaks down an Expression and shows the list of RPN steps.", {{name = "expression", type = "string", greedy = true}}, self.commandExprt, self)
	self.console:addCommand("ex", "Debugs an Expression: shows detailed tokenization and list of RPN steps.", {{name = "expression", type = "string", greedy = true}}, self.commandEx, self)
	-- TODO: Add commands to tinker with Expression Variables
	-- TODO: Add a list of Expression Variables in a debug screen

	-- Register game-specific commands.
	self.console:addCommand("particle", "Spawns a Particle Effect at the cursor.", {{name = "particle", type = "ParticleEffect"}, {name = "layer", type = "Layer", optional = true}}, self.commandParticle, self)
	self.console:addCommand("clearparticles", "Clears all particles spawned by the `particle` command.", {}, self.commandClearParticles, self)
	self.console:addCommand("sound", "Plays a Sound Event at the cursor.", {{name = "soundEvent", type = "SoundEvent"}}, self.commandSound, self)
	self.console:addCommand("clearsounds", "Clears all sounds played by the `sound` command.", {}, self.commandClearSounds, self)
	self.console:addCommand("collectible", "Spawns a Collectible at the cursor.", {{name = "collectible", type = "Collectible"}, {name = "amount", type = "integer", optional = true}}, self.commandCollectible, self)
	self.console:addCommand("n", "Destroys all spheres on the board.", {}, self.commandNukeSpheres, self)
	self.console:addCommand("lose", "Loses the level.", {}, self.commandLose, self)
	self.console:addCommand("train", "Evaluates a train preset generator.", {{name = "preset", type = "string", greedy = true}}, self.commandTrain, self)
	-- TODO: Add a command to play any level
	-- TODO: Add a command to set objective values

	---Stores particles spawned by the `particle` command. Useful to clear them later.
	---@type ParticlePacket[]
	self.particles = {}
	---Stores sounds played by the `sound` command. Useful to clear them later.
	---@type SoundInstanceList[]
	self.sounds = {}

	-- Register network test commands.
	self.console:addCommand("nettest", "A suite of commands intended for testing the networking functionality.", {{name = "action", type = "string"}})
	self.console:addCommand("nettest host", "Hosts a session at the given IP address and port.", {{name = "ip", type = "string", optional = true}, {name = "port", type = "integer", optional = true}}, self.commandNetHost, self)
	self.console:addCommand("nettest join", "Connects to a session at the given IP address and port.", {{name = "ip", type = "string", optional = true}, {name = "port", type = "integer", optional = true}}, self.commandNetJoin, self)
	self.console:addCommand("nettest leave", "Ends a session or a connection, depending on whether this is a server or a client.", {}, self.commandNetLeave, self)
	self.console:addCommand("nettest name", "Sets a username of choice for this session.", {{name = "name", type = "string", greedy = true}}, self.commandNetName, self)
	self.console:addCommand("nettest send", "Sends a message which is visible for all connected players.", {{name = "message", type = "string", greedy = true}}, self.commandNetSend, self)
	self.console:addCommand("nettest list", "Shows the list of all players connected to the current session.", {}, self.commandNetList, self)
	self.netTest = NetworkingTest()

	self.uiDebug = UIDebug()

	self.profUpdate = Profiler("Update")
	self.profDraw = Profiler("Draw")
	self.profDrawLevel = Profiler("Draw: Level")
	self.prof3 = Profiler("Draw: Level2")
	self.profMusic = Profiler("Music volume")

	self.profTimer = Profiler("Timer cache")
	self.profTimer.w = 80
	self.profTimer.maxValue = 1/60
	self.profTimer.bars = {}
	for i = 0.000, 0.017, 0.002 do
		table.insert(self.profTimer.bars, {value = i, label = string.format("%.3f", i), color = {1, 1, 1}})
	end
	self.profTimer.recordCount = 100
	self.profTimer.showMinMaxAvg = false

	self.profVisible = false
	self.profPage = 1
	self.profPages = {self.profUpdate, self.profMusic, self.profDrawLevel, self.prof3}

	self.gameDebugVisible = false -- Switched by F3
	self.textDebugVisible = false -- Switched by F4
	self.fpsDebugVisible = false -- Switched by F5
	self.sphereDebugVisible = false -- Switched by F6

	self.uiWidgetCount = 0
	self.vec2PerFrame = 0
	self.lastVec2PerFrame = 0

	---@type string[]
	self.displayedDeprecationTraces = {}
end



---Updates the debug class.
---@param dt number Time delta in seconds.
function Debug:update(dt)
	self.console:update(dt)
	self.netTest:update(dt)
	self.lastVec2PerFrame = self.vec2PerFrame
	self.vec2PerFrame = 0

	if _Game.timer then
		self.profTimer:putValue(_Game.timer.time)
	end
end

---Draws the debug class, which includes the help overlay, profiler, console, UI debugging and all elements controlled with F* keys.
function Debug:draw()
	-- Profilers
	if self.profVisible then
		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(_FONT)
		local p1 = self.profPages[self.profPage]
		p1.x, p1.y = 0, _Display.h
		p1:draw()

		local pt = self.profTimer
		pt.x, pt.y = 310, _Display.h
		pt:draw()

		local p2 = self.profDraw
		p2.x, p2.y = 400, _Display.h
		p2:draw()

		self:drawVisibleText("Debug Keys:", 10, 10, 15)
		self:drawVisibleText({self.profVisible and _COLORS.green or _COLORS.white, "[F1] Performance"}, 10, 25, 15)
		self:drawVisibleText({self.uiDebug.visible and _COLORS.green or _COLORS.white, "[F2] UI Tree"}, 10, 40, 15)
		self:drawVisibleText({self.uiDebug.autoCollapseInvisible and _COLORS.green or _COLORS.white, "    [Ctrl+F2] Collapse all invisible UI Nodes"}, 10, 55, 15)
		self:drawVisibleText({self.gameDebugVisible and _COLORS.green or _COLORS.white, "[F3] Gameplay debug display"}, 10, 70, 15)
		self:drawVisibleText({self.textDebugVisible and _COLORS.green or _COLORS.white, "[F4] Debug text (FPS, level data, etc.)"}, 10, 85, 15)
		self:drawVisibleText({self.fpsDebugVisible and _COLORS.green or _COLORS.white, "[F5] FPS Counter"}, 10, 100, 15)
		self:drawVisibleText({self.sphereDebugVisible and _COLORS.green or _COLORS.white, "[F6] Sphere trains path overlay"}, 10, 115, 15)
	end

	-- Console
	self.console:draw()

	-- UI tree
	self.uiDebug:draw()

	-- Game and spheres
	if self.textDebugVisible then self:drawDebugInfo() end
	if self.fpsDebugVisible then self:drawFpsInfo() end
	if self.sphereDebugVisible then self:drawSphereInfo() end
end

function Debug:wheelmoved(x, y)
	self.console:wheelmoved(x, y)
	self.uiDebug:wheelmoved(x, y)
end

function Debug:keypressed(key)
	if not self.console.active then
		if key == "f1" then
			self.profVisible = not self.profVisible
		elseif key == "f3" then
			self.gameDebugVisible = not self.gameDebugVisible
			self:print({_COLORS.aqua, string.format("[Debug] Gameplay Debug: %s", self.gameDebugVisible and "ON" or "OFF")})
		elseif key == "f4" then
			self.textDebugVisible = not self.textDebugVisible
		elseif key == "f5" then
			self.fpsDebugVisible = not self.fpsDebugVisible
		elseif key == "f6" then
			self.sphereDebugVisible = not self.sphereDebugVisible
		elseif key == "f10" then
			self:deprecationNotice("test")
		end
		-- Change profiler page
		if key == "kp-" and self.profPage > 1 then
			self.profPage = self.profPage - 1
		end
		if key == "kp+" and self.profPage < #self.profPages then
			self.profPage = self.profPage + 1
		end
		self.uiDebug:keypressed(key)
	end

	self.console:keypressed(key)
end

function Debug:keyreleased(key)
	self.console:keyreleased(key)
end

function Debug:textinput(t)
	self.console:textinput(t)
end

function Debug:mousepressed(x, y, button)
	self.uiDebug:mousepressed(x, y, button)
end

function Debug:mousereleased(x, y, button)
	self.uiDebug:mousereleased(x, y, button)
end

---Handles disconnecting from the Networking Test if the game is closed.
function Debug:disconnect()
	self.netTest:disconnect()
end



---Prints a message to the console and also to the log.
---@param message any? The message to be sent. If it's not a string or a formatted string (table), `tostring` will be implicitly used first.
function Debug:print(message)
	self.console:print(message)
	_Log:printt("CONSOLE", _Utils.strUnformat(message))
end

---Prints an error message to the console and also to the log.
---Shorthand version for applying the red color.
---@param message string The message to be sent.
function Debug:printError(message)
	self.console:print({_COLORS.red, message})
	_Log:printt("CONSOLE", _Utils.strUnformat(message))
end

---Prints a deprecation notice to the ingame console.
---@param message string The message to be printed.
---@param depth integer? The message will contain one line in the traceback. This parameter determines how many jumps back in the traceback should be made. The function will never print more than one instance of the same line.
function Debug:deprecationNotice(message, depth)
	if not _Settings:getSetting("printDeprecationNotices") then
		return
	end
	depth = depth or 1
	local trace = _Utils.isolateTracebackLine(debug.traceback(), depth + 1)
	if _Utils.isValueInTable(self.displayedDeprecationTraces, trace) then
		return
	end
	table.insert(self.displayedDeprecationTraces, trace)
	self:print({_COLORS.aqua, "[Debug] ", _COLORS.red, "Deprecation Notice: ", _COLORS.purple, message})
	self:print({_COLORS.yellow, "        " .. trace})
end

function Debug:getDebugMain()
	local s = ""

	s = s .. "Version = " .. _VERSION .. "\n"
	s = s .. "Game = " .. tostring(_Game.name) .. "\n"
	s = s .. "FPS = " .. tostring(love.timer.getFPS()) .. "\n"
	s = s .. "Drawcalls = " .. tostring(love.graphics.getStats().drawcalls) .. "\n"
	s = s .. "DrawcallsSaved = " .. tostring(love.graphics.getStats().drawcallsbatched) .. "\n"
	s = s .. "UIWidgetCount = " .. tostring(self.uiWidgetCount) .. "\n"
	s = s .. "Vec2PerFrame = " .. tostring(self.lastVec2PerFrame) .. "\n"
	s = s .. "DrawPerFrame = " .. tostring(_Renderer:getLastQueueLength()) .. "\n"

	return s
end

function Debug:getDebugParticle()
	local particleManager = _Game.particleManager
	if not particleManager then
		return ""
	end
	local s = ""

	s = s .. "ParticlePacket# = " .. tostring(particleManager:getParticlePacketCount()) .. "\n"
	s = s .. "ParticleSpawner# = " .. tostring(particleManager:getParticleSpawnerCount()) .. "\n"
	s = s .. "Particle# = " .. tostring(particleManager:getParticlePieceCount()) .. "\n"

	return s
end

function Debug:getDebugSession()
	local session = _Game.game:getSession()
	if not session then
		return ""
	end
	local s = ""

	s = s .. string.format("Level: Level = %s, Sublevel = %s, Total = %s", session:getLevel(), session:getSublevel(), session:getTotalLevel()) .. "\n"
	s = s .. "LevelID = " .. session:getLevelID() .. "\n"
	s = s .. "LatestCheckpoint = " .. tostring(session:getLatestCheckpoint()) .. "\n"
	s = s .. "CheckpointUpcoming = " .. tostring(session:isCheckpointUpcoming()) .. "\n"
	s = s .. string.format("Rollback: Score = %s, Coins = %s", session.rollbackScore, session.rollbackCoins) .. "\n"
	local levelStats = session:getCurrentLevelStats()
	if levelStats then
		s = s .. "LevelRecord = " .. levelStats.score .. "\n"
		s = s .. "Won = " .. levelStats.won .. "\n"
		s = s .. "Lost = " .. levelStats.lost .. "\n"
	end

	return s
end

function Debug:getDebugLevel()
	local level = _Game.game:getLevel()
	if not level then
		return ""
	end
	local s = ""

	s = s .. "LevelScore = " .. tostring(level.score) .. "\n"
	s = s .. string.format("Accuracy = %s / %s (%.0d%%)", level.successfulShots, level.spheresShot, level:getShotAccuracy() * 100) .. "\n"
	s = s .. "LevelSequenceStep = " .. tostring(level.levelSequenceStep) .. "\n"
	s = s .. "Objectives:\n"
	for i, objective in ipairs(level.objectives) do
		s = s .. string.format("  %s: %s %s/%s", i, objective.type, objective.progress, objective.target) .. "\n"
	end
	s = s .. "Variables:\n"
	for name, variable in pairs(level.variables) do
		s = s .. string.format("  - %s = %s", name, variable) .. "\n"
	end
	s = s .. "Timers:\n"
	for name, timer in pairs(level.timers) do
		s = s .. string.format("  - %s = %.2f", name, timer) .. "\n"
	end
	s = s .. "Timer Series:\n"
	for name, timerSeries in pairs(level.timerSeries) do
		s = s .. string.format("  - %s = ", name)
		if #timerSeries == 0 then
			s = s .. "(empty)\n"
		else
			for i, time in ipairs(timerSeries) do
				if i > 1 then
					s = s .. ", "
				end
				s = s .. string.format("%.2f", time)
			end
			s = s .. "\n"
		end
	end
	s = s .. "\n"
	s = s .. string.format("Collectible# = %s (rains=%s)", #level.collectibles, #level.collectibleRains) .. "\n"
	s = s .. string.format("Projectile# = %s (storms=%s)", #level.projectiles, #level.projectileStorms) .. "\n"
	s = s .. "FloatingText# = " .. tostring(#level.floatingTexts) .. "\n"
	s = s .. "ShotSphere# = " .. tostring(#level.shotSpheres) .. "\n"

	return s
end

function Debug:getDebugOptions()
	local options = _Game.game and _Game.game.options
	if not options then
		return ""
	end
	local s = ""

	s = s .. "EffMusicVolume = " .. tostring(options:getEffectiveMusicVolume()) .. "\n"
	s = s .. "EffSoundVolume = " .. tostring(options:getEffectiveSoundVolume()) .. "\n"

	return s
end

function Debug:getDebugInfo()
	local s = ""

	s = s .. "===== MAIN =====\n"
	s = s .. self:getDebugMain()
	s = s .. "\n===== COLOR MANAGER =====\n"
	if _Game.game and _Game.game:getLevel() then
		s = s .. _Game.game:getLevel().colorManager:getDebugText()
	end
	s = s .. "\n===== SESSION =====\n"
	s = s .. self:getDebugSession()
	s = s .. "\n===== LEVEL =====\n"
	s = s .. self:getDebugLevel()
	s = s .. "\n===== VARIABLES =====\n"
	s = s .. _Vars:getDebugText()

	-- table.insert(s, "")
	-- table.insert(s, "===== EXTRA =====")
	-- if game.widgets.root then
		-- local a = game:getWidget({"root", "Game", "Hud"}).actions
		-- for k, v in pairs(a) do
			-- table.insert(s, k .. " -> ")
			-- for k2, v2 in pairs(v) do
				-- local n = "    " .. k2 .. " = {"
				-- for k3, v3 in pairs(v2) do
					-- n = n .. k3 .. ":" .. tostring(v3) .. ", "
				-- end
				-- n = n .. "}"
				-- table.insert(s, n)
			-- end
		-- end
	-- end

	return s
end

function Debug:getRightDebugInfo()
	local s = ""
	s = s .. "\n===== PARTICLE =====\n"
	s = s .. self:getDebugParticle()
	s = s .. "\n===== OPTIONS =====\n"
	s = s .. self:getDebugOptions()
	return s
end



---Draws a text with a semi-transparent background.
---@param text string|table The text to be drawn.
---@param x number The X position of the text.
---@param y number The Y position of the text.
---@param height number The box height, in pixels.
---@param width number? The box width, in pixels. Defaults to the text width.
---@param alpha number? The semitransparency parameter.
---@param shadow boolean? If set, the text will have a shadow drawn for extra visibility.
---@param backgroundColor table? The background color, black by default.
---@param rightAlign boolean? If set, the text will grow to the left.
function Debug:drawVisibleText(text, x, y, height, width, alpha, shadow, backgroundColor, rightAlign)
	if text == "" then
		return
	end

	width = width or love.graphics.getFont():getWidth(_Utils.strUnformat(text))
	alpha = alpha or 1
	backgroundColor = backgroundColor or _COLORS.black
	if rightAlign then
		x = x - width
	end

	love.graphics.setColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], 0.7 * alpha)
	love.graphics.rectangle("fill", x - 3, y, width + 6, height)
	if shadow then
		love.graphics.setColor(0, 0, 0, alpha)
		love.graphics.print(text, x + 2, y + 2)
	end
	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.print(text, x, y)
end

function Debug:drawDebugInfo()
	love.graphics.setFont(_FONT)
	-- Debug screen
	local leftLines = _Utils.strSplit(self:getDebugInfo(), "\n")
	for i, l in ipairs(leftLines) do
		self:drawVisibleText(l, 0, 15 * (i - 1), 15)
	end

	local rightLines = _Utils.strSplit(self:getRightDebugInfo(), "\n")
	for i, l in ipairs(rightLines) do
		self:drawVisibleText(l, _Display.w, 15 * (i - 1), 15, nil, nil, nil, nil, true)
	end
end

function Debug:drawFpsInfo()
	love.graphics.setFont(_FONT)
	local s = "FPS = " .. tostring(love.timer.getFPS())

	self:drawVisibleText(s, 0, 0, 15, 65)
end



function Debug:drawSphereInfo()
	love.graphics.setFont(_FONT)
	local p = Vec2(0, _Display.h - 200)
	local s = Vec2(_Display.w, 200)

	-- background
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.rectangle("fill", p.x, p.y, s.x, s.y)

	local y = 0
	local x = 0

	if _Game.game.level then
		for i, path in ipairs(_Game.game.level.map.paths) do
			love.graphics.setColor(1, 1, 1)
			love.graphics.print("Path " .. tostring(i), p.x + 10, p.y + 10 + y)
			y = y + 25
			for j, sphereChain in ipairs(path.sphereChains) do
				love.graphics.setColor(1, 1, 1)
				love.graphics.print(tostring(j), p.x + 20, p.y + 10 + y)
				local lastSphereGroup = sphereChain:getLastSphereGroup()
				if lastSphereGroup then
					love.graphics.print(tostring(math.floor(sphereChain:getLastSphereGroup().offset)) .. "px", p.x + 50, p.y + 10 + y)
					x = 0
					for k = #sphereChain.sphereGroups, 1, -1 do -- reverse iteration
						local sphereGroup = sphereChain.sphereGroups[k]
						for l, sphere in ipairs(sphereGroup.spheres) do
							-- Draw a sphere.
							local color = sphere:getConfig().color
							local alpha = sphere:isGhost() and 0.5 or 1
							if color and type(color) == "table" then
								love.graphics.setColor(color.r, color.g, color.b, alpha)
							else
								love.graphics.setColor(0.5, 0.5, 0.5, alpha)
							end
							love.graphics.circle("fill", p.x + 120 + x, p.y + 20 + y, 10)
							if sphere.delQueue then
								love.graphics.setLineWidth(3)
								love.graphics.setColor(1, 0, 0)
								love.graphics.circle("line", p.x + 120 + x, p.y + 20 + y, 10)
							end
							-- Sphere ID
							love.graphics.setColor(1, 1, 1)
							love.graphics.print(tostring(sphereGroup:getSphereID(sphere)), p.x + 110 + x, p.y + 30 + y)
							-- Broken link arrows
							if sphere.prevSphere ~= sphereGroup.spheres[l - 1] then
								love.graphics.print("E<", p.x + 110 + x, p.y + 40 + y)
							end
							if sphere.nextSphere ~= sphereGroup.spheres[l + 1] then
								love.graphics.print("E>", p.x + 110 + x, p.y + 40 + y)
							end
							x = x + 20
						end
						-- Draw error arrows if the next/previous group pointers are incorrect.
						love.graphics.setColor(1, 0, 0)
						love.graphics.setLineWidth(2)
						if sphereGroup.nextGroup ~= sphereChain.sphereGroups[k - 1] then
							-- Left arrow
							love.graphics.line(p.x + 120 + x, p.y + 15 + y, p.x + 200 + x, p.y + 15 + y)
							love.graphics.line(p.x + 120 + x, p.y + 15 + y, p.x + 140 + x, p.y + 10 + y)
							love.graphics.line(p.x + 120 + x, p.y + 15 + y, p.x + 140 + x, p.y + 20 + y)
						end
						if sphereGroup.prevGroup ~= sphereChain.sphereGroups[k + 1] then
							-- Right arrow
							love.graphics.line(p.x + 120 + x, p.y + 25 + y, p.x + 200 + x, p.y + 25 + y)
							love.graphics.line(p.x + 200 + x, p.y + 25 + y, p.x + 180 + x, p.y + 20 + y)
							love.graphics.line(p.x + 200 + x, p.y + 25 + y, p.x + 180 + x, p.y + 30 + y)
						end
						if sphereGroup.nextGroup then
							-- Draw distance between groups.
							local text = tostring(math.floor(sphereGroup.nextGroup:getBackOffset() - sphereGroup:getFrontOffset())) .. "px"
							love.graphics.setColor(1, 1, 1)
							love.graphics.print(text, p.x + 150 + x, p.y + 10 + y)
						end
						--if k > 1 and sphereChain.sphereGroups[k - 1] ~= sphereGroup.nextGroup then print("ERROR") end
						--if k < #sphereChain.sphereGroups and sphereChain.sphereGroups[k + 1] ~= sphereGroup.prevGroup then print("ERROR") end

						x = x + 100
					end
					if j > 1 then
						-- Draw distance between chains.
						local a = sphereChain:getPreviousChain():getLastSphereGroup():getBackOffset()
						local b = sphereChain:getFirstSphereGroup():getFrontOffset()
						love.graphics.setColor(1, 1, 1)
						love.graphics.print(tostring(math.floor(a - b)) .. "px", p.x + 20, p.y + y)
					end
				else
					love.graphics.setColor(1, 0, 0)
					love.graphics.print("ERROR", p.x + 50, p.y + 10 + y)
				end

				y = y + 35
			end
		end
	else
		love.graphics.setColor(1, 1, 1)
		love.graphics.print("No level available!", p.x, p.y)
	end
end

-- Builtin commands

function Debug:commandSpeedScale(scale)
	_TimeScale = scale
	self:print("Time scale set to " .. scale)
end

function Debug:commandCrash()
	return "crash", self:getWitty()
end

function Debug:commandExpr(expression)
	local e = Expression(expression, true)
	self:print(string.format("expr(%s): %s", expression, e:evaluate()))
end

function Debug:commandExprt(expression)
	local e = Expression(expression, true)
	for i, step in ipairs(e.data) do
		_Log:printt("Debug", string.format("%s   %s", step.type, step.value))
	end
	self:print(string.format("exprt(%s): %s", expression, e:getDebug()))
end

function Debug:commandEx(expression)
	local e = Expression("2", true)
	self:print(string.format("ex(%s):", expression))
	local tokens = e:tokenize(expression)
	for i, token in ipairs(tokens) do
		self:print(string.format("%s   %s", token.value, token.type))
	end
	self:print("")
	self:print("")
	self:print("Compilation result:")
	e.data = e:compile(tokens)
	for i, step in ipairs(e.data) do
		self:print(string.format("%s   %s", step.type, step.value))
	end
	self:print(string.format("ex(%s): %s", expression, e:evaluate()))
end

-- Gameplay commands

---Spawns a particle effect at the mouse cursor.
---@param particle ParticleEffectConfig The particle effect to be spawned.
---@param layer string? Layer name, defaults to `"MAIN"`.
function Debug:commandParticle(particle, layer)
	local effect = _Game:spawnParticle(particle, _MouseX, _MouseY, layer or "MAIN")
	table.insert(self.particles, effect)
	self:print(string.format("Spawned particle effect `%s`", particle._path))
end

---Clears all particles spawned with `:commandParticle()`.
function Debug:commandClearParticles()
	local n = #self.particles
	if n == 0 then
		self:printError("There are no particles to clear")
		return
	end
	for i, effect in ipairs(self.particles) do
		effect:destroy(true)
	end
	_Utils.emptyTable(self.particles)
	self:print(string.format("Cleared %s particles", n))
end

---Plays a sound event at the mouse cursor.
---@param soundEvent SoundEvent The sound event to be played.
function Debug:commandSound(soundEvent)
	local sound = soundEvent:play(_MouseX, _MouseY)
	table.insert(self.sounds, sound)
	if sound then
		self:print(string.format("Played sound `%s`", soundEvent.path))
	else
		self:printError("Could not play the specified sound")
	end
end

---Clears all sounds played with `:commandSound()`.
function Debug:commandClearSounds()
	local n = #self.sounds
	if n == 0 then
		self:printError("There are no sounds to clear")
		return
	end
	for i, sound in ipairs(self.sounds) do
		sound:stop()
	end
	_Utils.emptyTable(self.sounds)
	self:print(string.format("Cleared %s sounds", n))
end

---Spawns one or multiple collectibles of the specified type.
---@param collectible CollectibleConfig The collectible to be spawned.
---@param amount integer? The amount of collectibles to be spawned.
function Debug:commandCollectible(collectible, amount)
	amount = amount or 1
	for i = 1, amount do
		_Game.game:getLevel():spawnCollectible(collectible, _MouseX, _MouseY)
	end
	self:print(string.format("Spawned %s collectible(s) of type `%s`", amount, collectible._path))
end

function Debug:commandNukeSpheres()
	SphereSelectorResult({operations = {{type = "add", condition = Expression(true)}}}):destroy()
	self:print("Nuked!")
end

function Debug:commandLose()
	_Game.game:getLevel():lose()
end

---Handles the `train` command.
---@param preset string The train preset to be evaluated.
function Debug:commandTrain(preset)
	self:print(SphereChain.generateTrainPreset(preset))
end

-- Network test commands

---Handles the `nettest host` command.
---@param ip string The IP at which the server will be hosted.
---@param port integer The port on which the server will listen to packets.
function Debug:commandNetHost(ip, port)
	self.netTest:host(ip, port)
end

---Handles the `nettest join` command.
---@param ip string The IP of the server to connect to.
---@param port integer The port on which the server is listening to.
function Debug:commandNetJoin(ip, port)
	self.netTest:join(ip, port)
end

---Handles the `nettest leave` command.
function Debug:commandNetLeave()
	self.netTest:leave()
end

---Handles the `nettest name` command.
---@param name string The new username to be used.
function Debug:commandNetName(name)
	self.netTest:setName(name)
end

---Handles the `nettest send` command.
---@param message string The message to be sent to all clients of the party.
function Debug:commandNetSend(message)
	self.netTest:send(message)
end

---Handles the `nettest list` command.
function Debug:commandNetList()
	self.netTest:list()
end



function Debug:profUpdateStart()
	self.profUpdate:start()
end

function Debug:profUpdateStop()
	self.profUpdate:stop()
end

function Debug:profDrawStart()
	self.profDraw:start()
end

function Debug:profDrawCheckpoint()
	self.profDraw:checkpoint()
end

function Debug:profDrawStop()
	self.profDraw:stop()
end

function Debug:profDrawLevelStart()
	self.profDrawLevel:start()
end

function Debug:profDrawLevelCheckpoint(n)
	self.profDrawLevel:checkpoint(n)
end

function Debug:profDrawLevelStop()
	self.profDrawLevel:stop()
end



---Returns a random line from the file `assets/eggs_crash.txt`, or a hardcoded message if the file does not exist.
---@return string
function Debug:getWitty()
	local witties = _Utils.loadFile("assets/eggs_crash.txt")
	if not witties then
		return "No witty message available :( ...Maybe that's for the better good?"
	end
	local wittiesSpl = _Utils.strSplit(witties, "\n")
	return wittiesSpl[math.random(#wittiesSpl)]
end



return Debug
