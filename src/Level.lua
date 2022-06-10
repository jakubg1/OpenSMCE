local class = require "com/class"
local Level = class:derive("Level")

local Vec2 = require("src/Essentials/Vector2")
local List1 = require("src/Essentials/List1")

local Map = require("src/Map")
local Shooter = require("src/Shooter")
local ShotSphere = require("src/ShotSphere")
local Collectible = require("src/Collectible")
local FloatingText = require("src/FloatingText")

function Level:new(data)
	-- data specified in level config file
	self.map = Map(self, "maps/" .. data.map, data.pathsBehavior)
	self.shooter = Shooter()

	self.gemGenerator = data.gemGenerator
	self.matchEffect = data.matchEffect

	self.target = data.target

	self.colorGeneratorNormal = data.colorGeneratorNormal
	self.colorGeneratorDanger = data.colorGeneratorDanger

	self.musicName = data.music
	self.dangerMusicName = data.dangerMusic

	self.dangerSoundName = data.dangerSound or "sound_events/warning.json"
	self.dangerLoopSoundName = data.dangerLoopSound or "sound_events/warning_loop.json"

	-- Additional variables come from this method!
	self:reset()
end

function Level:update(dt)
	-- Game speed modifier is going to be calculated outside the main logic
	-- function, as it messes with time itself.
	if self.gameSpeedTime > 0 then
		self.gameSpeedTime = self.gameSpeedTime - dt
		if self.gameSpeedTime <= 0 then
			-- The time has elapsed. Return to default speed.
			self.gameSpeed = 1
		end
	end

	if not self.pause then
		self:updateLogic(dt * self.gameSpeed)
	end

	self:updateMusic()
end

function Level:updateLogic(dt)
	self.map:update(dt)
	self.shooter:update(dt)

	-- danger sound
	local d1 = self:getDanger() and not self.lost
	local d2 = self.danger
	if d1 and not d2 then
		self.dangerSound = _Game:playSound(self.dangerLoopSoundName)
	elseif not d1 and d2 then
		self.dangerSound:stop()
		self.dangerSound = nil
	end

	self.danger = self:getDanger() and not self.lost



	-- Shot spheres, collectibles, floating texts
	for i, shotSphere in ipairs(self.shotSpheres.objects) do
		shotSphere:update(dt)
	end
	for i, collectible in ipairs(self.collectibles.objects) do
		collectible:update(dt)
	end
	for i, floatingText in ipairs(self.floatingTexts.objects) do
		floatingText:update(dt)
	end



	-- Lightning storm
	if self.lightningStormCount > 0 then
		self.lightningStormTime = self.lightningStormTime - dt
		if self.lightningStormTime <= 0 then
			self:spawnLightningStormPiece()
			self.lightningStormCount = self.lightningStormCount - 1
			if self.lightningStormCount == 0 then
				self.lightningStormTime = 0
			else
				self.lightningStormTime = self.lightningStormTime + 0.3
			end
		end
	end



	-- Warning lights
	local maxDistance = self:getMaxDangerProgress()
	if maxDistance > 0 and not self.lost then
		self.warningDelayMax = math.max((1 - maxDistance) * 3.5 + 0.5, 0.5)
	else
		self.warningDelayMax = nil
	end

	if self.warningDelayMax then
		self.warningDelay = self.warningDelay + dt
		if self.warningDelay >= self.warningDelayMax then
			for i, path in ipairs(self.map.paths.objects) do
				if path:isInDanger() then
					_Game:spawnParticle(path.dangerParticle, path:getPos(path.length))
				end
			end
			--game:playSound(self.dangerSoundName, 1 + (4 - self.warningDelayMax) / 6)
			_Game:playSound(self.dangerSoundName)
			self.warningDelay = 0
		end
	else
		self.warningDelay = 0
	end



	-- Level start
	-- TODO: HARDCODED - make it more flexible
	if self.controlDelay then
		self.controlDelay = self.controlDelay - dt
		if self.controlDelay <= 0 then
			self.controlDelay = nil
			self.shooter:activate()
		end
	end



	-- Level finish
	if self:getFinish() and not self.finish and not self.finishDelay then
		self.finishDelay = _Game.configManager.gameplay.level.finishDelay
		self.shooter.active = false
	end

	if self.finishDelay then
		self.finishDelay = self.finishDelay - dt
		if self.finishDelay <= 0 then
			self.finishDelay = nil
			self.finish = true
			self.bonusDelay = 0
			self.shooter:empty()
		end
	end

	if self.bonusDelay and (self.bonusPathID == 1 or not self.map.paths:get(self.bonusPathID - 1).bonusScarab) then
		if self.map.paths:get(self.bonusPathID) then
			self.bonusDelay = self.bonusDelay - dt
			if self.bonusDelay <= 0 then
				self.map.paths:get(self.bonusPathID):spawnBonusScarab()
				self.bonusDelay = _Game.configManager.gameplay.level.bonusDelay
				self.bonusPathID = self.bonusPathID + 1
			end
		elseif self:getFinish() then
			self.wonDelay = _Game.configManager.gameplay.level.wonDelay
			self.bonusDelay = nil
		end
	end

	if self.wonDelay then
		self.wonDelay = self.wonDelay - dt
		if self.wonDelay <= 0 then
			self.wonDelay = nil
			self.won = true
			local newRecord = _Game:getCurrentProfile():getLevelHighscoreInfo(self.score)
			_Game.uiManager:executeCallback({
				name = "levelComplete",
				parameters = {newRecord}
			})
		end
	end



	-- Level lose
	if self.lost and self:getEmpty() and not self.restart then
		_Game.uiManager:executeCallback("levelLost")
		self.restart = true
	end
end

function Level:updateMusic()
	local music = _Game:getMusic(self.musicName)

	if self.dangerMusicName then
		local dangerMusic = _Game:getMusic(self.dangerMusicName)

		-- If the level hasn't started yet, is lost, won or the game is paused,
		-- mute the music.
		if not self.started or self.lost or self.won or self.pause then
			music:setVolume(0)
			dangerMusic:setVolume(0)
		else
			-- Play the music accordingly to the danger flag.
			if self.danger then
				music:setVolume(0)
				dangerMusic:setVolume(1)
			else
				music:setVolume(1)
				dangerMusic:setVolume(0)
			end
		end
	else
		-- If there's no danger music, then mute it or unmute in a similar fashion.
		if not self.started or self.lost or self.won or self.pause then
			music:setVolume(0)
		else
			music:setVolume(1)
		end
	end
end



function Level:spawnCollectiblesFromEntry(pos, entryName)
	if not entryName then
		return
	end

	local manager = _Game.configManager.collectibleGeneratorManager
	local entry = manager:getEntry(entryName)
	assert(entry, string.format("Cound not find collectible entry: %s", entryName))
	local collectibles = entry:generate()
	for i, collectible in ipairs(collectibles) do
		self:spawnCollectible(pos, collectible)
	end
end

function Level:spawnGem(pos)
	self:spawnCollectiblesFromEntry(pos, self.gemGenerator)
end

function Level:grantScore(score)
	self.score = self.score + score
	_Game:getCurrentProfile():grantScore(score)
end

function Level:grantCoin()
	self.coins = self.coins + 1
	_Game:getCurrentProfile():grantCoin()
end

function Level:grantGem()
	self.gems = self.gems + 1
end

function Level:destroySphere()
	if self.targetReached or self.lost then return end
	self.destroyedSpheres = self.destroyedSpheres + 1
	if self.destroyedSpheres == self.target then self.targetReached = true end
end

function Level:applyEffect(effect, TMP_pos)
	if effect.type == "replaceSphere" then
		self.shooter:getSphere(effect.color)
	elseif effect.type == "multiSphere" then
		self.shooter:getMultiSphere(effect.color, effect.count)
	elseif effect.type == "speedShot" then
		self.shooter.speedShotTime = effect.time
		self.shooter.speedShotSpeed = effect.speed
	elseif effect.type == "speedOverride" then
		for i, path in ipairs(self.map.paths.objects) do
			for j, sphereChain in ipairs(path.sphereChains) do
				sphereChain.speedOverrideBase = effect.speedBase
				sphereChain.speedOverrideMult = effect.speedMultiplier
				sphereChain.speedOverrideDecc = effect.decceleration
				sphereChain.speedOverrideTime = effect.time
			end
		end
	elseif effect.type == "destroyAllSpheres" then
		-- DIRTY: replace this with an appropriate call within this function
		-- when Session class gets removed.
		_Game.session:destroyAllSpheres()
	elseif effect.type == "destroyColor" then
		-- Same as above.
		_Game.session:destroyColor(effect.color)
	elseif effect.type == "spawnScorpion" then
		local path = self:getMostDangerousPath()
		if path then
			path:spawnScorpion()
		end
	elseif effect.type == "lightningStorm" then
		self.lightningStormCount = effect.count
	elseif effect.type == "changeGameSpeed" then
		self.gameSpeed = effect.speed
		self.gameSpeedTime = effect.duration
	elseif effect.type == "setCombo" then
		self.combo = effect.combo
	elseif effect.type == "grantScore" then
		self:grantScore(effect.score)
		self:spawnFloatingText(_NumStr(effect.score), TMP_pos, "fonts/score0.json")
	elseif effect.type == "grantCoin" then
		self:grantCoin()
	elseif effect.type == "incrementGemStat" then
		self:grantGem()
	end
end

function Level:spawnLightningStormPiece()
	-- get a sphere candidate to be destroyed
	local sphere = self:getLightningStormSphere()
	-- if no candidate, the lightning storm is over
	if not sphere then
		self.lightningStormCount = 0
		self.lightningStormTime = 0
		return
	end

	-- spawn a particle, add points etc
	local pos = sphere:getPos()
	self:grantScore(100)
	self:spawnFloatingText(_NumStr(100), pos, _Game.configManager.spheres[sphere.color].matchFont)
	_Game:spawnParticle("particles/lightning_beam.json", pos)
	_Game:playSound("sound_events/lightning_storm_destroy.json")
	-- destroy it
	sphere.sphereGroup:destroySphere(sphere.sphereGroup:getSphereID(sphere))
end

function Level:getLightningStormSphere()
	local ln = _Game.session:getLowestMatchLength()
	-- first, check for spheres that would make matching easier when destroyed
	local spheres = _Game.session:getSpheresWithMatchLength(ln, true)
	if #spheres > 0 then
		return spheres[math.random(#spheres)]
	end
	-- if none, then check for any of the shortest groups
	spheres = _Game.session:getSpheresWithMatchLength(ln)
	if #spheres > 0 then
		return spheres[math.random(#spheres)]
	end
	-- if none, return nothing
	return nil
end





-- Returns currently used color generator data.
function Level:getCurrentColorGenerator()
	if self.danger then
		return _Game.configManager.colorGenerators[self.colorGeneratorDanger]
	else
		return _Game.configManager.colorGenerators[self.colorGeneratorNormal]
	end
end



-- Generates a new color for the Shooter.
function Level:getNewShooterColor()
	local data = self:getCurrentColorGenerator()
	if data.type == "random" then
		-- Make a pool with colors which are on the board.
		local pool = {}
		for i, color in ipairs(data.colors) do
			if not data.has_to_exist or _Game.session.colorManager:isColorExistent(color) then
				table.insert(pool, color)
			end
		end
		-- Return a random item from the pool.
		if #pool > 0 then
			return pool[math.random(#pool)]
		end
		-- Else, return a fallback value.
		return data.fallback
	elseif data.type == "near_end" then
		-- Select a random path.
		local path = _Game.session.level:getRandomPath(true, data.paths_in_danger_only)
		if not path:getEmpty() then
			-- Get a SphereChain nearest to the pyramid
			local sphereChain = path.sphereChains[1]
			-- Iterate through all groups and then spheres in each group
			local lastGoodColor = nil
			-- reverse iteration!!!
			for i, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for j = #sphereGroup.spheres, 1, -1 do
					local sphere = sphereGroup.spheres[j]
					local color = sphere.color
					-- If this color is generatable, check if we're lucky this time.
					if _MathIsValueInTable(data.colors, color) then
						if math.random() < data.select_chance then
							return color
						end
						-- Save this color in case if no more spheres are left.
						lastGoodColor = color
					end
				end
			end
			-- no more spheres left, get the last good one if exists
			if lastGoodColor then
				return lastGoodColor
			end
		end
		-- Else, return a fallback value.
		return data.fallback
	end
end





function Level:getEmpty()
	for i, path in ipairs(self.map.paths.objects) do
		if not path:getEmpty() then return false end
	end
	return true
end

function Level:getDanger()
	local ok = false
	for i, path in ipairs(self.map.paths.objects) do
		for j, sphereChain in ipairs(path.sphereChains) do
			if sphereChain:getDanger() then ok = true end
		end
	end
	return ok
end

function Level:getMaxDistance()
	local distance = 0
	for i, path in ipairs(self.map.paths.objects) do
		distance = math.max(distance, path:getMaxOffset() / path.length)
	end
	return distance
end

function Level:getMaxDangerProgress()
	local distance = 0
	for i, path in ipairs(self.map.paths.objects) do
		distance = math.max(distance, path:getDangerProgress())
	end
	return distance
end

function Level:getMostDangerousPath()
	local distance = nil
	local mostDangerousPath = nil
	for i, path in ipairs(self.map.paths.objects) do
		local d = path:getMaxOffset() / path.length
		if not distance or d > distance then
			distance = d
			mostDangerousPath = path
		end
	end
	return mostDangerousPath
end

-- Returns a randomly selected path.
-- If notEmpty is set to true, it will prioritize paths which are not empty.
-- If inDanger is set to true, it will prioritize paths which are in danger.
function Level:getRandomPath(notEmpty, inDanger)
	-- Set up a pool of paths.
	local paths = self.map.paths
	local pool = {}
	for i = 1, paths:size() do
		local path = paths:get(i)
		-- Insert a path into the pool if it meets the criteria.
		if not (notEmpty and path:getEmpty()) and not (inDanger and not path:isInDanger()) then
			table.insert(pool, path)
		end
	end
	-- If any path meets the criteria, pick a random one.
	if #pool > 0 then
		return pool[math.random(#pool)]
	end
	-- Else, loosen the criteria.
	if inDanger then
		return self:getRandomPath(notEmpty, false)
	else
		return self:getRandomPath()
	end
end

function Level:hasNoMoreSpheres()
	-- Returns true when there are no more spheres on the board and no more spheres can spawn, too.
	return self.targetReached and not self.lost and self:getEmpty()
end

function Level:getFinish()
	return self:hasNoMoreSpheres() and self.collectibles:empty()
end

function Level:tryAgain()
	if _Game:getCurrentProfile():loseLevel() then
		_Game.uiManager:executeCallback("levelStart")
		self:reset()
	else
		_Game.session:terminate()
	end
end

function Level:begin()
	self.started = true
	self.controlDelay = _Game.configManager.gameplay.level.controlDelay
	_Game:getMusic(self.musicName):reset()
end

function Level:beginLoad()
	self.started = true
	_Game:getMusic(self.musicName):reset()
	self.targetReached = self.destroyedSpheres == self.target
	if not self.bonusDelay and not self.map.paths:get(self.bonusPathID) then
		self.wonDelay = _Game.configManager.gameplay.level.wonDelay
	end
end

function Level:save()
	_Game:getCurrentProfile():saveLevel(self:serialize())
end

function Level:unsave()
	_Game:getCurrentProfile():unsaveLevel()
end

function Level:win()
	_Game:getCurrentProfile():winLevel(self.score)
	_Game:getCurrentProfile():unsaveLevel()
end

function Level:destroy()
	self.shooter:destroy()
	for i, shotSphere in ipairs(self.shotSpheres.objects) do
		shotSphere:destroy()
	end
	for i, collectible in ipairs(self.collectibles.objects) do
		collectible:destroy()
	end
	for i, path in ipairs(self.map.paths.objects) do
		path:destroy()
	end
end

function Level:reset()
	self.score = 0
	self.coins = 0
	self.gems = 0
	self.combo = 0
	self.destroyedSpheres = 0

	self.spheresShot = 0
	self.sphereChainsSpawned = 0
	self.maxChain = 0
	self.maxCombo = 0

	self.shotSpheres = List1()
	self.collectibles = List1()
	self.floatingTexts = List1()

	self.targetReached = false
	self.danger = false
	self.dangerSound = nil
	self.warningDelay = 0
	self.warningDelayMax = nil

	self.pause = false
	self.canPause = true
	self.started = false
	self.controlDelay = nil
	self.lost = false
	self.restart = false
	self.won = false
	self.wonDelay = nil
	self.finish = false
	self.finishDelay = nil
	self.bonusPathID = 1
	self.bonusDelay = nil

	self.gameSpeed = 1
	self.gameSpeedTime = 0
	self.lightningStormTime = 0
	self.lightningStormCount = 0
	self.shooter.speedShotTime = 0
	_Game.session.colorManager:reset()
end

function Level:lose()
	if self.lost then return end
	self.lost = true
	-- empty the shooter
	self.shooter:empty()
	-- delete all shot balls
	self.shotSpheres:clear()
	_Game:playSound("sound_events/level_lose.json")
end

function Level:setPause(pause)
	if self.pause == pause or (not self.canPause and not self.pause) then return end
	self.pause = pause
end

function Level:togglePause()
	self:setPause(not self.pause)
end

function Level:spawnShotSphere(shooter, pos, color, speed)
	self.shotSpheres:append(ShotSphere(nil, shooter, pos, color, speed))
end

function Level:spawnCollectible(pos, name)
	self.collectibles:append(Collectible(nil, pos, name))
end

function Level:spawnFloatingText(text, pos, font)
	self.floatingTexts:append(FloatingText(text, pos, font))
end



function Level:draw()
	self.map:draw()
	self.shooter:drawSpeedShotBeam()
	self.map:drawSpheres()
	self.shooter:draw()

	for i, shotSphere in ipairs(self.shotSpheres.objects) do
		shotSphere:draw()
	end
	for i, collectible in ipairs(self.collectibles.objects) do
		collectible:draw()
	end
	for i, floatingText in ipairs(self.floatingTexts.objects) do
		floatingText:draw()
	end

	-- local p = posOnScreen(Vec2(20, 500))
	-- love.graphics.setColor(1, 1, 1)
	-- love.graphics.print(tostring(self.warningDelay) .. "\n" .. tostring(self.warningDelayMax), p.x, p.y)
end



-- Store all necessary data to save the level in order to load it again with exact same things on board.
function Level:serialize()
	local t = {
		stats = {
			score = self.score,
			coins = self.coins,
			gems = self.gems,
			spheresShot = self.spheresShot,
			sphereChainsSpawned = self.sphereChainsSpawned,
			maxChain = self.maxChain,
			maxCombo = self.maxCombo
		},
		controlDelay = self.controlDelay,
		finish = self.finish,
		finishDelay = self.finishDelay,
		bonusPathID = self.bonusPathID,
		bonusDelay = self.bonusDelay,
		shooter = self.shooter:serialize(),
		shotSpheres = {},
		collectibles = {},
		combo = self.combo,
		lightningStormCount = self.lightningStormCount,
		lightningStormTime = self.lightningStormTime,
		destroyedSpheres = self.destroyedSpheres,
		paths = self.map:serialize(),
		lost = self.lost
	}
	for i, shotSphere in ipairs(self.shotSpheres.objects) do
		table.insert(t.shotSpheres, shotSphere:serialize())
	end
	for i, collectible in ipairs(self.collectibles.objects) do
		table.insert(t.collectibles, collectible:serialize())
	end
	return t
end

-- Restores all data that was saved in the serialization method.
function Level:deserialize(t)
	-- Prepare the counters
	_Game.session.colorManager:reset()

	-- Level stats
	self.score = t.stats.score
	self.coins = t.stats.coins
	self.gems = t.stats.gems
	self.spheresShot = t.stats.spheresShot
	self.sphereChainsSpawned = t.stats.sphereChainsSpawned
	self.maxChain = t.stats.maxChain
	self.maxCombo = t.stats.maxCombo
	self.combo = t.combo
	self.destroyedSpheres = t.destroyedSpheres
	self.lost = t.lost
	-- Utils
	self.controlDelay = t.controlDelay
	self.finish = t.finish
	self.finishDelay = t.finishDelay
	self.bonusPathID = t.bonusPathID
	self.bonusDelay = t.bonusDelay
	-- Paths
	self.map:deserialize(t.paths)
	-- Shooter
	self.shooter:deserialize(t.shooter)
	-- Shot spheres, collectibles
	self.shotSpheres:clear()
	for i, tShotSphere in ipairs(t.shotSpheres) do
		self.shotSpheres:append(ShotSphere(tShotSphere))
	end
	self.collectibles:clear()
	for i, tCollectible in ipairs(t.collectibles) do
		self.collectibles:append(Collectible(tCollectible))
	end
	-- Effects
	self.lightningStormCount = t.lightningStormCount
	self.lightningStormTime = t.lightningStormTime

	-- Pause
	self:setPause(true)
end

return Level
