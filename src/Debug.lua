local class = require "com/class"
local Debug = class:derive("Debug")

local strmethods = require("src/strmethods")

local Vec2 = require("src/Essentials/Vector2")

local Profiler = require("src/Profiler")
local Console = require("src/Console")

function Debug:new()
	self.console = Console()
	
	
	
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
	self.e = false
	
	
	
	self.particleSpawnersVisible = false
	self.gameDebugVisible = false
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
		self.profPages[self.profPage]:draw(Vec2(0, displaySize.y))
		self.profDraw:draw(Vec2(400, displaySize.y))
		self.profDraw2:draw(Vec2(400, displaySize.y))
	end
	
	-- Console
	self.console:draw()
	
	-- UI tree
	if self.uiDebugVisible and game.sessionExists and game:sessionExists() then
		love.graphics.setColor(0, 0, 0, 0.5)
		love.graphics.rectangle("fill", 0, 0, 460, 600)
		love.graphics.setColor(1, 1, 1)
		for i, line in ipairs(self:getUITreeText()) do
			love.graphics.print(line[1], 10, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[2], 260, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[3], 270, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[4], 290, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[5], 320, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[6], 350, 10 + i * 15 + self.uiDebugOffset)
			love.graphics.print(line[7], 380, 10 + i * 15 + self.uiDebugOffset)
		end
	end
	
	-- Game and spheres
	if self.gameDebugVisible then self:drawDebugInfo() end
	if self.sphereDebugVisible then self:drawSphereInfo() end
end

function Debug:keypressed(key)
	if not self.console.active then
		if key == "o" then self.profVisible = not self.profVisible end
		if key == "w" then self.uiDebugVisible = not self.uiDebugVisible end
		if key == "q" then self.particleSpawnersVisible = not self.particleSpawnersVisible end
		if key == "d" then self.gameDebugVisible = not self.gameDebugVisible end
		if key == "p" then self.sphereDebugVisible = not self.sphereDebugVisible end
		if key == "h" then self.sphereDebugVisible2 = not self.sphereDebugVisible2 end
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



function Debug:getUITreeText(widget, rowTable, indent)
	widget = widget or game.widgets["root"]
	rowTable = rowTable or {}
	indent = indent or 0
	--if indent > 1 then return end
	
	local name = widget.name
	for i = 1, indent do name = "    " .. name end
	local visible = widget.visible and "X" or ""
	local visible2 = widget:getVisible() and "V" or ""
	local alpha = tostring(math.floor(widget.alpha * 10) / 10)
	local alpha2 = tostring(math.floor(widget:getAlpha() * 10) / 10)
	local time = widget.time and tostring(math.floor(widget.time * 100) / 100) or "-"
	local pos = tostring(widget.pos)
	--if widget:getVisible() then
		table.insert(rowTable, {name, visible, visible2, alpha, alpha2, time, pos})
	--end
	
	--if 
	for childN, child in pairs(widget.children) do
		self:getUITreeText(child, rowTable, indent + 1)
	end
	
	return rowTable
end



function Debug:getDebugMain()
	local s = ""
	
	s = s .. "Version = " .. VERSION .. "\n"
	s = s .. "Game = " .. game.name .. "\n"
	s = s .. "FPS = " .. tostring(love.timer.getFPS()) .. "\n"
	
	return s
end

function Debug:getDebugParticle()
	local s = ""
	
	s = s .. "ParticlePacket# = " .. tostring(game.particleManager:getParticlePacketCount()) .. "\n"
	s = s .. "ParticleSpawner# = " .. tostring(game.particleManager:getParticleSpawnerCount()) .. "\n"
	s = s .. "Particle# = " .. tostring(game.particleManager:getParticlePieceCount()) .. "\n"
	
	return s
end

function Debug:getDebugSession()
	local s = ""
	
	s = s .. "SphereColors:\n"
	for i = 1, 9 do
		s = s .. tostring(i) .. " -> " .. game.session.sphereColorCounts[i] .. ", " .. game.session.dangerSphereColorCounts[i] .. "\n"
	end
	
	return s
end

function Debug:getDebugLevel()
	local s = ""
	
	s = s .. "LevelNumber = " .. tostring(game.runtimeManager.profile.data.session.level) .. "\n"
	s = s .. "LevelScore = " .. tostring(game.session.level.score) .. "\n"
	s = s .. "LevelProgress = " .. tostring(game.session.level.destroyedSpheres) .. "/" .. tostring(game.session.level.target) .. "\n"
	s = s .. "LevelRecord = " .. tostring(game.runtimeManager.profile:getCurrentLevel().score) .. "\n"
	s = s .. "Won = " .. tostring(game.runtimeManager.profile:getCurrentLevel().won) .. "\n"
	s = s .. "Lost = " .. tostring(game.runtimeManager.profile:getCurrentLevel().lost) .. "\n"
	s = s .. "\n"
	s = s .. "Collectible# = " .. tostring(game.session.level.collectibles:size()) .. "\n"
	s = s .. "FloatingText# = " .. tostring(game.session.level.floatingTexts:size()) .. "\n"
	s = s .. "ShotSphere# = " .. tostring(game.session.level.shotSpheres:size()) .. "\n"
	
	return s
end

function Debug:getDebugOptions()
	local s = ""
	
	s = s .. "MusicVolume = " .. tostring(game.runtimeManager.options:getMusicVolume()) .. "\n"
	s = s .. "SoundVolume = " .. tostring(game.runtimeManager.options:getSoundVolume()) .. "\n"
	s = s .. "FullScreen = " .. tostring(game.runtimeManager.options:getFullscreen()) .. "\n"
	s = s .. "Mute = " .. tostring(game.runtimeManager.options:getMute()) .. "\n"
	s = s .. "\n"
	s = s .. "EffMusicVolume = " .. tostring(game.runtimeManager.options:getEffectiveMusicVolume()) .. "\n"
	s = s .. "EffSoundVolume = " .. tostring(game.runtimeManager.options:getEffectiveSoundVolume()) .. "\n"
	
	return s
end

function Debug:getDebugInfo()
	local s = ""
	
	s = s .. "===== MAIN =====\n"
	s = s .. self:getDebugMain()
	s = s .. "\n===== PARTICLE =====\n"
	if game.particleManager then
		s = s .. self:getDebugParticle()
	end
	s = s .. "\n===== SESSION =====\n"
	if game:sessionExists() then
		s = s .. self:getDebugSession()
	end
	s = s .. "\n===== LEVEL =====\n"
	if game:levelExists() then
		s = s .. self:getDebugLevel()
	end
	s = s .. "\n===== OPTIONS =====\n"
	if game.runtimeManager then
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

function Debug:drawDebugInfo()
	-- Debug screen
	--local p = posOnScreen(Vec2())
	local p = Vec2()
	
	local spl = strSplit(self:getDebugInfo(), "\n")
	
	for i, l in ipairs(spl) do
		love.graphics.setColor(0, 0, 0, 0.5)
		local t = love.graphics.newText(love.graphics.getFont(), l)
		love.graphics.rectangle("fill", p.x - 3, 15 * (i - 1), t:getWidth() + 6, 15)
		love.graphics.setColor(1, 1, 1)
		love.graphics.print(l, p.x, p.y + 15 * (i - 1))
	end
end



function Debug:drawSphereInfo()
	local p = Vec2(0, displaySize.y - 200)
	local s = Vec2(displaySize.x, 200)
	
	-- background
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.rectangle("fill", p.x, p.y, s.x, s.y)
	
	local n = 0
	local m = 0
	
	if game:levelExists() then
		for i, path in ipairs(game.session.level.map.paths.objects) do
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
						local color = SPHERE_COLORS[sphere.color]
						if color then love.graphics.setColor(color.r, color.g, color.b) else love.graphics.setColor(0.5, 0.5, 0.5) end
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
				n = n + 25
			end
		end
	else
		love.graphics.setColor(1, 1, 1)
		love.graphics.print("No level available!", p.x, p.y)
	end
end



function Debug:runCommand(command)
	local words = strSplit(command, " ")
	
	if words[1] == "p" then
		local t = {fire = "bomb", ligh = "lightning", wild = "wild", bomb = "colorbomb", slow = "slow", stop = "stop", rev = "reverse", shot = "shotspeed"}
		for word, name in pairs(t) do
			if words[2] == word then
				if word == "bomb" then
					if not words[3] or not tonumber(words[3]) or tonumber(words[3]) < 1 or tonumber(words[3]) > 7 then return false end
					game.session:usePowerup({name = name, color = tonumber(words[3])})
				else
					game.session:usePowerup({name = name})
				end
				self.console:print("Powerup applied")
				return true
			end
		end
	elseif words[1] == "sp" then
		if not words[2] or not tonumber(words[2]) then return false end
		game.session.level.destroyedSpheres = tonumber(words[2])
		self.console:print("Spheres destroyed set to " .. words[2])
		return true
	elseif words[1] == "b" then
		for i, path in ipairs(game.session.level.map.paths) do
			for j, sphereChain in ipairs(path.sphereChains) do
				for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
					sphereGroup.offset = sphereGroup.offset + 1000
				end
			end
		end
		self.console:print("Boosted!")
		return true
	elseif words[1] == "s" then
		for i, path in ipairs(game.session.level.map.paths) do
			path:spawnChain()
		end
		self.console:print("Spawned new chains!")
		return true
	elseif words[1] == "fs" then
		toggleFullscreen()
		self.console:print("Fullscreen toggled")
		return true
	elseif words[1] == "t" then
		if not words[2] or not tonumber(words[2]) then return false end
		timeScale = tonumber(words[2])
		self.console:print("Time scale set to " .. words[2])
		return true
	elseif words[1] == "e" then
		e = not e
		self.console:print("Background cheat mode toggled")
		return true
	elseif words[1] == "n" then
		game.session:destroyFunction(function(sphere, spherePos) return true end, Vec2())
		self.console:print("Nuked!")
		return true
	elseif words[1] == "test" then
		game:spawnParticle("particles/collapse_vise.json", Vec2(100, 400))
		return true
	elseif words[1] == "crash" then
		local witties = {
			"Aw, that hurt!",
			"Please stop doing that to me!",
			"GET REKT",
			"Was this a joke?",
			"Ah shit, here we go again.",
			"This is not funny!",
			"WELL DONE!",
			"If you fire a crash report now, I'm gonna be mad at you.",
			">:C",
			"Y-YAMETE KUDASAI!!~",
			"Don’t you have anything better to do?",
			"Game Over on hR 13-13 moment"
		}
		local witty = math.random(1, #witties)
		error("Crashed manually. " .. witties[witty])
	end
	
	return false
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

function Debug:profDraw2Stop()
	self.profDraw2:stop()
end



return Debug