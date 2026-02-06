local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")
local Profiler = require("src.Profiler")
local Console = require("src.Console")
local UIDebug = require("src.UITreeDebug")
local NetworkingTest = require("src.NetworkingTest.NetworkingTest")
local Expression = require("src.Expression")
local SphereSelectorResult = require("src.Game.SphereSelectorResult")

---@class Debug : Class
---@overload fun():Debug
local Debug = class:derive("Debug")

---Constructs a Debug class.
function Debug:new()
	self.console = Console()
	self.console:setFont(_FONT_CONSOLE)
	self.console:addCommand("t", "Adjusts the speed scale of the game. 1 = default.", {{name = "scale", type = "number"}}, self.commandSpeedScale, self)
	self.console:addCommand("n", "Destroys all spheres on the board.", {}, self.commandNukeSpheres, self)
	self.console:addCommand("test", "Spawns a test particle.", {{name = "particle", type = "ParticleEffect"}}, self.commandTest, self)
	self.console:addCommand("crash", "Crashes the game.", {}, self.commandCrash, self)
	self.console:addCommand("lose", "Loses the level.", {}, self.commandLose, self)
	self.console:addCommand("expr", "Evaluates an Expression.", {{name = "expression", type = "string", greedy = true}}, self.commandExpr, self)
	self.console:addCommand("exprt", "Breaks down an Expression and shows the list of RPN steps.", {{name = "expression", type = "string", greedy = true}}, self.commandExprt, self)
	self.console:addCommand("ex", "Debugs an Expression: shows detailed tokenization and list of RPN steps.", {{name = "expression", type = "string", greedy = true}}, self.commandEx, self)
	self.console:addCommand("collectible", "Spawns a Collectible in the middle of the screen.", {{name = "collectible", type = "Collectible"}, {name = "amount", type = "integer", optional = true}}, self.commandCollectible, self)
	self.console:addCommand("train", "Evaluates a train preset generator.", {{name = "preset", type = "string", greedy = true}}, self.commandTrain, self)
	-- Add commands to tinker with Expression Variables
	-- Add a list of Expression Variables in a debug screen
	-- Add a command to play any level
	-- Add a command to set objective values

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
	local s = ""

	s = s .. "ParticlePacket# = " .. tostring(_Game.particleManager:getParticlePacketCount()) .. "\n"
	s = s .. "ParticleSpawner# = " .. tostring(_Game.particleManager:getParticleSpawnerCount()) .. "\n"
	s = s .. "Particle# = " .. tostring(_Game.particleManager:getParticlePieceCount()) .. "\n"

	return s
end

function Debug:getDebugSession()
	local session = assert(_Game:getSession())
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
	local level = _Game.level
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
	local options = _Game.runtimeManager.options
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
	if _Game.level then
		s = s .. _Game.level.colorManager:getDebugText()
	end
	s = s .. "\n===== SESSION =====\n"
	if _Game.getSession and _Game:getSession() then
		s = s .. self:getDebugSession()
	end
	s = s .. "\n===== LEVEL =====\n"
	if _Game.level then
		s = s .. self:getDebugLevel()
	end
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
	if _Game.particleManager then
		s = s .. self:getDebugParticle()
	end
	s = s .. "\n===== OPTIONS =====\n"
	if _Game.runtimeManager then
		s = s .. self:getDebugOptions()
	end
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

	if _Game.level then
		for i, path in ipairs(_Game.level.map.paths) do
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



function Debug:commandSpeedScale(scale)
	_TimeScale = scale
	self:print("Time scale set to " .. scale)
end

function Debug:commandNukeSpheres()
	SphereSelectorResult({operations = {{type = "add", condition = Expression(true)}}}):destroy()
	self:print("Nuked!")
end

function Debug:commandTest(particle)
	-- TODO: Layer argument/debug layer?
	_Game:spawnParticle(particle, 100, 400, "MAIN")
end

function Debug:commandCrash()
	return "crash", self:getWitty()
end

function Debug:commandLose()
	_Game.level:lose()
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

function Debug:commandCollectible(collectible, amount)
	amount = amount or 1
	local w, h = _Game:getNativeResolution()
	for i = 1, amount do
		_Game.level:spawnCollectible(collectible, w / 2, h / 2)
	end
end

function Debug:commandTrain(preset)
	local result = preset
	if tonumber(preset:sub(1, 1)) then
		local blocks = {}
		-- Parse the preset generator into blocks.
		local strBlocks = _Utils.strSplit(preset, ",")
		for i, strBlock in ipairs(strBlocks) do
			local block = {pool = {}, size = 0} -- ex: {pool = {"X", "Y", "Z"}, size = 3}
			local spl = _Utils.strSplit(strBlock, ":")
			for j = 1, spl[2]:len() do
				table.insert(block.pool, spl[2]:sub(j, j))
			end
			spl = _Utils.strSplit(spl[1], "*")
			block.size = tonumber(spl[2])
			for j = 1, tonumber(spl[1]) do
				table.insert(blocks, block)
			end
		end
		-- Generate the preset from blocks.
		-- We need to make sure the same color (letter/key, colors are dispatched later) is not appearing in any two neighboring groups.
		--
		-- Key insights: (note that whenever "color" is said that actually means "key" in this context)
		-- - Group sizes can be disregarded altogether, because their neighborhood doesn't change at all no matter how big or small
		--    the groups are (we assume n>0).
		-- - All generators with only groups of colors>=3 are possible, because at any possible insertion point inside the built train
		--    there are at most 2 blocked colors, so for 3 or more colors there's always at least one good color which can be used.
		-- - All generators with groups of colors>=2 are possible, because at the beginning and end of the built train
		--    there's always exactly one blocked color, so the group can always pick the other one.
		-- - If there is at least one single color group, all generators are possible as long as there is no color for which the amount of
		--    single color groups is greater than N/2 rounded up, where N is the total number of groups.
		-- - If so, you could always place them next to each other and fill the gaps inside with a different color; this is also an exclusive
		--    condition for impossibility if we disregard blatant errors like groups of size = 0 or amount of colors = 0.
		-- - Because the groups which have 2 or more colors are always going to have at least two valid places (the edges) to be inserted,
		--    the generation should always start by picking a random single color group and only if none of them can be inserted at any
		--    position, then place one group of the next smallest number of colors.
		-- - Placing any of these groups will automatically enable at least one of the single color groups to be placed next to the previously
		--    inserted group regardless of that group's position, and if we run out of everything while still having single color groups left
		--    which cannot be dispatched, we've basically hit the impossibility condition.
		--    (we've started with a single, then we've dispatched all X multi-color groups, and as such another X single color groups,
		--    hence we've dispatched 2X+1 groups out of which X+1 were single color and only single color groups are left,
		--    and as such we've proven no valid combination is possible).
		local genBlocks = {} -- ex: {{key = "X", size = 3}, {key = "Y", size = 1}, ...}
		while #blocks > 0 do
			-- Each iteration = one inserted block (or crash if no valid combination is possible).
			-- Compose the block order and iterate through it here.
			-- #pool=1 blocks in random order, then #pool=2 blocks in random order, then #pool=3 blocks in random order, and so on.
			local blockPools = {} -- ex: {[1] = {<block>, <block>}, [3] = {<block>}, [7] = {<block>}}, where <block> is ex: {pool = {"X", "Y", "Z"}, size = 3}
			local blockPoolSizes = {}
			for i, block in ipairs(blocks) do
				if not blockPools[#block.pool] then
					blockPools[#block.pool] = {}
					table.insert(blockPoolSizes, #block.pool)
				end
				table.insert(blockPools[#block.pool], block)
			end
			-- Flatten the pools by shuffling all blocks within their pools and combining them together into one table with increasing pool size.
			local blocksIter = {} -- ex: {<block #pool=1>, <block #pool=1>, <block #pool=3>, <block #pool=7>, <block #pool=7>}
			for i, index in ipairs(blockPoolSizes) do
				local pool = blockPools[index]
				_Utils.tableShuffle(pool)
				for j, block in ipairs(pool) do
					table.insert(blocksIter, block)
				end
			end
			local success = false
			for i, block in ipairs(blocksIter) do
				local gapInfo = {}
				local validGaps = {}
				for j = 1, #genBlocks + 1 do
					-- For each position we can insert this group to, check which keys it can have.
					local prevBlock = genBlocks[j - 1]
					local nextBlock = genBlocks[j]
					local validKeys = _Utils.copyTable(block.pool)
					if prevBlock then
						_Utils.iTableRemoveValue(validKeys, prevBlock.key)
					end
					if nextBlock then
						_Utils.iTableRemoveValue(validKeys, nextBlock.key)
					end
					gapInfo[j] = validKeys
					if #validKeys > 0 then
						table.insert(validGaps, j)
					end
				end
				if #validGaps > 0 then
					-- Success! Roll the key out of valid ones, and add the block to the list.
					local index = validGaps[math.random(#validGaps)]
					local keys = gapInfo[index]
					local key = keys[math.random(#keys)]
					table.insert(genBlocks, index, {key = key, size = block.size})
					_Utils.iTableRemoveFirstValue(blocks, block)
					success = true
					break
				end
			end
			-- If `success` is `false`, we've exhausted all possibilities.
			assert(success, string.format("Level error: Impossible combination of blocks for the wave `%s`! If there is at least one possible combination without repeat keys next to each other, let me know!", preset))
		end
		-- Generate the string from blocks.
		result = ""
		for i, block in ipairs(genBlocks) do
			result = result .. block.key:rep(block.size)
		end
	end
	self:print(result)
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
