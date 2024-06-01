local class = require "com.class"

---@class Debug
---@overload fun():Debug
local Debug = class:derive("Debug")

local Vec2 = require("src.Essentials.Vector2")

local Profiler = require("src.Kernel.Profiler")
local Console = require("src.Kernel.Console")

local Expression = require("src.Expression")
local SphereSelectorResult = require("src.SphereSelectorResult")



function Debug:new()
	self.console = Console()

	self.commands = {
		p = {description = "Doesn't work. Used to activate a powerup.", parameters = {{name = "name", type = "string", optional = false}, {name = "color", type = "integer", optional = true}}},
		sp = {description = "Doesn't work. Used to set the number of spheres destroyed.", parameters = {{name = "count", type = "integer", optional = false}}},
		b = {description = "Doesn't work. Used to boost spheres.", parameters = {}},
		s = {description = "Doesn't work. Used to immediately spawn new sphere chains on all paths.", parameters = {}},
		fs = {description = "Doesn't work. Used to activate Full Screen.", parameters = {}},
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
		help = {description = "Displays this list.", parameters = {}}
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

	self.uiDebugVisible = false
	self.uiDebugOffset = 0
	self.uiWidgetCount = 0
	self.e = false



	self.particleSpawnersVisible = false
	self.gameDebugVisible = false
	self.fpsDebugVisible = false
	self.sphereDebugVisible = false
	self.sphereDebugVisible2 = false
end



function Debug:update(dt)
	self.console:update(dt)
end

function Debug:draw()
	-- Profilers
	if self.profVisible then
		love.graphics.setColor(1, 1, 1)
		self.profPages[self.profPage]:draw(Vec2(0, _DisplaySize.y))
		self.profDraw:draw(Vec2(400, _DisplaySize.y))
		self.profDraw2:draw(Vec2(400, _DisplaySize.y))
	end

	-- Console
	self.console:draw()

	-- UI tree
	if self.uiDebugVisible and _Game.sessionExists then
		love.graphics.setColor(0, 0, 0, 0.5)
		love.graphics.rectangle("fill", 0, 0, 460, 600)
		love.graphics.setColor(1, 1, 1)
		for i, line in ipairs(self:getUITreeText()) do
			love.graphics.print(line[1], 10, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[2], 260, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[3], 270, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[4], 280, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[5], 300, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[6], 320, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[7], 340, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[8], 360, 10 + i * 15 + self.uiDebugOffset)
		end
	end

	-- Game and spheres
	if self.gameDebugVisible then self:drawDebugInfo() end
	if self.fpsDebugVisible then self:drawFpsInfo() end
	if self.sphereDebugVisible then self:drawSphereInfo() end
end

function Debug:keypressed(key)
	if not self.console.active then
		if key == "f1" then self.profVisible = not self.profVisible end
		if key == "f2" then self.uiDebugVisible = not self.uiDebugVisible end
		if key == "f3" then self.particleSpawnersVisible = not self.particleSpawnersVisible end
		if key == "f4" then self.gameDebugVisible = not self.gameDebugVisible end
		if key == "f5" then self.fpsDebugVisible = not self.fpsDebugVisible end
		if key == "f6" then self.sphereDebugVisible = not self.sphereDebugVisible end
		if key == "f7" then self.sphereDebugVisible2 = not self.sphereDebugVisible2 end
		if key == "kp-" and self.profPage > 1 then self.profPage = self.profPage - 1 end
		if key == "kp+" and self.profPage < #self.profPages then self.profPage = self.profPage + 1 end
		if key == "," then self.uiDebugOffset = self.uiDebugOffset - 75 end
		if key == "." then self.uiDebugOffset = self.uiDebugOffset + 75 end
	end

	self.console:keypressed(key)
end

function Debug:keyreleased(key)
	self.console:keyreleased(key)
end

function Debug:textinput(t)
	self.console:textinput(t)
end



function Debug:getUITreeText(node, rowTable, indent)
	local ui2 = _Game.configManager.config.useUI2
	if ui2 then
		node = node or _Game.uiManager.rootNodes["root"] or _Game.uiManager.rootNodes["splash"]
	else
		node = node or _Game.uiManager.widgets.root or _Game.uiManager.widgets.splash
	end
	rowTable = rowTable or {}
	indent = indent or 0
	--if indent > 1 then return end

	local name = node.name
	for i = 1, indent do name = "    " .. name end
	local visible = ""
	local visible2 = ""
	if not ui2 then
		visible = node.visible and "X" or ""
		visible2 = node:isVisible() and "V" or ""
	end
	local active = node:isActive() and "A" or ""
	local alpha = tostring(math.floor(node.alpha * 10) / 10)
	local alpha2
	if ui2 then
		alpha2 = tostring(math.floor(node:getGlobalAlpha() * 10) / 10)
	else
		alpha2 = tostring(math.floor(node:getAlpha() * 10) / 10)
	end
	local time = ""
	if not ui2 then
		time = node.time and tostring(math.floor(node.time * 100) / 100) or "-"
	end
	local pos = tostring(node.pos)
	--if node:getVisible() then
		table.insert(rowTable, {name, visible, visible2, active, alpha, alpha2, time, pos})
	--end

	--if
	for childN, child in pairs(node.children) do
		self:getUITreeText(child, rowTable, indent + 1)
	end

	return rowTable
end



function Debug:getDebugMain()
	local s = ""

	s = s .. "Version = " .. _VERSION .. "\n"
	s = s .. "Game = " .. _Game.name .. "\n"
	s = s .. "FPS = " .. tostring(love.timer.getFPS()) .. "\n"
	s = s .. "Drawcalls = " .. tostring(love.graphics.getStats().drawcalls) .. "\n"
	s = s .. "DrawcallsSaved = " .. tostring(love.graphics.getStats().drawcallsbatched) .. "\n"
	s = s .. "UIWidgetCount = " .. tostring(self.uiWidgetCount) .. "\n"

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
	local levelData = profile:getCurrentLevelData()
	if levelData then
		s = s .. "LevelRecord = " .. tostring(levelData.score) .. "\n"
		s = s .. "Won = " .. tostring(levelData.won) .. "\n"
		s = s .. "Lost = " .. tostring(levelData.lost) .. "\n"
	end

	return s
end

function Debug:getDebugLevel()
	local level = _Game.session.level
	local s = ""

	s = s .. "LevelScore = " .. tostring(level.score) .. "\n"
	s = s .. string.format("Accuracy = %s / %s (%.0d%%)", level.successfulShots, level.spheresShot, level:getShotAccuracy() * 100) .. "\n"
	s = s .. "LevelSequenceStep = " .. tostring(level.levelSequenceStep) .. "\n"
	s = s .. "Objectives:\n"
	for i, objective in ipairs(level.objectives) do
		s = s .. string.format("  %s: %s %s/%s\n", i, objective.type, objective.progress, objective.target)
	end
	s = s .. "\n"
	s = s .. "Collectible# = " .. tostring(#level.collectibles) .. "\n"
	s = s .. "FloatingText# = " .. tostring(#level.floatingTexts) .. "\n"
	s = s .. "ShotSphere# = " .. tostring(#level.shotSpheres) .. "\n"

	return s
end

function Debug:getDebugOptions()
	local s = ""

	s = s .. "MusicVolume = " .. tostring(_Game.runtimeManager.options:getMusicVolume()) .. "\n"
	s = s .. "SoundVolume = " .. tostring(_Game.runtimeManager.options:getSoundVolume()) .. "\n"
	s = s .. "FullScreen = " .. tostring(_Game.runtimeManager.options:getFullscreen()) .. "\n"
	s = s .. "Mute = " .. tostring(_Game.runtimeManager.options:getMute()) .. "\n"
	s = s .. "\n"
	s = s .. "EffMusicVolume = " .. tostring(_Game.runtimeManager.options:getEffectiveMusicVolume()) .. "\n"
	s = s .. "EffSoundVolume = " .. tostring(_Game.runtimeManager.options:getEffectiveSoundVolume()) .. "\n"

	return s
end

function Debug:getDebugInfo()
	local s = ""

	s = s .. "===== MAIN =====\n"
	s = s .. self:getDebugMain()
	s = s .. "\n===== PARTICLE =====\n"
	if _Game.particleManager then
		s = s .. self:getDebugParticle()
	end
	s = s .. "\n===== COLOR MANAGER =====\n"
	if _Game:sessionExists() then
		s = s .. _Game.session.colorManager:getDebugText()
	end
	s = s .. "\n===== PROFILE =====\n"
	if _Game:getCurrentProfile() then
		s = s .. self:getDebugProfile()
	end
	s = s .. "\n===== LEVEL =====\n"
	if _Game:levelExists() then
		s = s .. self:getDebugLevel()
	end
	s = s .. "\n===== OPTIONS =====\n"
	if _Game.runtimeManager then
		s = s .. self:getDebugOptions()
	end

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



function Debug:drawVisibleText(text, pos, height, width, alpha, shadow)
	alpha = alpha or 1

	if text == "" then
		return
	end

	love.graphics.setColor(0, 0, 0, 0.7 * alpha)
	if width then
		love.graphics.rectangle("fill", pos.x - 3, pos.y, width - 3, height)
	else
		love.graphics.rectangle("fill", pos.x - 3, pos.y, love.graphics.getFont():getWidth(_Utils.strUnformat(text)) + 6, height)
	end
	if shadow then
		love.graphics.setColor(0, 0, 0, alpha)
		love.graphics.print(text, pos.x + 2, pos.y + 2)
	end
	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.print(text, pos.x, pos.y)
end

function Debug:drawDebugInfo()
	-- Debug screen
	--local p = posOnScreen(Vec2())
	local p = Vec2()

	local spl = _Utils.strSplit(self:getDebugInfo(), "\n")

	for i, l in ipairs(spl) do
		self:drawVisibleText(l, p + Vec2(0, 15 * (i - 1)), 15)
	end
end

function Debug:drawFpsInfo()
	local s = "FPS = " .. tostring(love.timer.getFPS())

	self:drawVisibleText(s, Vec2(), 15, 50)
end



function Debug:drawSphereInfo()
	local p = Vec2(0, _DisplaySize.y - 200)
	local s = Vec2(_DisplaySize.x, 200)

	-- background
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.rectangle("fill", p.x, p.y, s.x, s.y)

	local n = 0
	local m = 0

	if _Game:levelExists() then
		for i, path in ipairs(_Game.session.level.map.paths) do
			love.graphics.setColor(1, 1, 1)
			love.graphics.print("Path " .. tostring(i), p.x + 10, p.y + 10 + n)
			n = n + 25
			for j, sphereChain in ipairs(path.sphereChains) do
				love.graphics.setColor(1, 1, 1)
				love.graphics.print(tostring(j), p.x + 20, p.y + 10 + n)
				love.graphics.print(tostring(math.floor(sphereChain:getLastSphereGroup().offset)) .. "px", p.x + 50, p.y + 10 + n)
				m = 0
				for k = #sphereChain.sphereGroups, 1, -1 do -- reverse iteration
					local sphereGroup = sphereChain.sphereGroups[k]
					for l, sphere in ipairs(sphereGroup.spheres) do
						local color = _Game.configManager.spheres[sphere.color].color
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

				n = n + 25
			end
		end
	else
		love.graphics.setColor(1, 1, 1)
		love.graphics.print("No level available!", p.x, p.y)
	end
end



function Debug:runCommand(command)
	local words = _Utils.strSplit(command, " ")

	-- Get basic command stuff.
	local command = words[1]
	local commandData = self.commands[command]
	if not commandData then
		self.console:print({{1, 0.2, 0.2}, string.format("Command \"%s\" not found. Type \"help\" to see available commands.", words[1])})
		return
	end

	-- Obtain all necessary parameters.
	local parameters = {}
	for i, parameter in ipairs(commandData.parameters) do
		local raw = words[i + 1]
		if not raw then
			if not parameter.optional then
				self.console:print({{1, 0.2, 0.2}, string.format("Missing parameter: \"%s\", expected: %s", parameter.name, parameter.type)})
				return
			end
		else
			if parameter.type == "number" or parameter.type == "integer" then
				raw = tonumber(raw)
				if not raw then
					self.console:print({{1, 0.2, 0.2}, string.format("Failed to convert to number: \"%s\", expected: %s", words[i + 1], parameter.type)})
					return
				end
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
		self.console:print({{1, 0.2, 1}, "This is a still pretty rough console of OpenSMCE!"})
		self.console:print({{0.2, 1, 0.2}, "Available commands:"})
		for i, name in ipairs(self.commandNames) do
			local commandData = self.commands[name]
			local msg = {{1, 1, 0.2}, name}
			for i, parameter in ipairs(commandData.parameters) do
				local name = parameter.name
				if parameter.greedy then
					name = name .. "..."
				end
				if parameter.optional then
					table.insert(msg, {0.2, 1, 1})
					table.insert(msg, string.format(" [%s]", name))
				else
					table.insert(msg, {0.2, 1, 1})
					table.insert(msg, string.format(" <%s>", name))
				end
			end
			table.insert(msg, {1, 1, 1})
			table.insert(msg, " - " .. commandData.description)
			self.console:print(msg)
		end
	elseif command == "p" then
		local t = {fire = "bomb", ligh = "lightning", wild = "wild", bomb = "colorbomb", slow = "slow", stop = "stop", rev = "reverse", shot = "shotspeed"}
		for word, name in pairs(t) do
			if parameters[1] == word then
				if word == "bomb" then
					if not parameters[2] or parameters[2] < 1 or parameters[2] > 7 then
						self.console:print({{1, 0.2, 0.2}, "Missing parameter (expected an integer from 1 to 7)."})
						return
					end
					_Game.session:usePowerup({name = name, color = parameters[2]})
				else
					_Game.session:usePowerup({name = name})
				end
				self.console:print("Powerup applied")
			end
		end
	elseif command == "sp" then
		_Game.session.level.destroyedSpheres = parameters[1]
		self.console:print("Spheres destroyed set to " .. tostring(parameters[1]))
	elseif command == "b" then
		for i, path in ipairs(_Game.session.level.map.paths) do
			for j, sphereChain in ipairs(path.sphereChains) do
				for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
					sphereGroup.offset = sphereGroup.offset + 1000
				end
			end
		end
		self.console:print("Boosted!")
	elseif command == "s" then
		for i, path in ipairs(_Game.session.level.map.paths) do
			path:spawnChain()
		end
		self.console:print("Spawned new chains!")
	elseif command == "fs" then
		--toggleFullscreen()
		self.console:print("Fullscreen toggled")
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
		_Game.session.level:applyEffect({type = "spawnPathEntity", pathEntity = "path_entities/scorpion.json"})
	elseif command == "ls" then
		_Game.session.level:applyEffect({type = "lightningStorm", count = 10})
	elseif command == "net" then
		_Game.session.level:applyEffect({type = "activateNet", time = 20})
	elseif command == "test" then
		_Game:spawnParticle("particles/collapse_vise.json", Vec2(100, 400))
	elseif command == "crash" then
		return "crash"
	elseif command == "expr" then
		local result = _Vars:evaluateExpression(parameters[1])
		self.console:print(string.format("expr(%s): %s", parameters[1], result))
	elseif command == "exprt" then
		local ce = Expression(parameters[1], true)
		for i, step in ipairs(ce.data) do
			_Log:printt("Debug", string.format("%s   %s", step.type, step.value))
		end
		self.console:print(string.format("exprt(%s): %s", parameters[1], ce:getDebug()))
	elseif command == "ex" then
		local ce = Expression("2", true)
		self.console:print(string.format("ex(%s):", parameters[1]))
		local tokens = ce:tokenize(parameters[1])
		for i, token in ipairs(tokens) do
			self.console:print(string.format("%s   %s", token.value, token.type))
		end
		self.console:print("")
		self.console:print("")
		self.console:print("Compilation result:")
		ce.data = ce:compile(tokens)
		for i, step in ipairs(ce.data) do
			self.console:print(string.format("%s   %s", step.type, step.value))
		end
		self.console:print(string.format("ex(%s): %s", parameters[1], ce:evaluate()))
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
