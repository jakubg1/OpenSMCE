local class = require "com/class"

---@class Level
---@overload fun(data):Level
local Level = class:derive("Level")

local Vec2 = require("src/Essentials/Vector2")

local Map = require("src/Map")
local Shooter = require("src/Shooter")
local ShotSphere = require("src/ShotSphere")
local Collectible = require("src/Collectible")
local FloatingText = require("src/FloatingText")



---Constructs a new Level.
---@param data table The level data, specified in a level config file.
function Level:new(data)
	self.map = Map(self, "maps/" .. data.map, data.pathsBehavior)
	self.shooter = Shooter(data.shooter)

	self.matchEffect = data.matchEffect

	local objectives = data.objectives
	if data.target then
		objectives = {{type = "destroyedSpheres", target = data.target}}
	end
	if _Game.satMode then
		objectives = {{type = "destroyedSpheres", target = _Game:getCurrentProfile():getUSMNumber() * 10}}
	end
	self.objectives = {}
	for i, objective in ipairs(objectives) do
		table.insert(self.objectives, {type = objective.type, target = objective.target, progress = 0, reached = false})
	end

	self.colorGeneratorNormal = data.colorGeneratorNormal
	self.colorGeneratorDanger = data.colorGeneratorDanger

	self.musicName = data.music
	self.dangerMusicName = data.dangerMusic
	self.ambientMusicName = data.ambientMusic

	self.dangerSoundName = data.dangerSound or "sound_events/warning.json"
	self.dangerLoopSoundName = data.dangerLoopSound or "sound_events/warning_loop.json"

	-- Additional variables come from this method!
	self:reset()
end



---Updates the Level.
---@param dt number Delta time in seconds.
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



---Updates the Level's logic.
---@param dt number Delta time in seconds.
function Level:updateLogic(dt)
	self.map:update(dt)
	self.shooter:update(dt)

	-- Danger sound
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
	for i, shotSphere in ipairs(self.shotSpheres) do
		shotSphere:update(dt)
	end
	for i = #self.shotSpheres, 1, -1 do
		local shotSphere = self.shotSpheres[i]
		if shotSphere.delQueue then table.remove(self.shotSpheres, i) end
	end
	for i, collectible in ipairs(self.collectibles) do
		collectible:update(dt)
	end
	for i = #self.collectibles, 1, -1 do
		local collectible = self.collectibles[i]
		if collectible.delQueue then table.remove(self.collectibles, i) end
	end
	for i, floatingText in ipairs(self.floatingTexts) do
		floatingText:update(dt)
	end
	for i = #self.floatingTexts, 1, -1 do
		local floatingText = self.floatingTexts[i]
		if floatingText.delQueue then table.remove(self.floatingTexts, i) end
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



	-- Net
	if self.netTime > 0 then
		self.netTime = self.netTime - dt
		if self.netTime <= 0 then
			self.netTime = 0
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
			for i, path in ipairs(self.map.paths) do
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



	-- Time counting
	if self.started and not self.controlDelay and not self:getFinish() and not self.finish and not self.lost then
		self.time = self.time + dt
	end



	-- Objectives
	self:updateObjectives()



	-- Level start
	-- TODO: HARDCODED - make it more flexible
	if self.controlDelay then
		self.controlDelay = self.controlDelay - dt
		if self.controlDelay <= 0 then
			self.controlDelay = nil
		end
	end



	-- Level finish
	if self:getFinish() and not self.finish and not self.finishDelay then
		self.finishDelay = _Game.configManager.gameplay.level.finishDelay
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

	if self.bonusDelay and (self.bonusPathID == 1 or not self.map.paths[self.bonusPathID - 1].bonusScarab) then
		if self.map.paths[self.bonusPathID] then
			self.bonusDelay = self.bonusDelay - dt
			if self.bonusDelay <= 0 then
				self.map.paths[self.bonusPathID]:spawnBonusScarab()
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
			_Game.ui2Manager:executeCallback("levelComplete")
			self.ended = true
		end
	end



	-- Level lose
	if self.lost and self:getEmpty() and not self.ended then
		_Game.ui2Manager:executeCallback("levelLost")
		self.ended = true
	end
end



---Adjusts which music is playing based on the level's internal state.
function Level:updateMusic()
	local music = _Game:getMusic(self.musicName)

	if self.dangerMusicName then
		local dangerMusic = _Game:getMusic(self.dangerMusicName)

		-- If the level hasn't started yet, is lost, won or the game is paused,
		-- mute the music.
		if not self.started or self.ended or self.pause then
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
		if not self.started or self.ended or self.pause then
			music:setVolume(0)
		else
			music:setVolume(1)
		end
	end

	if self.ambientMusicName then
		local ambientMusic = _Game:getMusic(self.ambientMusicName)

		-- Ambient music plays all the time.
		ambientMusic:setVolume(1)
	end
end



---Updates the progress of this Level's objectives.
function Level:updateObjectives()
	for i, objective in ipairs(self.objectives) do
		if objective.type == "destroyedSpheres" then
			objective.progress = self.destroyedSpheres
		elseif objective.type == "timeSurvived" then
			objective.progress = self.time
		elseif objective.type == "score" then
			objective.progress = self.score
		end
		objective.reached = objective.progress >= objective.target
	end
end



---Activates a collectible generator in a given position.
---@param pos Vector2 The position where the collectibles will spawn.
---@param entryName string The CollectibleEntry ID.
function Level:spawnCollectiblesFromEntry(pos, entryName)
	if not entryName then
		return
	end

	local manager = _Game.configManager.collectibleGeneratorManager
	local entry = manager:getEntry(entryName)
	local collectibles = entry:generate()
	for i, collectible in ipairs(collectibles) do
		self:spawnCollectible(pos, collectible)
	end
end



---Adds score to the current Profile, as well as to level's statistics.
---@param score integer The score to be added.
function Level:grantScore(score)
	self.score = self.score + score
	_Game:getCurrentProfile():grantScore(score)
end



---Adds one coin to the current Profile and to level's statistics.
function Level:grantCoin()
	self.coins = self.coins + 1
	_Game:getCurrentProfile():grantCoin()
end



---Adds one gem to the level's statistics.
function Level:grantGem()
	self.gems = self.gems + 1
end



---Adds one sphere to the destroyed sphere counter.
function Level:destroySphere()
	if self.lost then
		return
	end

	self.destroyedSpheres = self.destroyedSpheres + 1
end



---Returns the fraction of progress of the given objective as a number in a range [0, 1].
---@param n integer The objective index.
---@return number
function Level:getObjectiveProgress(n)
	local objective = self.objectives[n]
	return math.min(objective.progress / objective.target, 1)
end



---Returns whether all objectives defined in this level have been reached.
---@return boolean
function Level:areAllObjectivesReached()
	for i, objective in ipairs(self.objectives) do
		if not objective.reached then
			return false
		end
	end
	return true
end



---Applies an effect to the level.
---@param effect table The effect data to be applied.
---@param TMP_pos Vector2? The position of the effect.
function Level:applyEffect(effect, TMP_pos)
	if effect.type == "replaceSphere" then
		self.shooter:getSphere(effect.color)
	elseif effect.type == "multiSphere" then
		self.shooter:getMultiSphere(effect.color, effect.count)
	elseif effect.type == "speedShot" then
		self.shooter.speedShotTime = effect.time
		self.shooter.speedShotSpeed = effect.speed
	elseif effect.type == "speedOverride" then
		for i, path in ipairs(self.map.paths) do
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
	elseif effect.type == "activateNet" then
		self.netTime = effect.time
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



---Strikes a single time during a lightning storm.
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



---Picks a sphere to be destroyed by a lightning storm strike, or `nil` if no spheres are found.
---@return Sphere|nil
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





---Returns currently used color generator data.
---@return table
function Level:getCurrentColorGenerator()
	if self.danger then
		return _Game.configManager.colorGenerators[self.colorGeneratorDanger]
	else
		return _Game.configManager.colorGenerators[self.colorGeneratorNormal]
	end
end



---Generates a new color for the Shooter.
---@return integer
function Level:getNewShooterColor()
	return self:generateColor(self:getCurrentColorGenerator())
end



---Generates a color based on the data.
---@param data table Shooter color generator data.
---@return integer
function Level:generateColor(data)
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
	end

	-- Else, return a fallback value.
	if type(data.fallback) == "table" then
		return self:generateColor(data.fallback)
	end
	return data.fallback
end





---Returns `true` if no Paths on this Level's Map contain any Spheres.
---@return boolean
function Level:getEmpty()
	for i, path in ipairs(self.map.paths) do
		if not path:getEmpty() then
			return false
		end
	end
	return true
end



---Returns `true` if any Paths on this Level's Map are in danger.
---@return boolean
function Level:getDanger()
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			if sphereChain:getDanger() then
				return true
			end
		end
	end
	return false
end



---Returns the maximum percentage distance which is occupied by spheres on all paths.
---@return number
function Level:getMaxDistance()
	local distance = 0
	for i, path in ipairs(self.map.paths) do
		distance = math.max(distance, path:getMaxOffset() / path.length)
	end
	return distance
end



---Returns the maximum danger percentage distance from all paths.
---Danger percentage is a number interpolated from 0 at the beginning of a danger zone to 1 at the end of the path.
---@return number
function Level:getMaxDangerProgress()
	local distance = 0
	for i, path in ipairs(self.map.paths) do
		distance = math.max(distance, path:getDangerProgress())
	end
	return distance
end



---Returns the Path which has the maximum percentage distance which is occupied by spheres on all paths.
---@return Path
function Level:getMostDangerousPath()
	local distance = nil
	local mostDangerousPath = nil
	for i, path in ipairs(self.map.paths) do
		local d = path:getMaxOffset() / path.length
		if not distance or d > distance then
			distance = d
			mostDangerousPath = path
		end
	end
	return mostDangerousPath
end



---Returns a randomly selected path.
---@param notEmpty boolean? If set to `true`, this call will prioritize paths which are not empty.
---@param inDanger boolean? If set to `true`, this call will prioritize paths which are in danger.
---@return Path
function Level:getRandomPath(notEmpty, inDanger)
	-- Set up a pool of paths.
	local paths = self.map.paths
	local pool = {}
	for i, path in ipairs(paths) do
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



---Returns `true` when there are no more spheres on the board and no more spheres can spawn, too.
---@return boolean
function Level:hasNoMoreSpheres()
	return self:areAllObjectivesReached() and not self.lost and self:getEmpty()
end



---Returns `true` if there are any shot spheres in this level, `false` otherwise.
---@return boolean
function Level:hasShotSpheres()
	return #self.shotSpheres > 0
end



---Returns `true` if the current level score is the highest in history for the current Profile.
---@return boolean
function Level:hasNewScoreRecord()
	return _Game:getCurrentProfile():getLevelHighscoreInfo(self.score)
end



---Returns `true` if the level has been finished, i.e. there are no more spheres and no more collectibles.
---@return boolean
function Level:getFinish()
	return self:hasNoMoreSpheres() and #self.collectibles == 0
end



---Takes one life away from the current Profile, and either restarts this Level, or ends the game.
function Level:tryAgain()
	if _Game:getCurrentProfile():loseLevel() then
		_Game.ui2Manager:executeCallback("levelStart")
		self:reset()
	else
		_Game.session:terminate()
	end
end



---Starts the Level.
function Level:begin()
	self.started = true
	self.controlDelay = _Game.configManager.gameplay.level.controlDelay
	_Game:getMusic(self.musicName):reset()
end



---Resumes the Level after loading data.
function Level:beginLoad()
	self.started = true
	_Game:getMusic(self.musicName):reset()
	if not self.bonusDelay and not self.map.paths[self.bonusPathID] then
		self.wonDelay = _Game.configManager.gameplay.level.wonDelay
	end
end



---Saves the current progress on this Level.
function Level:save()
	_Game:getCurrentProfile():saveLevel(self:serialize())
end



---Erases saved data from this Level.
function Level:unsave()
	_Game:getCurrentProfile():unsaveLevel()
end



---Marks this level as completed and forgets its saved data.
function Level:win()
	_Game:getCurrentProfile():winLevel(self.score)
	_Game:getCurrentProfile():unsaveLevel()
end



---Uninitialization function. Uninitializes Level's elements which need deinitializing.
function Level:destroy()
	self.shooter:destroy()
	for i, shotSphere in ipairs(self.shotSpheres) do
		shotSphere:destroy()
	end
	for i, collectible in ipairs(self.collectibles) do
		collectible:destroy()
	end
	for i, path in ipairs(self.map.paths) do
		path:destroy()
	end

	if self.ambientMusicName then
		local ambientMusic = _Game:getMusic(self.ambientMusicName)

		-- Stop any ambient music.
		ambientMusic:setVolume(0)
	end
end



---Resets the Level data.
function Level:reset()
	self.score = 0
	self.coins = 0
	self.gems = 0
	self.combo = 0
	self.destroyedSpheres = 0
	self.time = 0

	self.spheresShot = 0
	self.sphereChainsSpawned = 0
	self.maxChain = 0
	self.maxCombo = 0

	self.shotSpheres = {}
	self.collectibles = {}
	self.floatingTexts = {}

	self.danger = false
	self.dangerSound = nil
	self.warningDelay = 0
	self.warningDelayMax = nil

	self.pause = false
	self.canPause = true
	self.started = false
	self.controlDelay = nil
	self.lost = false
	self.ended = false
	self.wonDelay = nil
	self.finish = false
	self.finishDelay = nil
	self.bonusPathID = 1
	self.bonusDelay = nil

	self.gameSpeed = 1
	self.gameSpeedTime = 0
	self.lightningStormTime = 0
	self.lightningStormCount = 0
	self.netTime = 0
	self.shooter.speedShotTime = 0
	_Game.session.colorManager:reset()
end



---Forfeits the level. The shooter is emptied, and spheres start rushing into the pyramid.
function Level:lose()
	if self.lost then return end
	self.lost = true
	-- empty the shooter
	self.shooter:empty()
	-- delete all shot balls
	for i, shotSphere in ipairs(self.shotSpheres) do
		shotSphere:destroy()
	end
	self.shotSpheres = {}
	_Game:playSound("sound_events/level_lose.json")
end



---Sets the pause flag for this Level.
---@param pause boolean Whether the level should be paused.
function Level:setPause(pause)
	if self.pause == pause or (not self.canPause and not self.pause) then return end
	self.pause = pause
end



---Inverts the pause flag for this Level.
function Level:togglePause()
	self:setPause(not self.pause)
end



---Spawns a new Shot Sphere into the level.
---@param shooter Shooter The shooter which has shot the sphere.
---@param pos Vector2 Where the Shot Sphere should be spawned at.
---@param angle number Which direction the Shot Sphere should be moving, in radians. 0 is up.
---@param color integer The sphere ID to be shot.
---@param speed number The sphere speed.
function Level:spawnShotSphere(shooter, pos, angle, color, speed)
	table.insert(self.shotSpheres, ShotSphere(nil, shooter, pos, angle, color, speed))
end



---Spawns a new Collectible into the Level.
---@param pos Vector2 Where the Collectible should be spawned at.
---@param name string The collectible ID.
function Level:spawnCollectible(pos, name)
	table.insert(self.collectibles, Collectible(nil, pos, name))
end



---Spawns a new FloatingText into the Level.
---@param text string The text to be displayed.
---@param pos Vector2 The starting position of this text.
---@param font string Path to the Font which is going to be used.
function Level:spawnFloatingText(text, pos, font)
	table.insert(self.floatingTexts, FloatingText(text, pos, font))
end



---Draws this Level and all its components.
function Level:draw()
	self.map:draw()
	self.shooter:drawSpeedShotBeam()
	self.map:drawSpheres()
	self.shooter:draw()

	for i, shotSphere in ipairs(self.shotSpheres) do
		shotSphere:draw()
	end
	for i, collectible in ipairs(self.collectibles) do
		collectible:draw()
	end
	for i, floatingText in ipairs(self.floatingTexts) do
		floatingText:draw()
	end

	-- local p = posOnScreen(Vec2(20, 500))
	-- love.graphics.setColor(1, 1, 1)
	-- love.graphics.print(tostring(self.warningDelay) .. "\n" .. tostring(self.warningDelayMax), p.x, p.y)
end



---Stores all necessary data to save the level in order to load it again with exact same things on board.
---@return table
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
		time = self.time,
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
	for i, shotSphere in ipairs(self.shotSpheres) do
		table.insert(t.shotSpheres, shotSphere:serialize())
	end
	for i, collectible in ipairs(self.collectibles) do
		table.insert(t.collectibles, collectible:serialize())
	end
	return t
end



---Restores all data that was saved in the serialization method.
---@param t table The data to be deserialized.
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
	self.time = t.time
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
	self.shotSpheres = {}
	for i, tShotSphere in ipairs(t.shotSpheres) do
		table.insert(self.shotSpheres, ShotSphere(tShotSphere))
	end
	self.collectibles = {}
	for i, tCollectible in ipairs(t.collectibles) do
		table.insert(self.collectibles, Collectible(tCollectible))
	end
	-- Effects
	self.lightningStormCount = t.lightningStormCount
	self.lightningStormTime = t.lightningStormTime

	-- Pause
	self:setPause(true)
	self:updateObjectives()
end



return Level
