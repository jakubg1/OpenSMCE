local class = require "com.class"

---Represents a Level. Houses the Map, Shooters, Shot Spheres, Collectibles and Floating Texts. Handles elements such as level objectives and general level event order.
---@class Level
---@overload fun(config):Level
local Level = class:derive("Level")

local Vec2 = require("src.Essentials.Vector2")

local Map = require("src.Game.Map")
local Shooter = require("src.Game.Shooter")
local ColorManager = require("src.Game.ColorManager")
local SphereSelectorResult = require("src.Game.SphereSelectorResult")
local ShotSphere = require("src.Game.ShotSphere")
local Collectible = require("src.Game.Collectible")
local Projectile = require("src.Game.Projectile")
local FloatingText = require("src.Game.FloatingText")

local Expression = require("src.Expression")



---Constructs a new Level.
---@param config LevelConfig The level config.
function Level:new(config)
	self.config = config

	self.map = Map(self, "maps/" .. config.map, config.pathsBehavior)
	self.shooter = Shooter(config.shooter)
	self.colorManager = ColorManager()

	self.matchEffect = config.matchEffect

	local objectives = config.objectives
	if _Game.satMode then
		objectives = {{type = "destroyedSpheres", target = _Game:getSession():getUSMNumber() * 10}}
	end
	self.objectives = {}
	for i, objective in ipairs(objectives) do
		table.insert(self.objectives, {type = objective.type, target = objective.target, progress = 0, reached = false})
	end

	self.levelSequence = config.sequence.sequence
	self.startingVariables = _Game.configManager.gameplay.levelVariables
	self.startingTimers = _Game.configManager.gameplay.levelTimers
	self.startingTimerSeries = _Game.configManager.gameplay.levelTimerSeries

	-- Additional variables come from `:reset()`!
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
			self.gameSpeedTime = 0
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
	self:updateTimers(dt)
	self:updateVariables()
	self.colorManager:dumpVariables()

	-- Danger sound
	if self.config.dangerLoopSound then
		local d1 = self:getDanger() and not self.lost
		local d2 = self.danger
		if d1 and not d2 then
			self.dangerLoopSound = _Game:playSound(self.config.dangerLoopSound)
		elseif not d1 and d2 then
			self.dangerLoopSound:stop()
			self.dangerLoopSound = nil
		end
	end

	self.danger = self:getDanger() and not self.lost



	-- Shot spheres, collectibles, floating texts
	for i, shotSphere in ipairs(self.shotSpheres) do
		shotSphere:update(dt)
	end
	_Utils.removeDeadObjects(self.shotSpheres)
	for i, collectible in ipairs(self.collectibles) do
		collectible:update(dt)
	end
	_Utils.removeDeadObjects(self.collectibles)
	for i, projectile in ipairs(self.projectiles) do
		projectile:update(dt)
	end
	_Utils.removeDeadObjects(self.projectiles)
	for i, floatingText in ipairs(self.floatingTexts) do
		floatingText:update(dt)
	end
	_Utils.removeDeadObjects(self.floatingTexts)



	-- Collectible rains
	for i, rain in ipairs(self.collectibleRains) do
		if rain.count > 0 then
			rain.time = rain.time - dt
			if rain.time <= 0 then
				local w, h = _Game:getNativeResolution()
				self:spawnCollectiblesFromEntry(math.random() * w, -32, rain.generator)
				rain.count = rain.count - 1
				if rain.count > 0 then
					rain.time = rain.time + rain.delay:evaluate()
				end
			end
		end
	end

	-- Remove finished collectible rains.
	for i = #self.collectibleRains, 1, -1 do
		if self.collectibleRains[i].count == 0 then
			table.remove(self.collectibleRains, i)
		end
	end



	-- Projectile storms
	for i, storm in ipairs(self.projectileStorms) do
		if storm.count > 0 then
			storm.time = storm.time - dt
			if storm.time <= 0 then
				local result = self:spawnProjectile(storm.projectile)
				if not result and storm.cancelWhenNoTargetsRemaining then
					storm.count = 0
				else
					storm.count = storm.count - 1
				end
				if storm.count > 0 then
					storm.time = storm.time + storm.delay:evaluate()
				end
			end
		end
	end

	-- Remove finished projectile storms.
	for i = #self.projectileStorms, 1, -1 do
		if self.projectileStorms[i].count == 0 then
			table.remove(self.projectileStorms, i)
		end
	end



	-- Net
	if self.netTime > 0 then
		self.netTime = self.netTime - dt
		if self.netTime <= 0 then
			self.netTime = 0
			self:destroyNet()
		end
	end

	-- Score multiplier
	if self.scoreMultiplierTime > 0 then
		self.scoreMultiplierTime = self.scoreMultiplierTime - dt
		if self.scoreMultiplierTime <= 0 then
			-- The time has elapsed. Return to default multiplier.
			self.scoreMultiplier = 1
			self.scoreMultiplierTime = 0
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
			self.map:spawnDangerParticles()
			if self.config.dangerSound then
				_Game:playSound(self.config.dangerSound)
			end
			self.warningDelay = 0
		end
	else
		self.warningDelay = 0
	end



	-- Current sequence step config
	local step = self.levelSequence[self.levelSequenceStep]

	if step.type == "wait" then
		self.levelSequenceVars.time = self.levelSequenceVars.time + dt
		if self.levelSequenceVars.time >= step.delay then
			self:advanceSequenceStep()
		end
	elseif step.type == "waitForCollectibles" then
		if self:getFinish() then
			self:advanceSequenceStep()
		end
	elseif step.type == "uiCallback" then
		-- Restart the callback if it needs to do so.
		if step.retriggerWhenLoaded and self.levelSequenceLoad then
			self:retriggerSequenceStep()
			self.levelSequenceLoad = false
		end
	elseif step.type == "pathEntity" then
		local isThereAnythingOnPreviousPaths = false
		for i = 1, self.levelSequenceVars.pathID do
			local path = self.map.paths[i]
			isThereAnythingOnPreviousPaths = path and path:hasPathEntities()
			if not path or isThereAnythingOnPreviousPaths then
				break
			end
		end

		while self.map.paths[self.levelSequenceVars.pathID] and (not step.separatePaths or not isThereAnythingOnPreviousPaths) do
			if self.levelSequenceVars.delay > 0 then
				self.levelSequenceVars.delay = self.levelSequenceVars.delay - dt
				break
			else
				local currentPath = self.map.paths[self.levelSequenceVars.pathID]
				currentPath:spawnPathEntity(step.pathEntity)
				self.levelSequenceVars.pathID = self.levelSequenceVars.pathID + 1
				self.levelSequenceVars.delay = step.launchDelay
				isThereAnythingOnPreviousPaths = true
			end
		end

		-- If all paths have been exhausted and either nothing is there or we don't have to wait until finished, move on to the next step.
		if not self.map.paths[self.levelSequenceVars.pathID] then
			if not step.waitUntilFinished or not isThereAnythingOnPreviousPaths then
				self:advanceSequenceStep()
			end
		end
	elseif step.type == "gameplay" then
		self.time = self.time + dt
		if self.levelSequenceVars.warmupTime then
			if step.previewFirstShooterColor then
				self.shooter:fillReserve()
			end
			self.levelSequenceVars.warmupTime = self.levelSequenceVars.warmupTime + dt
			if self.levelSequenceVars.warmupTime >= step.warmupTime then
				self.levelSequenceVars.warmupTime = nil
				if self.warmupLoop then
					self.warmupLoop:stop()
				end
			end
		end
		if step.onObjectivesReached and self:areAllObjectivesReached() then
			self:jumpToSequenceStep(step.onObjectivesReached)
		end
		if self:hasNoMoreSpheres() then
			if step.onWin then
				self:jumpToSequenceStep(step.onWin)
			else
				self:advanceSequenceStep()
			end
		end
	elseif step.type == "fail" then
		if self.failDestructionDelay then
			self.failDestructionDelay = self.failDestructionDelay - dt
			if self.failDestructionDelay <= 0 then
				self:destroyFrontmostSphere()
				local failConfig = _Game.configManager.gameplay.sphereBehavior.foulDestroySpheres
				self.failDestructionDelay = self.failDestructionDelay + failConfig.subsequentDelay
			end
		end
		if self:getEmpty() then
			self:advanceSequenceStep()
		end
	elseif step.type == "end" then
		if not self.ended then
			if step.status == "win" then
				_Game.uiManager:executeCallback("levelComplete")
			elseif step.status == "fail" then
				_Game.uiManager:executeCallback("levelLost")
			end
			if self.failLoop then
				self.failLoop:stop()
			end
			self.ended = true
		end
	end

	-- Reset the cascade combo if necessary.
	if _Game.configManager.gameplay.sphereBehavior.cascadeScope == "level" and not self:isMatchPredicted() then
		self:endCascade()
	end

	-- Objectives
	self:updateObjectives()
end



---Adjusts which music is playing based on the level's internal state.
function Level:updateMusic()
	local music = self.config.music
	local dangerMusic = self.config.dangerMusic
	local ambientMusic = self.config.ambientMusic
	local mute = self:getCurrentSequenceStep().muteMusic or self.pause

	if dangerMusic then
		-- If the level hasn't started yet, is lost, won or the game is paused,
		-- mute the music.
		if mute then
			music:play(0, 1)
			dangerMusic:play(0, 1)
		else
			-- Play the music accordingly to the danger flag.
			-- This "if" statement is an experimental feature where the music is sped up when in danger. Works with ASL only.
			-- TODO: Make this configurable.
			if true then
				if self.danger then
					-- TODO: Make the danger music continue instead of starting over if the game has been unpaused.
					if dangerMusic.volume == 0 then
						dangerMusic:stop()
						dangerMusic:play()
					end
					music:play(0, 1)
					dangerMusic:play(1, 1)
				else
					music:play(1, 1)
					dangerMusic:play(0, 1)
				end
			else
				if self.danger then
					music.instance:setTimeStretch(3)
				else
					music:play(1, 1)
					music.instance:setTimeStretch(1)
				end
			end
		end
	else
		-- If there's no danger music, then mute it or unmute in a similar fashion.
		if mute then
			music:play(0, 1)
		else
			music:play(1, 1)
		end
	end

	if ambientMusic then
		-- Ambient music plays all the time.
		ambientMusic:play(1, 1)
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
		elseif objective.type == "sphereChainsSpawned" then
			objective.progress = self.sphereChainsSpawned
		end
		objective.reached = objective.progress >= objective.target
	end
end



---Sets the Level Variable to the given value.
---@param name string The variable name.
---@param value number The new value.
function Level:setVariable(name, value)
	self.variables[name] = value
	_Vars:set("level." .. name, value)
end

---Sets the Level Timer to the given value.
---@param name string The timer name.
---@param value number The new value.
function Level:setTimer(name, value)
	self.timers[name] = value
	_Vars:set("level." .. name, value)
end

---Adds a new entry to the Level Timer Series.
---@param name string The name of timer series.
---@param time number The lifetime of the entry.
function Level:addToTimerSeries(name, time)
	table.insert(self.timerSeries[name], time)
	_Vars:set("level." .. name .. ".length", #self.timerSeries[name])
end

---Erases all entries from the given Level Timer Series.
---@param name string The name of timer series.
function Level:clearTimerSeries(name)
	self.timerSeries[name] = {}
end

---Exposes the current state of the level to Expression Variables:
--- - Streak (Luxor: Combo, Zuma: Chain): `[level.streak]`
--- - Shot accuracy: `[level.accuracy]`
--- - Level variables: `[level.<variable>]`
--- - Level timers: `[level.<timer>]`
--- - Level timer series: `[level.<timerSeries>.length]`
function Level:updateVariables()
	_Vars:set("level.streak", self.streak)
	_Vars:set("level.accuracy", self:getShotAccuracy())
	for name, variable in pairs(self.variables) do
		_Vars:set("level." .. name, variable)
	end
	for name, timer in pairs(self.timers) do
		_Vars:set("level." .. name, timer)
	end
	for name, timerSeries in pairs(self.timerSeries) do
		_Vars:set("level." .. name .. ".length", #timerSeries)
	end
end

---Ticks all the Level Timers up or down, and all elements of Level Timer Series down.
---Timers which are counting down are capped at 0.
---Timer Series elements which reach 0 are removed.
---@param dt number Time delta in seconds.
function Level:updateTimers(dt)
	-- Timers
	for name, time in pairs(self.timers) do
		if self.startingTimers[name].countDown then
			self:setTimer(name, math.max(time - dt, 0))
		else
			self:setTimer(name, time + dt)
		end
	end
	-- Timer series
	for name, timerSeries in pairs(self.timerSeries) do
		for i = #timerSeries, 1, -1 do
			timerSeries[i] = timerSeries[i] - dt
			if timerSeries[i] <= 0 then
				table.remove(timerSeries, i)
			end
		end
	end
end



---Evaluates a Collectible Generator from its config and returns a list of Collectible IDs (strings) which are generated by this entry.
---@param generator CollectibleGeneratorConfig The Collectible Generator to be generated from.
---@return CollectibleConfig[]
function Level:evaluateCollectibleGeneratorEntry(generator)
	-- Run any present conditions and check them. If they aren't met, this entry returns an empty list.
	if generator.conditions then
		_Vars:set("generator.latestCheckpoint", _Game:getSession():getLatestCheckpoint())
		for i, condition in ipairs(generator.conditions) do
			if not condition:evaluate() then
				_Vars:unset("generator")
				return {}
			end
		end
		_Vars:unset("generator")
	end
	-- Check the entry type and act accordingly.
	if generator.type == "collectible" then
		return {generator.collectible}
	elseif generator.type == "collectibleGenerator" then
		return self:evaluateCollectibleGeneratorEntry(generator.generator)
	elseif generator.type == "combine" then
		local result = {}
		for i, entry in ipairs(generator.entries) do
			local subresult = self:evaluateCollectibleGeneratorEntry(entry)
			for j, subentry in ipairs(subresult) do
				table.insert(result, subentry)
			end
		end
		return result
	elseif generator.type == "repeat" then
		local result = {}
		_Vars:set("generator.latestCheckpoint", _Game:getSession():getLatestCheckpoint())
		for i = 1, generator.count:evaluate() do
			-- Append the results of each roll separately.
			local subresult = self:evaluateCollectibleGeneratorEntry(generator.entry)
			for j, subentry in ipairs(subresult) do
				table.insert(result, subentry)
			end
		end
		_Vars:unset("generator")
		return result
	elseif generator.type == "randomPick" then
		local subresults = {}
		local weights = {}
		for i, entry in ipairs(generator.pool) do
			local subresult = self:evaluateCollectibleGeneratorEntry(entry.entry)
			-- Discard empty results.
			if #subresult > 0 then
				table.insert(subresults, subresult)
				table.insert(weights, entry.weight or 1)
			end
		end
		if #subresults > 0 then
			return subresults[_Utils.weightedRandom(weights)]
		else
			return {}
		end
	end
	return {}
end



---Activates a collectible generator in a given position.
---@param x number The X position where the collectibles will spawn.
---@param y number The Y position where the collectibles will spawn.
---@param entry CollectibleGeneratorConfig The Collectible Generator entry to be evaluated.
function Level:spawnCollectiblesFromEntry(x, y, entry)
	local collectibles = self:evaluateCollectibleGeneratorEntry(entry)
	for i, collectible in ipairs(collectibles) do
		self:spawnCollectible(collectible, x, y)
	end
end



---Adds score to the current Profile, as well as to level's statistics.
---@param score integer The score to be added.
---@param unmultipliedScore integer The unmultiplied score, for extra life calculation.
function Level:grantScore(score, unmultipliedScore)
	self.score = self.score + score
	_Game:getSession():grantScore(score, unmultipliedScore)
end



---Adds one coin to the current Profile and to level's statistics.
function Level:grantCoin()
	self.coins = self.coins + 1
	_Game:getSession():grantCoin()
end



---Adds one gem to the level's statistics.
function Level:grantGem()
	self.gems = self.gems + 1
end



---Executes a Score Event at the given position and returns a number of points calculated for further usage.
---@param scoreEvent ScoreEventConfig The Score Event config to be used for calculation.
---@param pos Vector2? The position where the Score Event should be executed. If not provided, the score text will not be displayed.
---@return integer
function Level:executeScoreEvent(scoreEvent, pos)
	local score = scoreEvent.score:evaluate()
	if _Game:getProfile().ultimatelySatisfyingMode then
		score = math.floor(score * (1 + (_Game:getSession():getUSMNumber() - 1) * 0.2) + 0.5)
	end
	local unmultipliedScore = score
	if not scoreEvent.ignoreDifficultyMultiplier then
		score = score * _Game:getSession():getDifficultyConfig().scoreMultiplier
	end
	score = score * self.scoreMultiplier
	_Vars:set("event.score", score)
	self:grantScore(score, unmultipliedScore)

	-- Display the score text (Floating Text) only if a position is provided.
	if pos then
		local font = scoreEvent.font
		if scoreEvent.fonts then
			-- We pick one of the font options.
			local choice = scoreEvent.fonts.choice:evaluate()
			font = scoreEvent.fonts.options[choice] or scoreEvent.fonts.default
		end
		if font then
			local text = scoreEvent.text and scoreEvent.text:evaluate() or (score > 0 and _Utils.formatNumber(score) or "")
			self:spawnFloatingText(text, pos.x, pos.y, font)
		end
	end
	_Vars:unset("event")

	-- Execute a UI callback.
	_Game.uiManager:executeCallback({
		name = "scoreAdded",
		parameters = {score}
	})

	return score
end



---Adds one sphere to the destroyed sphere counter.
function Level:destroySphere()
	if self.lost then
		return
	end

	self.destroyedSpheres = self.destroyedSpheres + 1
end



---Adds one to the shot counter, which is used to calculate accuracy and to display in the UI.
function Level:markSphereShot()
	self.spheresShot = self.spheresShot + 1
end

---Adds one to the successful shot counter, which is used to calculate accuracy.
function Level:markSuccessfulShot()
	self.successfulShots = self.successfulShots + 1
end



---Returns the percentage of shot spheres which have successfully landed.
---@return number
function Level:getShotAccuracy()
	if self.spheresShot == 0 then
		return 1
	end
	return self.successfulShots / self.spheresShot
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
	self:updateObjectives()
	for i, objective in ipairs(self.objectives) do
		if not objective.reached then
			return false
		end
	end
	return true
end



---Applies an effect to the level.
---@param effect CollectibleEffectConfig The effect data to be applied.
---@param x number? The X position of the effect.
---@param y number? The Y position of the effect.
function Level:applyEffect(effect, x, y)
	if effect.type == "replaceSphere" then
		self.shooter:getSphere(effect.color)
	elseif effect.type == "multiSphere" then
		self.shooter:getMultiSphere(effect.color, effect.count and effect.count:evaluate(), effect.time, effect.removeWhenTimeOut, effect.holdTimeRate)
	elseif effect.type == "removeMultiSphere" then
		self.shooter:removeMultiSphere(effect.removeSpheres)
	elseif effect.type == "speedShot" then
		self.shooter.speedShotTime = effect.time
		self.shooter.speedShotSpeed = effect.speed
	elseif effect.type == "homingBugs" then
		self.shooter.homingBugsTime = effect.time
	elseif effect.type == "speedOverride" then
		for i, path in ipairs(self.map.paths) do
			for j, sphereChain in ipairs(path.sphereChains) do
				sphereChain.speedOverrideBase = effect.speedBase
				sphereChain.speedOverrideMult = effect.speedMultiplier
				sphereChain.speedOverrideDecc = effect.decceleration
				sphereChain.speedOverrideTime = effect.time
			end
		end
	elseif effect.type == "destroySpheres" then
		self:destroySelector(effect.selector, Vec2(x, y), effect.scoreEvent, effect.scoreEventPerSphere, effect.gameEvent, effect.gameEventPerSphere, true)
	elseif effect.type == "spawnPathEntity" then
		local path = self:getMostDangerousPath()
		if path then
			path:spawnPathEntity(effect.pathEntity)
		end
	elseif effect.type == "activateNet" then
		self.netTime = effect.time
		self:spawnNet()
	elseif effect.type == "changeGameSpeed" then
		self.gameSpeed = effect.speed
		self.gameSpeedTime = effect.time
	elseif effect.type == "setStreak" then
		self.streak = effect.streak
	elseif effect.type == "executeScoreEvent" then
		self:executeScoreEvent(effect.scoreEvent, Vec2(x, y))
	elseif effect.type == "executeGameEvent" then
		_Game:executeGameEvent(effect.gameEvent)
	elseif effect.type == "setScoreMultiplier" then
		self.scoreMultiplier = effect.multiplier
		self.scoreMultiplierTime = effect.time
	elseif effect.type == "collectibleRain" then
		table.insert(self.collectibleRains, {count = effect.count:evaluate(), time = 0, delay = effect.delay, generator = effect.collectibleGenerator})
	elseif effect.type == "projectileStorm" then
		table.insert(self.projectileStorms, {count = effect.count:evaluate(), time = 0, delay = effect.delay, projectile = effect.projectile, cancelWhenNoTargetsRemaining = effect.cancelWhenNoTargetsRemaining})
	elseif effect.type == "colorSort" then
		for i, path in ipairs(self.map.paths) do
			for j, sphereChain in ipairs(path.sphereChains) do
				sphereChain:sortColors(effect.sortType, effect.delay, effect.stopWhenTampered)
			end
		end
	elseif effect.type == "grantCoin" then
		self:grantCoin()
	elseif effect.type == "incrementGemStat" then
		self:grantGem()
	end
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
---Returns `nil` if none of the paths are in danger.
---@return Path?
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



---Returns all sphere colors that can spawn on this level on the path.
---@return table
function Level:getSpawnableColors()
	local colors = {}
	for i, path in ipairs(self.map.paths) do
		colors = _Utils.tableUnion(colors, path:getSpawnableColors())
	end
	return colors
end



---Returns currently used color generator data for the Shooter.
---@return ColorGeneratorConfig
function Level:getCurrentColorGenerator()
	if self.danger then
		return self.config.colorGeneratorDanger
	else
		return self.config.colorGeneratorNormal
	end
end



---Returns `true` when there are no more spheres on the board and no more spheres can spawn, too.
---@return boolean
function Level:hasNoMoreSpheres()
	return self:areAllObjectivesReached() and not self.lost and self:getEmpty()
end



---Returns `true` if at least one of the Paths in this Level has a predicted match.
---@return boolean
function Level:isMatchPredicted()
	for i, path in ipairs(self.map.paths) do
		if path:isMatchPredicted() then
			return true
		end
	end
	return false
end



---Resets the cascade combo value for this Level to 0 and emits a `cascadeEnded` UI callback if the values were greater than 0.
function Level:endCascade()
	if self.cascade == 0 and self.cascadeScore == 0 then
		return
	end
	--_Debug:print("level " .. self.cascadeScore)
	_Game.uiManager:executeCallback({
		name = "cascadeEnded",
		parameters = {self.cascade, self.cascadeScore}
	})
	self.cascade = 0
	self.cascadeScore = 0
end



---Returns `true` if there are any shot spheres in this level, `false` otherwise.
---@return boolean
function Level:hasShotSpheres()
	return #self.shotSpheres > 0
end



---Returns `true` if the current level score is the highest in history for the current Profile.
---@return boolean
function Level:hasNewScoreRecord()
	return _Game:getSession():getLevelHighscore(self.score)
end



---Returns `true` if the level has been finished, i.e. there are no more spheres and no more collectibles.
---@return boolean
function Level:getFinish()
	return self:hasNoMoreSpheres() and #self.collectibles == 0 and #self.projectiles == 0
end



---Starts the level music from the beginning.
function Level:restartMusic()
	self.config.music:stop()
	self.config.music:play()
end



---Restarts the current level sequence step.
function Level:retriggerSequenceStep()
	self:jumpToSequenceStep(self.levelSequenceStep)
end

---Advances the level sequence program by one step.
function Level:advanceSequenceStep()
	self:jumpToSequenceStep(self.levelSequenceStep + 1)
end



---Sets the level sequence program to a given step.
---@param stepN integer The step to jump to.
function Level:jumpToSequenceStep(stepN)
	self.levelSequenceStep = stepN
	local step = self.levelSequence[self.levelSequenceStep]
	if step.type == "uiCallback" then
		_Game.uiManager:executeCallback(step.callback)
		if not step.waitUntilFinished then
			self:advanceSequenceStep()
		end
	elseif step.type == "pathEntity" then
		self.levelSequenceVars = {pathID = 1, delay = 0}
	elseif step.type == "gameplay" then
		self.levelSequenceVars = {warmupTime = 0}
		if self.config.warmupLoopSound then
			self.warmupLoop = _Game:playSound(self.config.warmupLoopSound)
		end
	elseif step.type == "waitForCollectibles" then
		self.levelSequenceVars = {}
	elseif step.type == "wait" then
		self.levelSequenceVars = {time = 0}
	elseif step.type == "clearBoard" then
		self.shooter:empty()
		self.netTime = 0
		self:destroyNet()
		self:advanceSequenceStep()
	elseif step.type == "collectibleEffect" then
		for i, effect in ipairs(step.effects) do
			self:applyEffect(effect)
		end
		self:advanceSequenceStep()
	elseif step.type == "executeGameEvent" then
		_Game:executeGameEvent(step.gameEvent)
		self:advanceSequenceStep()
	end
end



---Returns the type of the current level sequence step.
---@return string
function Level:getCurrentSequenceStepType()
	return self.levelSequence[self.levelSequenceStep].type
end

---Returns the data of the current level sequence step.
---@return table
function Level:getCurrentSequenceStep()
	return self.levelSequence[self.levelSequenceStep]
end

---Moves on to the next sequence step if the current step is a UI callback which is waiting.
function Level:continueSequence()
	local step = self:getCurrentSequenceStep()
	if step.type == "uiCallback" and step.waitUntilFinished then
		self:advanceSequenceStep()
	end
end



---Saves the current progress on this Level.
function Level:save()
	local session = _Game:getSession()
	if session then
		session:setLevelSaveData(self:serialize())
	end
end

---Erases saved data from this Level.
function Level:unsave()
	local session = _Game:getSession()
	if session then
		session:setLevelSaveData()
	end
end

---Marks this level as completed and forgets its saved data.
function Level:win()
	local session = _Game:getSession()
	if session then
		session:updateCurrentLevelStats(true, self.score)
		session:setLevelSaveData()
	end
end

---Marks this level as lost and restarts it if there are some lives left. Otherwise, ends the game.
function Level:tryAgain()
	local session = _Game:getSession()
	if session then
		session:updateCurrentLevelStats(false, self.score)
		session:setLevelSaveData()
		if session:getLives() > 0 then
			session:takeLife()
			session:doRollback()
			self:reset()
			self:resetSequence()
		else
			_Game:gameOver()
		end
	else
		-- Just restart the level if the session does not exist.
		self:reset()
		self:resetSequence()
	end
end



---Forfeits the level. The shooter is emptied, and spheres start rushing into the pyramid.
function Level:lose()
	if self:getCurrentSequenceStepType() ~= "gameplay" then
		return
	end
	self.lost = true
	-- empty the shooter
	self.shooter:empty()
	-- delete all shot balls
	for i, shotSphere in ipairs(self.shotSpheres) do
		shotSphere:destroy()
	end
	self.shotSpheres = {}
	-- Start the destruction if the loss type has been configured to do so.
	local failConfig = _Game.configManager.gameplay.sphereBehavior.foulDestroySpheres
	if failConfig.type == "fromEnd" then
		self.failDestructionDelay = failConfig.delay
	end
	-- stop warmup sound
	if self.warmupLoop then
		self.warmupLoop:stop()
	end
	-- play loss sounds
	if self.config.failSound then
		_Game:playSound(self.config.failSound)
	end
	if self.config.failLoopSound then
		self.failLoop = _Game:playSound(self.config.failLoopSound)
	end
	-- update sequence step
	local jumpTo = self.levelSequence[self.levelSequenceStep].onFail
	if jumpTo then
		self:jumpToSequenceStep(jumpTo)
	else
		self:advanceSequenceStep()
	end
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
	for i, projectile in ipairs(self.projectiles) do
		projectile:destroy()
	end
	self.map:destroy()
	self:destroyNet()
	-- Remove all Expression Variables associated with the level.
	_Vars:unset("level")

	-- Stop any music.
	if self.config.music then
		self.config.music:play(0, 1)
	end
	if self.config.dangerMusic then
		self.config.dangerMusic:play(0, 1)
	end
	if self.config.ambientMusic then
		self.config.ambientMusic:play(0, 1)
	end

	if self.warmupLoop then
		self.warmupLoop:stop()
	end
	if self.failLoop then
		self.failLoop:stop()
	end
end



---Resets the Level data.
function Level:reset()
	self.score = 0
	self.coins = 0
	self.gems = 0
	self.streak = 0
	self.cascade = 0
	self.cascadeScore = 0
	self.destroyedSpheres = 0
	self.time = 0

	self.spheresShot = 0
	self.successfulShots = 0
	self.sphereChainsSpawned = 0
	self.maxCascade = 0
	self.maxStreak = 0

	self.shotSpheres = {}
	self.collectibles = {}
	self.projectiles = {}
	self.floatingTexts = {}

	self.danger = false
	self.dangerLoopSound = nil
	self.warningDelay = 0
	self.warningDelayMax = nil
	self.failDestructionDelay = nil

	self.pause = false
	self.canPause = true
	self.lost = false
	self.ended = false

	self.gameSpeed = 1
	self.gameSpeedTime = 0
	self.scoreMultiplier = 1
	self.scoreMultiplierTime = 0
	self.collectibleRains = {}
	self.projectileStorms = {}
	self.netTime = 0
	self:destroyNet()

	self:updateObjectives()

	self.variables = {}
	if self.startingVariables then
		for variable, value in pairs(self.startingVariables) do
			self.variables[variable] = value
		end
	end
	self.timers = {}
	if self.startingTimers then
		for timerName, timer in pairs(self.startingTimers) do
			self.timers[timerName] = timer.value or 0
		end
	end
	self.timerSeries = {}
	if self.startingTimerSeries then
		for timerSeriesName, timerSeries in pairs(self.startingTimerSeries) do
			self.timerSeries[timerSeriesName] = {}
		end
	end

	self.shooter:reset()
	self.colorManager:reset()
end



---Resets the sequence to the first step.
function Level:resetSequence()
	self.levelSequenceStep = 0
	self.levelSequenceVars = nil
	self.levelSequenceLoad = false
	self:jumpToSequenceStep(1)
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



---Returns whether both provided colors can attract or make valid scoring combinations with each other.
---@param color1 integer The first color to be checked against.
---@param color2 integer The second color to be checked against.
---@return boolean
function Level:colorsMatch(color1, color2)
	local sphereConfig1 = _Res:getSphereConfig("spheres/sphere_" .. color1 .. ".json")
	return _Utils.isValueInTable(sphereConfig1.matches, color2)
end



---Selects spheres based on a provided Sphere Selector Config and destroys them, executing any provided Score Events in the process.
---@param sphereSelector SphereSelectorConfig The Sphere Selector that will be used to select the spheres to be destroyed.
---@param pos Vector2? The position used to calculate distances to spheres, and used in Floating Text position, unless `forceEventPosCalculation` is set.
---@param scoreEvent ScoreEventConfig? The Score Event that will be executed once on the whole batch.
---@param scoreEventPerSphere ScoreEventConfig? The Score Event that will be executed separately for each sphere.
---@param gameEvent GameEventConfig? The Game Event which will be executed once on the whole batch.
---@param gameEventPerSphere GameEventConfig? The Game Event which will be executed separately for each sphere.
---@param forceEventPosCalculation boolean? If set, the `pos` argument will be ignored and a new position for the Score Event will be calculated anyways.
function Level:destroySelector(sphereSelector, pos, scoreEvent, scoreEventPerSphere, gameEvent, gameEventPerSphere, forceEventPosCalculation)
	SphereSelectorResult(sphereSelector, pos):destroy(scoreEvent, scoreEventPerSphere, gameEvent, gameEventPerSphere, forceEventPosCalculation)
end



---Selects spheres based on a provided Sphere Selector Config and changes their colors.
---@param hitBehavior table The sphere's Hit Behavior with `selector`, `color` and `particle` (optional) fields.
---@param pos Vector2? The position used to calculate distances to spheres.
function Level:replaceColorSelector(hitBehavior, pos)
	SphereSelectorResult(hitBehavior.selector, pos):changeColor(hitBehavior.color:evaluate(), hitBehavior.particle)
end



---Selects spheres based on a provided Sphere Selector Config and applies a Sphere Effect on them.
---@param hitBehavior table The sphere's Hit Behavior with `selector` and `effect` fields.
---@param pos Vector2? The position used to calculate distances to spheres.
function Level:applyEffectSelector(hitBehavior, pos)
	SphereSelectorResult(hitBehavior.selector, pos):applyEffect(hitBehavior.effect)
end



---Returns a randomly selected sphere, or `nil` if this level does not contain any spheres.
---@param excludeScarabs boolean? If `true`, scarabs will not be counted.
---@param ignoreOffscreen boolean? If `true`, this function will never return an offscreen sphere.
---@param ignoreHidden boolean? If set to `true`, this function will never return a sphere which is in a tunnel.
---@return Sphere?
function Level:getRandomSphere(excludeScarabs, ignoreOffscreen, ignoreHidden)
	local spheres = {}
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					if (not excludeScarabs or sphere.color ~= 0) and (not ignoreOffscreen or not sphere:isOffscreen()) and (not ignoreHidden or not sphere:getHidden()) then
						table.insert(spheres, sphere)
					end
				end
			end
		end
	end
	return spheres[math.random(#spheres)]
end



---Returns the lowest length out of all sphere groups of a single color on the screen.
---This function ignores spheres that are offscreen.
---@return integer?
function Level:getLowestMatchLength()
	local lowest = nil
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local matchLength = sphereGroup:getMatchLengthInChain(l)
					if sphere.color ~= 0 and not sphere:isOffscreen() and (not lowest or lowest > matchLength) then
						lowest = matchLength
						if lowest == 1 then -- can't go any lower
							return 1
						end
					end
				end
			end
		end
	end
	return lowest
end



---Returns a list of spheres which can be destroyed by Lightning Storm the next time it decides to impale a sphere.
---@param matchLength integer? The exact length of a single-color group which will be targeted.
---@param encourageMatches boolean? If `true`, the function will prioritize groups which have the same color on either end.
---@return table
function Level:getSpheresWithMatchLength(matchLength, encourageMatches)
	if not matchLength then return {} end
	local spheres = {}
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local valid = true
					-- Encourage matches: target groups that when destroyed will make a match.
					if encourageMatches then
						local color1, color2 = sphereGroup:getMatchBoundColorsInChain(l)
						valid = color1 and color2 and self:colorsMatch(color1, color2)
					end
					-- If one sphere can be destroyed in a large group to make a big match, don't trim edges to avoid lost opportunities.
					if matchLength > 3 then
						valid = sphereGroup.spheres[l - 1] and sphereGroup.spheres[l + 1] and self:colorsMatch(sphereGroup.spheres[l - 1].color, sphereGroup.spheres[l + 1].color)
					end
					if sphere.color ~= 0 and not sphere:isOffscreen() and sphereGroup:getMatchLengthInChain(l) == matchLength and valid then
						table.insert(spheres, sphere)
					end
				end
			end
		end
	end
	return spheres
end



---Returns a list of spheres constituting towards the largest group matching with the provided color.
---@param color integer? The sphere color which must match with the returned group. If not specified, any color is taken into consideration.
---@param ignoreHidden boolean? If set to `true`, this function will never return a sphere which is in a tunnel.
---@return table
function Level:getSpheresOfBiggestGroupMatchingColor(color, ignoreHidden)
	local spheres = {}
	local topLength = 0
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					if (not color or self:colorsMatch(sphere.color, color)) and not sphere:isOffscreen() and (not ignoreHidden or not sphere:getHidden()) then
						local length = sphereGroup:getMatchLengthInChain(l)
						if length > topLength then
							spheres = {sphere}
							topLength = length
						elseif length == topLength then
							table.insert(spheres, sphere)
						end
					end
				end
			end
		end
	end
	return spheres
end



---Picks a sphere to be destroyed by a lightning storm strike, or `nil` if no spheres are found.
---@return Sphere?
function Level:getLightningStormSphere()
	local length = self:getLowestMatchLength()
	-- first, check for spheres that would make matching easier when destroyed
	local spheres = self:getSpheresWithMatchLength(length, true)
	if #spheres > 0 then
		return spheres[math.random(#spheres)]
	end
	-- if none, then check for any of the shortest groups
	spheres = self:getSpheresWithMatchLength(length)
	if #spheres > 0 then
		return spheres[math.random(#spheres)]
	end
	-- if none, return nothing
	return nil
end



---Picks a sphere to be set as a target by a homing sphere. This will be a sphere from the largest group of the specified color, or a random one in case none of them match.
---@param color integer? The target color for the homing sphere. If not specified, any color can be targeted.
---@return Sphere?
function Level:getHomingBugsSphere(color)
	-- First, check for spheres of the biggest group size.
	local spheres = self:getSpheresOfBiggestGroupMatchingColor(color, true)
	if #spheres > 0 then
		return spheres[math.random(#spheres)]
	end
	-- If none, return a random sphere from the board.
	return self:getRandomSphere(true, true, true)
end



---Destroys the frontmost sphere on all paths, for the purposes of fail animation.
---If the path has no spheres rolled out past the spawn area (offset<0), kills all spheres on that path.
function Level:destroyFrontmostSphere()
	for i, path in ipairs(self.map.paths) do
		if path:getMaxOffset() > 0 then
			local sphereGroup = path:getFirstSphereChain():getFirstSphereGroup()
			sphereGroup:destroySphere(#sphereGroup.spheres)
		else
			for j, sphereChain in ipairs(path.sphereChains) do
				for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
					sphereGroup:destroySpheres(1, #sphereGroup.spheres)
				end
			end
		end
	end
end



---Returns the nearest sphere to the given position along with some extra data.
---The returned table has the following fields:
---
--- - `path` (Path),
--- - `sphereChain` (SphereChain),
--- - `sphereGroup` (SphereGroup),
--- - `sphere` (Sphere),
--- - `sphereID` (integer) - the sphere ID in the group,
--- - `pos` (Vector2) - the position of this sphere,
--- - `dist` (number) - the distance to this sphere,
--- - `half` (boolean) - if `true`, this is a half pointing to the end of the path, `false` if to the beginning of said path.
---@param posX number The X coordinate of the position to be checked against.
---@param posY number The Y coordinate of the position to be checked against.
---@return table
function Level:getNearestSphere(posX, posY)
	local nearestData = {path = nil, sphereChain = nil, sphereGroup = nil, sphereID = nil, sphere = nil, pos = nil, dist = nil, half = nil}
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local spherePos = sphereGroup:getSpherePos(l)
					local sphereAngle = sphereGroup:getSphereAngle(l)
					local sphereHidden = sphereGroup:getSphereHidden(l)

					local sphereDist = _V.length(posX - spherePos.x, posY - spherePos.y)

					local sphereDistAngle = _V.angle(posX - spherePos.x, posY - spherePos.y)
					local sphereAngleDiff = (sphereDistAngle - sphereAngle + math.pi / 2) % (math.pi * 2)
					local sphereHalf = sphereAngleDiff <= math.pi / 2 or sphereAngleDiff > 3 * math.pi / 2
					-- if closer than the closest for now, save it
					if not sphere:isGhost() and not sphereHidden and (not nearestData.dist or sphereDist < nearestData.dist) then
						nearestData.path = path
						nearestData.sphereChain = sphereChain
						nearestData.sphereGroup = sphereGroup
						nearestData.sphereID = l
						nearestData.sphere = sphere
						nearestData.pos = spherePos
						nearestData.dist = sphereDist
						nearestData.half = sphereHalf
					end
				end
			end
		end
	end
	return nearestData
end



---Returns the first sphere to collide with a provided line of sight along with some extra data.
---The returned table has the following fields:
---
--- - `path` (Path),
--- - `sphereChain` (SphereChain),
--- - `sphereGroup` (SphereGroup),
--- - `sphere` (Sphere),
--- - `sphereID` (integer) - the sphere ID in the group,
--- - `pos` (Vector2) - the position of this sphere,
--- - `dist` (number) - the distance to this sphere,
--- - `targetPos` (Vector2) - the collision position (used for i.e. drawing the reticle),
--- - `half` (boolean) - if `true`, this is a half pointing to the end of the path, `false` if to the beginning of said path.
---@param posX number The X coordinate of the starting position of the line of sight.
---@param posY number The Y coordinate of the starting position of the line of sight.
---@param angle number The angle of the line. 0 is up.
---@return table
function Level:getNearestSphereOnLine(posX, posY, angle)
	local nearestData = {path = nil, sphereChain = nil, sphereGroup = nil, sphereID = nil, sphere = nil, pos = nil, dist = nil, targetPos = nil, half = nil}
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local spherePos = sphereGroup:getSpherePos(l)
					local sphereSize = sphereGroup:getSphereSize(l)
					local sphereAngle = sphereGroup:getSphereAngle(l)
					local sphereHidden = sphereGroup:getSphereHidden(l)

					local x, y = _V.rotate(spherePos.x - posX, spherePos.y - posY, -angle)
					local sphereTargetCPosX, sphereTargetCPosY = posX + x, posY + y
					local sphereTargetY = sphereTargetCPosY + math.sqrt((sphereSize / 2) ^ 2 - (posX - sphereTargetCPosX) ^ 2)
					local x, y = _V.rotate(0, sphereTargetY - posY, angle)
					local sphereTargetPosX, sphereTargetPosY = posX + x, posY + y
					local sphereDistX, sphereDistY = posX - sphereTargetCPosX, posY - sphereTargetY

					local sphereDistAngle = _V.angle(posX - spherePos.x, posY - spherePos.y)
					local sphereAngleDiff = (sphereDistAngle - sphereAngle + math.pi / 2) % (math.pi * 2)
					local sphereHalf = sphereAngleDiff <= math.pi / 2 or sphereAngleDiff > 3 * math.pi / 2
					-- if closer than the closest for now, save it
					if not sphere:isGhost() and not sphereHidden and math.abs(sphereDistX) <= sphereSize / 2 and sphereDistY >= 0 and (not nearestData.dist or sphereDistY < nearestData.dist.y) then
						nearestData.path = path
						nearestData.sphereChain = sphereChain
						nearestData.sphereGroup = sphereGroup
						nearestData.sphereID = l
						nearestData.sphere = sphere
						nearestData.pos = spherePos
						nearestData.dist = Vec2(sphereDistX, sphereDistY)
						nearestData.targetPos = Vec2(sphereTargetPosX, sphereTargetPosY)
						nearestData.half = sphereHalf
					end
				end
			end
		end
	end
	return nearestData
end



---Returns a Sphere which has been saved by using `Sphere:getIDs()`.
---This function will only work correctly if the IDs have been saved at the same frame!
---@param ids table The ID table obtained with `Sphere:getIDs()`.
---@return Sphere
function Level:getSphere(ids)
	return self.map.paths[ids.pathID].sphereChains[ids.chainID].sphereGroups[ids.groupID].spheres[ids.sphereID]
end



---Spawns a new Shot Sphere into the level.
---@param shooter Shooter The shooter which has shot the sphere.
---@param posX number The starting X coordinate of the Shot Sphere.
---@param posY number The starting Y coordinate of the Shot Sphere.
---@param angle number Which direction the Shot Sphere should be moving, in radians. 0 is up.
---@param size number The diameter of the Shot Sphere, in pixels.
---@param color integer The sphere ID to be shot.
---@param speed number The sphere speed.
---@param sphereEntity SphereEntity The Sphere Entity that was attached to the Shooter from which this entity is created.
---@param isHoming boolean? If set, the sphere will be homing towards a specific sphere determined by `:getHomingBugsSphere()`.
function Level:spawnShotSphere(shooter, posX, posY, angle, size, color, speed, sphereEntity, isHoming)
	table.insert(self.shotSpheres, ShotSphere(nil, shooter, posX, posY, angle, size, color, speed, sphereEntity, isHoming))
end



---Spawns a new Collectible into the Level.
---@param collectible CollectibleConfig The collectible which should be spawned.
---@param x number Where the Collectible should be spawned at on X axis.
---@param y number Where the Collectible should be spawned at on Y axis.
function Level:spawnCollectible(collectible, x, y)
	table.insert(self.collectibles, Collectible(nil, collectible, x, y))
end



---Spawns a new Projectile into the Level.
---Returns `true` if a Projectile has been successfully spawned, `false` if there were no target spheres to pick from and the projectile did not spawn.
---@param projectile ProjectileConfig The projectile which should be spawned.
---@return boolean
function Level:spawnProjectile(projectile)
	local targetSphere
	if projectile.sphereAlgorithm == "homingBugs" then
		targetSphere = self:getHomingBugsSphere()
	elseif projectile.sphereAlgorithm == "lightningStorm" then
		targetSphere = self:getLightningStormSphere()
	end
	if targetSphere then
		table.insert(self.projectiles, Projectile(nil, projectile, targetSphere))
	end
	return targetSphere ~= nil
end



---Spawns a new FloatingText into the Level.
---@param text string The text to be displayed.
---@param x number The starting X position of this text.
---@param y number The starting Y position of this text.
---@param font Font The font which is going to be used to draw the text.
function Level:spawnFloatingText(text, x, y, font)
	table.insert(self.floatingTexts, FloatingText(text, x, y, font))
end



---Spawns the Net particle and sound, if it doesn't exist yet.
function Level:spawnNet()
	local netConfig = _Game.configManager.gameplay.net
	local w, h = _Game:getNativeResolution()
	local x, y = w / 2, netConfig.posY
	if not self.netParticle then
		self.netParticle = _Game:spawnParticle(_Res:getParticleEffectConfig(netConfig.particle), x, y)
	end
	if not self.netSound then
		self.netSound = _Game:playSound(_Res:getSoundEvent(netConfig.sound), x, y)
	end
end



---Despawns the Net particle and sound, if it exists.
function Level:destroyNet()
	if self.netParticle then
		self.netParticle:destroy()
		self.netParticle = nil
	end
	if self.netSound then
		self.netSound:stop()
		self.netSound = nil
	end
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
	for i, projectile in ipairs(self.projectiles) do
		projectile:draw()
	end
	for i, floatingText in ipairs(self.floatingTexts) do
		floatingText:draw()
	end

	-- local p = Vec2(20, 500)
	-- love.graphics.setColor(1, 1, 1)
	-- love.graphics.print(tostring(self.warningDelay) .. "\n" .. tostring(self.warningDelayMax), p.x, p.y)
end



---Callback from `main.lua`.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button which was pressed.
function Level:mousepressed(x, y, button)
	self.shooter:mousepressed(x, y, button)
end



---Callback from `main.lua`.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button which was released.
function Level:mousereleased(x, y, button)
	self.shooter:mousereleased(x, y, button)
end



---Callback from `main.lua`.
---@param key string The pressed key code.
function Level:keypressed(key)
	self.shooter:keypressed(key)
end



---Callback from `main.lua`.
---@param key string The released key code.
function Level:keyreleased(key)
	self.shooter:keyreleased(key)
end



---Stores all necessary data to save the level in order to load it again with exact same things on board.
---@return table
function Level:serialize()
	local t = {
		score = self.score,
		coins = self.coins,
		gems = self.gems,
		spheresShot = self.spheresShot,
		successfulShots = self.successfulShots,
		sphereChainsSpawned = self.sphereChainsSpawned,
		time = self.time,
		shooter = self.shooter:serialize(),
		shotSpheres = {},
		collectibles = {},
		projectiles = {},
		streak = self.streak,
		maxStreak = self.maxStreak,
		cascade = self.cascade,
		cascadeScore = self.cascadeScore,
		maxCascade = self.maxCascade,
		collectibleRains = {},
		projectileStorms = {},
		netTime = self.netTime,
		destroyedSpheres = self.destroyedSpheres,
		paths = self.map:serialize(),
		lost = self.lost,
		failDestructionDelay = self.failDestructionDelay,
		levelSequenceStep = self.levelSequenceStep,
		levelSequenceVars = self.levelSequenceVars,
		variables = self.variables,
		timers = self.timers,
		timerSeries = self.timerSeries
	}
	for i, shotSphere in ipairs(self.shotSpheres) do
		table.insert(t.shotSpheres, shotSphere:serialize())
	end
	for i, collectible in ipairs(self.collectibles) do
		table.insert(t.collectibles, collectible:serialize())
	end
	for i, projectile in ipairs(self.projectiles) do
		table.insert(t.projectiles, projectile:serialize())
	end
	for i, collectibleRain in ipairs(self.collectibleRains) do
		table.insert(t.collectibleRains, {
			count = collectibleRain.count,
			time = collectibleRain.time,
			delay = collectibleRain.delay.str,
			generator = _Res:getResourceReference(collectibleRain.generator)
		})
	end
	for i, projectileStorm in ipairs(self.projectileStorms) do
		table.insert(t.projectileStorms, {
			count = projectileStorm.count,
			time = projectileStorm.time,
			delay = projectileStorm.delay.str,
			projectile = _Res:getResourceReference(projectileStorm.projectile),
			cancelWhenNoTargetsRemaining = projectileStorm.cancelWhenNoTargetsRemaining
		})
	end
	return t
end



---Restores all data that was saved in the serialization method.
---@param t table The data to be deserialized.
function Level:deserialize(t)
	-- Prepare the counters
	self.colorManager:reset()

	-- Level stats
	self.score = t.score
	self.coins = t.coins
	self.gems = t.gems
	self.spheresShot = t.spheresShot
	self.successfulShots = t.successfulShots
	self.sphereChainsSpawned = t.sphereChainsSpawned
	self.streak = t.streak
	self.maxStreak = t.maxStreak
	self.cascade = t.cascade
	self.cascadeScore = t.cascadeScore
	self.maxCascade = t.maxCascade
	self.destroyedSpheres = t.destroyedSpheres
	self.time = t.time
	self.lost = t.lost
	self.failDestructionDelay = t.failDestructionDelay
	self.levelSequenceStep = t.levelSequenceStep
	self.levelSequenceVars = t.levelSequenceVars
	self.levelSequenceLoad = true
	self.variables = t.variables
	self.timers = t.timers
	self.timerSeries = t.timerSeries
	-- Paths
	self.map:deserialize(t.paths)
	-- We need to resolve the `Sphere.attachedSphere` field here for the loading order reasons.
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local attachedSphere = type(t.paths[i].sphereChains[j].sphereGroups[k].spheres[l]) == "table" and t.paths[i].sphereChains[j].sphereGroups[k].spheres[l].attachedSphere
					if attachedSphere then
						sphere.attachedSphere = self.map.paths[attachedSphere.pathID].sphereChains[attachedSphere.chainID].sphereGroups[attachedSphere.groupID].spheres[attachedSphere.sphereID]
					end
				end
			end
		end
	end
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
	self.projectiles = {}
	for i, tProjectile in ipairs(t.projectiles) do
		table.insert(self.projectiles, Projectile(tProjectile))
	end
	-- Effects
	self.collectibleRains = {}
	for i, tCollectibleRain in ipairs(t.collectibleRains) do
		table.insert(self.collectibleRains, {
			count = tCollectibleRain.count,
			time = tCollectibleRain.time,
			delay = Expression(tCollectibleRain.delay),
			generator = _Res:getCollectibleGeneratorConfig(tCollectibleRain.generator)
		})
	end
	self.projectileStorms = {}
	for i, tProjectileStorm in ipairs(t.projectileStorms) do
		table.insert(self.projectileStorms, {
			count = tProjectileStorm.count,
			time = tProjectileStorm.time,
			delay = Expression(tProjectileStorm.delay),
			projectile = _Res:getProjectileConfig(tProjectileStorm.projectile),
			cancelWhenNoTargetsRemaining = tProjectileStorm.cancelWhenNoTargetsRemaining
		})
	end
	self.netTime = t.netTime
	if self.netTime > 0 then
		self:spawnNet()
	end

	-- Pause
	self:setPause(true)
	self:updateObjectives()
end



return Level
