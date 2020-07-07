local class = require "class"
local Session = class:derive("Session")

local Vec2 = require("Essentials/Vector2")

local Profile = require("Profile")
local Highscores = require("Highscores")
local Level = require("Level")
local Collectible = require("Collectible")
local FloatingText = require("FloatingText")

function Session:new()
	self.profile = Profile("TEST")
	self.highscores = Highscores()
	
	self.scoreDisplay = 0
	self.pause = false
	self.canPause = true
	self.gameOver = false
	
	self.level = nil
	self.shotSpheres = {}
	self.collectibles = {}
	self.particles = {}
	self.floatingTexts = {}
	
	self.sphereColorCounts = {}
	self.dangerSphereColorCounts = {}
	for i = 1, 9 do
		self.sphereColorCounts[i] = 0
		self.dangerSphereColorCounts[i] = 0
	end
	self.lastSphereColor = 1
end

function Session:init()
	game:getWidget({"main"}):show()
	game:getWidget({"main", "Frame"}):show()
end

function Session:update(dt)
	self.canPause = self.level and not self.level.won and not self.level.lost
	if not love.window.hasFocus() and not self.pause then self:setPause(true) end
	if not self.canPause and self.pause then self:setPause(false) end
	
	if not self.pause then
		if self.level then self.level:update(dt) end
		for i, shotSphere in pairs(self.shotSpheres) do
			if shotSphere.delQueue then
				self.shotSpheres[i] = nil
				self.level.shooter.active = true
				game:playSound("shooter_fill")
			else
				shotSphere:update(dt)
			end
		end
		for i, collectible in pairs(self.collectibles) do
			if collectible.delQueue then
				self.collectibles[i] = nil
			else
				collectible:update(dt)
			end
		end
		for i, particle in pairs(self.particles) do
			if particle.delQueue then
				self.particles[i] = nil
			else
				particle:update(dt)
			end
		end
		for i, floatingText in pairs(self.floatingTexts) do
			if floatingText.delQueue then
				self.floatingTexts[i] = nil
			else
				floatingText:update(dt)
			end
		end
		
		if self.scoreDisplay < self.profile:getScore() then self.scoreDisplay = self.scoreDisplay + math.ceil((self.profile:getScore() - self.scoreDisplay) / 10) end
	end
end

function Session:startLevel()
	--self.level = Level({path = "levels/level_7_2.json", name = self.profile.data.session.level})
	self.level = Level({path = "levels/seven_lines.json", name = "0-0"})
	--self.level = Level(self.profile:getCurrentLevelData())
end

function Session:terminate()
	if self.gameOver then return end
	self.gameOver = true
	self.level = nil
	game:getWidget({"main", "Banner_LevelLose"}):clean()
	game:getWidget({"main", "Banner_GameOver"}):show()
end

function Session:setPause(pause)
	if self.pause == pause or (not self.canPause and not self.pause) then return end
	self.pause = pause
	game:getMusic("level"):setVolume(0)
	game:getMusic("danger"):setVolume(0)
	if pause then game:getWidget({"main", "Banner_Paused"}):show() else game:getWidget({"main", "Banner_Paused"}):hide() end
end

function Session:draw()
	if self.level then self.level:draw() end
	for i, shotSphere in pairs(self.shotSpheres) do shotSphere:draw() end
	for i, collectible in pairs(self.collectibles) do collectible:draw() end
	for i, particle in pairs(self.particles) do particle:draw() end
	for i, floatingText in pairs(self.floatingTexts) do floatingText:draw() end
end

function Session:newSphereColor(omitDangerCheck)
	local availableColors = {}
	if not omitDangerCheck then
		-- check the vises in danger first
		for i, count in ipairs(self.dangerSphereColorCounts) do
			if count > 0 then table.insert(availableColors, i) end
		end
		if #availableColors > 0 then return availableColors[math.random(1, #availableColors)] end -- if there are, pick one from them
	end
	for i, count in ipairs(self.sphereColorCounts) do
		if count > 0 then table.insert(availableColors, i) end
	end
	if #availableColors == 0 then return self.lastSphereColor end -- if no spheres present
	return availableColors[math.random(1, #availableColors)]
end

function Session:colorsMatch(color1, color2)
	return color1 ~= 0 and color2 ~= 0 and (color1 == color2 or color1 == -1 or color2 == -1)
end

function Session:spawnCollectible(pos, data)
	table.insert(self.collectibles, Collectible(pos, data))
	game:playSound("collectible_spawn_" .. data.type)
end

function Session:spawnFloatingText(text, pos, font)
	table.insert(self.floatingTexts, FloatingText(text, pos, font))
end

function Session:usePowerup(data)
	if data.name == "slow" then
		for i, path in ipairs(self.level.map.paths) do
			for j, sphereChain in ipairs(path.sphereChains) do
				sphereChain.slowTime = 3
				sphereChain.stopTime = 0
				sphereChain.reverseTime = 0
			end
		end
	elseif data.name == "stop" then
		for i, path in ipairs(self.level.map.paths) do
			for j, sphereChain in ipairs(path.sphereChains) do
				sphereChain.slowTime = 0
				sphereChain.stopTime = 3
				sphereChain.reverseTime = 0
			end
		end
	elseif data.name == "reverse" then
		for i, path in ipairs(self.level.map.paths) do
			for j, sphereChain in ipairs(path.sphereChains) do
				sphereChain.slowTime = 0
				sphereChain.stopTime = 0
				sphereChain.reverseTime = 3
			end
		end
	elseif data.name == "wild" then
		self.level.shooter:getColor(-1)
	elseif data.name == "bomb" then
		self.level.shooter:getColor(-2)
	elseif data.name == "lightning" then
		self.level.shooter:getColor(-3)
	elseif data.name == "shotspeed" then
		self.level.shooter.speedShotTime = 30
	elseif data.name == "colorbomb" then
		self:destroyColor(data.color)
	end
	game:playSound("collectible_catch_powerup_" .. data.name)
end

function Session:destroyFunction(f, scorePos)
	-- we pass a function in the f variable
	-- if f(param1, param2, ...) returns true, the sphere is nuked
	local score = 0
	for i, path in ipairs(self.level.map.paths) do
		for j = #path.sphereChains, 1, -1 do
			local sphereChain = path.sphereChains[j]
			for k = #sphereChain.sphereGroups, 1, -1 do
				local sphereGroup = sphereChain.sphereGroups[k]
				for l = #sphereGroup.spheres, 1, -1 do
					local sphere = sphereGroup.spheres[l]
					local spherePos = sphereGroup:getSpherePos(l)
					if f(sphere, spherePos) and sphere.color ~= 0 then
						sphereGroup:destroySphere(l)
						score = score + 100
					end
				end
			end
		end
	end
	self.level:grantScore(score)
	self:spawnFloatingText(numStr(score), scorePos, "fonts/score0.json")
end

function Session:destroyColor(color)
	self:destroyFunction(
		function(sphere, spherePos) return sphere.color == color end,
		self.level.shooter.pos + Vec2(0, -32)
	)
end

function Session:destroyRadius(pos, radius)
	self:destroyFunction(
		function(sphere, spherePos) return (pos - spherePos):len() <= radius end,
		pos
	)
end

function Session:destroyVertical(x, width)
	self:destroyFunction(
		function(sphere, spherePos) return math.abs(x - spherePos.x) <= width / 2 end,
		self.level.shooter.pos + Vec2(0, -32)
	)
end

function Session:getNearestSphere(pos)
	local nearestData = {path = nil, sphereChain = nil, sphereGroup = nil, sphereID = nil, sphere = nil, pos = nil, dist = nil}
	for i, path in ipairs(self.level.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local spherePos = sphereGroup:getSpherePos(l)
					local sphereAngle = sphereGroup:getSphereAngle(l)
					local sphereDist = (pos - spherePos):len()
					-- if closer than the closest for now, save it
					if not nearestData.dist or sphereDist < nearestData.dist then
						nearestData.path = path
						nearestData.sphereChain = sphereChain
						nearestData.sphereGroup = sphereGroup
						nearestData.sphereID = l
						nearestData.sphere = sphere
						nearestData.pos = spherePos
						nearestData.dist = sphereDist
					end
				end
			end
		end
	end
	return nearestData
end

function Session:getNearestSphereY(pos)
	local nearestData = {path = nil, sphereChain = nil, sphereGroup = nil, sphereID = nil, sphere = nil, pos = nil, dist = nil, targetPos = nil, half = nil}
	for i, path in ipairs(self.level.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local spherePos = sphereGroup:getSpherePos(l)
					local sphereAngle = sphereGroup:getSphereAngle(l)
					local sphereHidden = sphereGroup:getSphereHidden(l)
					
					local sphereTargetY = spherePos.y + math.sqrt(math.pow(16 --[[half of sphere size // note for placing constant here]], 2) - math.pow(pos.x - spherePos.x, 2))
					local sphereDist = Vec2(pos.x - spherePos.x, pos.y - sphereTargetY)
					
					local sphereDistAngle = (pos - spherePos):angle()
					local sphereAngleDiff = (sphereDistAngle - sphereAngle + math.pi / 2) % (math.pi * 2)
					local sphereHalf = sphereAngleDiff <= math.pi / 2 or sphereAngleDiff > 3 * math.pi / 2
					-- if closer than the closest for now, save it
					if not sphereHidden and math.abs(sphereDist.x) <= 16 and sphereDist.y >= 0 and (not nearestData.dist or sphereDist.y < nearestData.dist.y) then
						nearestData.path = path
						nearestData.sphereChain = sphereChain
						nearestData.sphereGroup = sphereGroup
						nearestData.sphereID = l
						nearestData.sphere = sphere
						nearestData.pos = spherePos
						nearestData.dist = sphereDist
						nearestData.targetPos = Vec2(pos.x, sphereTargetY)
						nearestData.half = sphereHalf
					end
				end
			end
		end
	end
	return nearestData
end

return Session