local class = require "com.class"

---@class Debug
---@overload fun():Debug
local Debug = class:derive("Debug")

local Vec2 = require("src.Essentials.Vector2")

local Profiler = require("src.Profiler")
local Console = require("src.Console")
local UIDebug = require("src.UITreeDebug")

local Expression = require("src.Expression")
local SphereSelectorResult = require("src.Game.SphereSelectorResult")



---Constructs a Debug class.
function Debug:new()
	self.console = Console()
	self.uiDebug = UIDebug()

	self.commands = {
		t = {description = "Adjusts the speed scale of the game. 1 = default.", parameters = {{name = "scale", type = "number", optional = false}}},
		e = {description = "Toggles the Background Cheat Mode. Spheres render over tunnels.", parameters = {}},
		n = {description = "Destroys all spheres on the board.", parameters = {}},
		ppp = {description = "Spawns a Scorpion.", parameters = {}},
		ls = {description = "Spawns a Lightning Storm.", parameters = {}},
		net = {description = "Spawns a Net.", parameters = {}},
		test = {description = "Spawns a test particle.", parameters = {}},
		crash = {description = "Crashes the game.", parameters = {}},
		expr = {description = "Evaluates an Expression.", parameters = {{name = "expression", type = "string", optional = false, greedy = true}}},
		exprt = {description = "Breaks down an Expression and shows the list of RPN steps.", parameters = {{name = "expression", type = "string", optional = false, greedy = true}}},
		ex = {description = "Debugs an Expression: shows detailed tokenization and list of RPN steps.", parameters = {{name = "expression", type = "string", optional = false, greedy = true}}},
		help = {description = "Displays this list.", parameters = {}},
		collectible = {description = "Spawns a Collectible in the middle of the screen.", parameters = {{name = "collectible", type = "Collectible", optional = false}}}
		-- Add commands to tinker with Expression Variables
		-- Add a list of Expression Variables in a debug screen
	}
	self.commandNames = {}
	for commandName, commandData in pairs(self.commands) do
		table.insert(self.commandNames, commandName)
	end
	table.sort(self.commandNames)

	self.profUpdate = Profiler("Update")
	self.profDraw = Profiler("Draw")
	self.profDraw2 = Profiler("Draw")
	self.profDrawLevel = Profiler("Draw: Level")
	self.prof3 = Profiler("Draw: Level2")
	self.profMusic = Profiler("Music volume")

	self.profVisible = false
	self.profPage = 1
	self.profPages = {self.profUpdate, self.profMusic, self.profDrawLevel, self.prof3}

	self.uiWidgetCount = 0
	self.vec2PerFrame = 0
	self.lastVec2PerFrame = 0
	self.e = false

	self.displayedDeprecationTraces = {}



	self.gameDebugVisible = false -- Switched by F3
	self.textDebugVisible = false -- Switched by F4
	self.fpsDebugVisible = false -- Switched by F5
	self.sphereDebugVisible = false -- Switched by F6
end



---Updates the debug class.
---@param dt number Time delta in seconds.
function Debug:update(dt)
	self.console:update(dt)
	self.lastVec2PerFrame = self.vec2PerFrame
	self.vec2PerFrame = 0
end

---Draws the debug class, which includes the help overlay, profiler, console, UI debugging and all elements controlled with F* keys.
function Debug:draw()
	-- Profilers
	if self.profVisible then
		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(_FONT)
		self.profPages[self.profPage]:draw(Vec2(0, _Display.size.y))
		self.profDraw:draw(Vec2(400, _Display.size.y))
		self.profDraw2:draw(Vec2(400, _Display.size.y))

		self:drawVisibleText("Debug Keys:", Vec2(10, 10), 15)
		self:drawVisibleText("[F1] Performance", Vec2(10, 25), 15)
		self:drawVisibleText("[F2] UI Tree", Vec2(10, 40), 15)
		self:drawVisibleText("    [Ctrl+F2] Collapse all invisible UI Nodes", Vec2(10, 55), 15)
		self:drawVisibleText("[F3] Gameplay debug display", Vec2(10, 70), 15)
		self:drawVisibleText("[F4] Debug text (FPS, level data, etc.)", Vec2(10, 85), 15)
		self:drawVisibleText("[F5] FPS Counter", Vec2(10, 100), 15)
		self:drawVisibleText("[F6] Sphere trains path overlay", Vec2(10, 115), 15)
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

function Debug:keypressed(key)
	if not self.console.active then
		if key == "f1" then
			self.profVisible = not self.profVisible
		elseif key == "f3" then
			self.gameDebugVisible = not self.gameDebugVisible
			self.console:print({_COLORS.aqua, string.format("[Debug] Gameplay Debug: %s", self.gameDebugVisible and "ON" or "OFF")})
		elseif key == "f4" then
			self.textDebugVisible = not self.textDebugVisible
		elseif key == "f5" then
			self.fpsDebugVisible = not self.fpsDebugVisible
		elseif key == "f6" then
			self.sphereDebugVisible = not self.sphereDebugVisible
		elseif key == "f10" then
			self:deprecationNotice("test")
		end
		if key == "kp-" and self.profPage > 1 then self.profPage = self.profPage - 1 end
		if key == "kp+" and self.profPage < #self.profPages then self.profPage = self.profPage + 1 end
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

function Debug:wheelmoved(x, y)
	self.uiDebug:wheelmoved(x, y)
end



---Prints a deprecation notice to the ingame console.
---@param message string The message to be printed.
---@param depth integer? The message will contain one line in the traceback. This parameter determines how many jumps back in the traceback should be made. The function will never print more than one instance of the same line.
function Debug:deprecationNotice(message, depth)
	if not _EngineSettings:getPrintDeprecationNotices() then
		return
	end
    depth = depth or 1
	local trace = _Utils.strTrim(_Utils.strSplit(debug.traceback(), "\n")[depth + 2])
	if _Utils.isValueInTable(self.displayedDeprecationTraces, trace) then
		return
	end
	table.insert(self.displayedDeprecationTraces, trace)
	self.console:print({_COLORS.aqua, "[Debug] ", _COLORS.red, "Deprecation Notice: ", _COLORS.purple, message})
	self.console:print({_COLORS.yellow, "        " .. trace})
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

	return s
end

function Debug:getDebugParticle()
	local s = ""

	s = s .. "ParticlePacket# = " .. tostring(_Game.particleManager:getParticlePacketCount()) .. "\n"
	s = s .. "ParticleSpawner# = " .. tostring(_Game.particleManager:getParticleSpawnerCount()) .. "\n"
	s = s .. "Particle# = " .. tostring(_Game.particleManager:getParticlePieceCount()) .. "\n"

	return s
end

function Debug:getDebugProfile()
	local profile = _Game:getCurrentProfile()
	local s = ""

	s = s .. "LevelNumber = " .. profile:getLevelStr() .. "\n"
	s = s .. "LevelID = " .. profile:getLevelIDStr() .. "\n"
	s = s .. "LatestCheckpoint = " .. tostring(profile:getLatestCheckpoint()) .. "\n"
	s = s .. "CheckpointUpcoming = " .. tostring(profile:isCheckpointUpcoming()) .. "\n"
	s = s .. string.format("Rollback: Score = %s, Coins = %s", profile.session.rollbackScore, profile.session.rollbackCoins) .. "\n"
	local levelData = profile:getCurrentLevelData()
	if levelData then
		s = s .. "LevelRecord = " .. tostring(levelData.score) .. "\n"
		s = s .. "Won = " .. tostring(levelData.won) .. "\n"
		s = s .. "Lost = " .. tostring(levelData.lost) .. "\n"
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
				s = s .. string.format("%.2f", time) .. "\n"
			end
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

	s = s .. "MusicVolume = " .. tostring(options:getMusicVolume()) .. "\n"
	s = s .. "SoundVolume = " .. tostring(options:getSoundVolume()) .. "\n"
	s = s .. "FullScreen = " .. tostring(options:getFullscreen()) .. "\n"
	s = s .. "Mute = " .. tostring(options:getMute()) .. "\n"
	s = s .. "\n"
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
	s = s .. "\n===== PROFILE =====\n"
	if _Game.getCurrentProfile and _Game:getCurrentProfile() and _Game:getCurrentProfile().session then
		s = s .. self:getDebugProfile()
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



---Draws a text with a semitransparent background.
---@param text string|table The text to be drawn.
---@param pos Vector2 The text position.
---@param height number The box height, in pixels.
---@param width number? The box width, in pixels. Defaults to the text width.
---@param alpha number? The semitransparency parameter.
---@param shadow boolean? If set, the text will have a shadow drawn for extra visibility.
---@param backgroundColor table? The background color, black by default.
---@param rightAlign boolean? If set, the text will grow to the left.
function Debug:drawVisibleText(text, pos, height, width, alpha, shadow, backgroundColor, rightAlign)
	if text == "" then
		return
	end

	width = width or love.graphics.getFont():getWidth(_Utils.strUnformat(text))
	alpha = alpha or 1
	backgroundColor = backgroundColor or _COLORS.black
	local x = pos.x
	if rightAlign then
		x = x - width
	end

	love.graphics.setColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], 0.7 * alpha)
	love.graphics.rectangle("fill", x - 3, pos.y, width + 6, height)
	if shadow then
		love.graphics.setColor(0, 0, 0, alpha)
		love.graphics.print(text, x + 2, pos.y + 2)
	end
	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.print(text, x, pos.y)
end

function Debug:drawDebugInfo()
	-- Debug screen
	local leftLines = _Utils.strSplit(self:getDebugInfo(), "\n")
	for i, l in ipairs(leftLines) do
		self:drawVisibleText(l, Vec2(0, 15 * (i - 1)), 15)
	end

	local rightLines = _Utils.strSplit(self:getRightDebugInfo(), "\n")
	for i, l in ipairs(rightLines) do
		self:drawVisibleText(l, Vec2(_Display.size.x, 15 * (i - 1)), 15, nil, nil, nil, nil, true)
	end
end

function Debug:drawFpsInfo()
	local s = "FPS = " .. tostring(love.timer.getFPS())

	self:drawVisibleText(s, Vec2(), 15, 65)
end



function Debug:drawSphereInfo()
	local p = Vec2(0, _Display.size.y - 200)
	local s = Vec2(_Display.size.x, 200)

	-- background
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.rectangle("fill", p.x, p.y, s.x, s.y)

	local n = 0
	local m = 0

	if _Game.level then
		for i, path in ipairs(_Game.level.map.paths) do
			love.graphics.setColor(1, 1, 1)
			love.graphics.print("Path " .. tostring(i), p.x + 10, p.y + 10 + n)
			n = n + 25
			for j, sphereChain in ipairs(path.sphereChains) do
				love.graphics.setColor(1, 1, 1)
				love.graphics.print(tostring(j), p.x + 20, p.y + 10 + n)
				local lastSphereGroup = sphereChain:getLastSphereGroup()
				if lastSphereGroup then
					love.graphics.print(tostring(math.floor(sphereChain:getLastSphereGroup().offset)) .. "px", p.x + 50, p.y + 10 + n)
					m = 0
					for k = #sphereChain.sphereGroups, 1, -1 do -- reverse iteration
						local sphereGroup = sphereChain.sphereGroups[k]
						for l, sphere in ipairs(sphereGroup.spheres) do
							local color = sphere:getConfig().color
							local alpha = sphere:isGhost() and 0.5 or 1
							if color and type(color) == "table" then
								love.graphics.setColor(color.r, color.g, color.b, alpha)
							else
								love.graphics.setColor(0.5, 0.5, 0.5, alpha)
							end
							love.graphics.circle("fill", p.x + 120 + m, p.y + 20 + n, 10)
							m = m + 20
						end
						if sphereGroup.nextGroup then
							love.graphics.setColor(1, 1, 1)
							love.graphics.print(tostring(math.floor(sphereGroup.nextGroup:getBackPos() - sphereGroup:getFrontPos())) .. "px", p.x + 150 + m, p.y + 10 + n)
						end
						--if k > 1 and sphereChain.sphereGroups[k - 1] ~= sphereGroup.nextGroup then print("ERROR") end
						--if k < #sphereChain.sphereGroups and sphereChain.sphereGroups[k + 1] ~= sphereGroup.prevGroup then print("ERROR") end

						m = m + 100
					end
					if j > 1 then
						local a = sphereChain:getPreviousChain():getLastSphereGroup():getBackPos()
						local b = sphereChain:getFirstSphereGroup():getFrontPos()
						love.graphics.setColor(1, 1, 1)
						love.graphics.print(tostring(math.floor(a - b)) .. "px", p.x + 20, p.y + n)
					end
				else
					love.graphics.setColor(1, 0, 0)
					love.graphics.print("ERROR", p.x + 50, p.y + 10 + n)
				end

				n = n + 25
			end
		end
	else
		love.graphics.setColor(1, 1, 1)
		love.graphics.print("No level available!", p.x, p.y)
	end
end



---Returns a list of TAB completion suggestions for the current command.
---@param command string The incomplete command. The suggestions will be provided for the last word.
---@return table
function Debug:getCommandCompletionSuggestions(command)
	local suggestions = {}
	local words = _Utils.strSplit(command, " ")
	if #words == 1 then
		-- First word: provide the suggestions for command names.
		suggestions = _Utils.copyTable(_Debug.commandNames)
	else
		-- Subsequent word: check the command and provide the suggestions for command arguments.
		local commandConfig = self.commands[words[1]]
		if commandConfig then
			local parameter = commandConfig.parameters[#words - 1]
			if parameter then
				if parameter.type == "Collectible" then
					if _Game.resourceManager then
						suggestions = _Game.resourceManager:getAssetList("collectible")
					end
				end
			end
		end
	end

	-- Remove irrelevant suggestions and sort them alphabetically.
	for i = #suggestions, 1, -1 do
		if not _Utils.strStartsWith(suggestions[i], words[#words]) then
			table.remove(suggestions, i)
		end
	end
	table.sort(suggestions)
	return suggestions
end



function Debug:runCommand(command)
	local words = _Utils.strSplit(command, " ")

	-- Get basic command stuff.
	local command = words[1]
	local commandData = self.commands[command]
	if not commandData then
		self.console:print({_COLORS.red, string.format("Command \"%s\" not found. Type \"help\" to see available commands.", words[1])})
		return
	end

	-- Obtain all necessary parameters.
	local parameters = {}
	for i, parameter in ipairs(commandData.parameters) do
		local raw = words[i + 1]
		if not raw then
			if not parameter.optional then
				self.console:print({_COLORS.red, string.format("Missing parameter: \"%s\", expected: %s", parameter.name, parameter.type)})
				return
			end
		else
			if parameter.type == "number" or parameter.type == "integer" then
				raw = tonumber(raw)
				if not raw then
					self.console:print({_COLORS.red, string.format("Failed to convert to number: \"%s\", expected: %s", words[i + 1], parameter.type)})
					return
				end
			elseif parameter.type == "Collectible" then
				raw = _Game.resourceManager:getCollectibleConfig(raw)
			end
			-- Greedy parameters can only be strings and are always last (taking the rest of the command).
			if parameter.type == "string" and parameter.greedy then
				for j = i + 2, #words do
					raw = raw .. " " .. words[j]
				end
			end
		end
		table.insert(parameters, raw)
	end

	-- Command handling
	if command == "help" then
		self.console:print({_COLORS.purple, "This is a still pretty rough console of OpenSMCE!"})
		self.console:print({_COLORS.green, "Available commands:"})
		for i, name in ipairs(self.commandNames) do
			local commandData = self.commands[name]
			local msg = {_COLORS.yellow, name}
			for i, parameter in ipairs(commandData.parameters) do
				local name = parameter.name
				if parameter.greedy then
					name = name .. "..."
				end
				if parameter.optional then
					table.insert(msg, _COLORS.aqua)
					table.insert(msg, string.format(" [%s]", name))
				else
					table.insert(msg, _COLORS.aqua)
					table.insert(msg, string.format(" <%s>", name))
				end
			end
			table.insert(msg, _COLORS.white)
			table.insert(msg, " - " .. commandData.description)
			self.console:print(msg)
		end
	elseif command == "p" then
		-- REMOVED: kept for reference in the future
		local t = {fire = "bomb", ligh = "lightning", wild = "wild", bomb = "colorbomb", slow = "slow", stop = "stop", rev = "reverse", shot = "shotspeed"}
		for word, name in pairs(t) do
			if parameters[1] == word then
				if word == "bomb" then
					if not parameters[2] or parameters[2] < 1 or parameters[2] > 7 then
						self.console:print({_COLORS.red, "Missing parameter (expected an integer from 1 to 7)."})
						return
					end
					--_Game.session:usePowerup({name = name, color = parameters[2]})
				else
					--_Game.session:usePowerup({name = name})
				end
				self.console:print("Powerup applied")
			end
		end
	elseif command == "sp" then
		-- REMOVED: kept for reference in the future
		_Game.level.destroyedSpheres = parameters[1]
		self.console:print("Spheres destroyed set to " .. tostring(parameters[1]))
	elseif command == "b" then
		-- REMOVED: kept for reference in the future
		for i, path in ipairs(_Game.level.map.paths) do
			for j, sphereChain in ipairs(path.sphereChains) do
				for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
					sphereGroup.offset = sphereGroup.offset + 1000
				end
			end
		end
		self.console:print("Boosted!")
	elseif command == "s" then
		-- REMOVED: kept for reference in the future
		for i, path in ipairs(_Game.level.map.paths) do
			path:spawnChain()
		end
		self.console:print("Spawned new chains!")
	elseif command == "t" then
		_TimeScale = parameters[1]
		self.console:print("Time scale set to " .. tostring(parameters[1]))
	elseif command == "e" then
		self.e = not self.e
		self.console:print("Background cheat mode toggled")
	elseif command == "n" then
		SphereSelectorResult({operations = {{type = "add", condition = Expression(true)}}}):destroy()
		self.console:print("Nuked!")
	elseif command == "ppp" then
		_Game.level:applyEffect({type = "spawnPathEntity", pathEntity = "path_entities/scorpion.json"})
	elseif command == "ls" then
		_Game.level:applyEffect({type = "lightningStorm", count = 10})
	elseif command == "net" then
		_Game.level:applyEffect({type = "activateNet", time = 20})
	elseif command == "test" then
		_Game:spawnParticle("particles/collapse_vise.json", Vec2(100, 400))
	elseif command == "crash" then
		return "crash"
	elseif command == "expr" then
		local e = Expression(parameters[1], true)
		self.console:print(string.format("expr(%s): %s", parameters[1], e:evaluate()))
	elseif command == "exprt" then
		local e = Expression(parameters[1], true)
		for i, step in ipairs(e.data) do
			_Log:printt("Debug", string.format("%s   %s", step.type, step.value))
		end
		self.console:print(string.format("exprt(%s): %s", parameters[1], e:getDebug()))
	elseif command == "ex" then
		local e = Expression("2", true)
		self.console:print(string.format("ex(%s):", parameters[1]))
		local tokens = e:tokenize(parameters[1])
		for i, token in ipairs(tokens) do
			self.console:print(string.format("%s   %s", token.value, token.type))
		end
		self.console:print("")
		self.console:print("")
		self.console:print("Compilation result:")
		e.data = e:compile(tokens)
		for i, step in ipairs(e.data) do
			self.console:print(string.format("%s   %s", step.type, step.value))
		end
		self.console:print(string.format("ex(%s): %s", parameters[1], e:evaluate()))
	elseif command == "collectible" then
		_Game.level:spawnCollectible(_Game:getNativeResolution() / 2, parameters[1].id)
	end
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

function Debug:profDrawStop()
	self.profDraw:stop()
end

function Debug:profDraw2Start()
	self.profDraw2:start()
end

function Debug:profDraw2Checkpoint(n)
	self.profDraw2:checkpoint(n)
end

function Debug:profDraw2Stop()
	self.profDraw2:stop()
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



function Debug:getWitty()
	local witties = _Utils.strSplit(_Utils.loadFile("assets/eggs_crash.txt"), "\n")
	return witties[math.random(1, #witties)]
end



return Debug
