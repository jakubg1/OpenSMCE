local class = require "com.class"

---Represents a Level. Houses the Map, Shooters, Shot Spheres, Collectibles and Floating Texts. Handles elements such as level objectives and general level event order.
---@class Level
---@overload fun(data):Level
local Level = class:derive("Level")

local Vec2 = require("src.Essentials.Vector2")

local Map = require("src.Game.Map")
local Shooter = require("src.Game.Shooter")
local ColorManager = require("src.Game.ColorManager")
local SphereSelectorResult = require("src.Game.SphereSelectorResult")
local ShotSphere = require("src.Game.ShotSphere")
local Collectible = require("src.Game.Collectible")
local FloatingText = require("src.Game.FloatingText")

local Expression = require("src.Expression")



---Constructs a new Level.
---@param data table The level data, specified in a level config file.
function Level:new(data)
	self.map = Map(self, "maps/" .. data.map, data.pathsBehavior)
	self.shooter = Shooter(data.shooter)
	self.colorManager = ColorManager()

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

	self.music = data.music and _Game.resourceManager:getMusic(data.music)
	self.dangerMusic = data.dangerMusic and _Game.resourceManager:getMusic(data.dangerMusic)
	self.ambientMusic = data.ambientMusic and _Game.resourceManager:getMusic(data.ambientMusic)

	self.dangerSoundName = data.dangerSound or "sound_events/warning.json"
	self.dangerLoopSoundName = data.dangerLoopSound
	self.warmupLoopName = data.warmupLoopSound or "sound_events/spheres_roll.json"
	self.failSoundName = data.failSound or "sound_events/foul.json"
	self.failLoopName = data.failLoopSound or "sound_events/spheres_roll.json"

	self.lightningStormDelay = _Game.configManager.gameplay.lightningStorm and Expression(_Game.configManager.gameplay.lightningStorm.delay)

	self.levelSequence = _Game.configManager.gameplay.levelSequence

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
	self.colorManager:dumpVariables()

	-- Danger sound
	if self.dangerLoopSoundName then
		local d1 = self:getDanger() and not self.lost
		local d2 = self.danger
		if d1 and not d2 then
			self.dangerSound = _Game:playSound(self.dangerLoopSoundName)
		elseif not d1 and d2 then
			self.dangerSound:stop()
			self.dangerSound = nil
		end
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
	for i, storm in ipairs(self.lightningStorms) do
		if storm.count > 0 then
			storm.time = storm.time - dt
			if storm.time <= 0 then
				self:spawnLightningStormPiece()
				storm.count = storm.count - 1
				if storm.count > 0 then
					storm.time = storm.time + self.lightningStormDelay:evaluate()
				end
			end
		end
	end

	-- Remove finished lightning storms.
	for i = #self.lightningStorms, 1, -1 do
		if self.lightningStorms[i].count == 0 then
			table.remove(self.lightningStorms, i)
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



	-- Current sequence step config
	local step = self.levelSequence[self.levelSequenceStep]

	-- No step (when the level hasn't started yet)
	if not step then
		return
	end

	if step.type == "wait" then
		self.levelSequenceVars.time = self.levelSequenceVars.time + dt
		if self.levelSequenceVars.time >= step.delay then
			self:advanceSequenceStep()
		end
	elseif step.type == "waitForCollectibles" then
		if self:getFinish() then
			self:advanceSequenceStep()
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
				currentPath:spawnPathEntity(_Game.resourceManager:getPathEntityConfig(step.pathEntity))
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

	-- Objectives
	self:updateObjectives()
end



---Adjusts which music is playing based on the level's internal state.
function Level:updateMusic()
	local mute = self.levelSequenceStep == 0 or self:getCurrentSequenceStep().muteMusic or self.pause

	if self.dangerMusic then
		-- If the level hasn't started yet, is lost, won or the game is paused,
		-- mute the music.
		if mute then
			self.music:play(0, 1)
			self.dangerMusic:play(0, 1)
		else
			-- Play the music accordingly to the danger flag.
			-- This "if" statement is an experimental feature where the music is sped up when in danger. Works with ASL only.
			-- TODO: Make this configurable.
			if true then
				if self.danger then
					-- TODO: Make the danger music continue instead of starting over if the game has been unpaused.
					if self.dangerMusic.volume == 0 then
						self.dangerMusic:stop()
						self.dangerMusic:play()
					end
					self.music:play(0, 1)
					self.dangerMusic:play(1, 1)
				else
					self.music:play(1, 1)
					self.dangerMusic:play(0, 1)
				end
			else
				if self.danger then
					self.music.instance:setTimeStretch(3)
				else
					self.music:play(1, 1)
					self.music.instance:setTimeStretch(1)
				end
			end
		end
	else
		-- If there's no danger music, then mute it or unmute in a similar fashion.
		if mute then
			self.music:play(0, 1)
		else
			self.music:play(1, 1)
		end
	end

	if self.ambientMusic then
		-- Ambient music plays all the time.
		self.ambientMusic:play(1, 1)
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



---Evaluates a Collectible Generator from its config and returns a list of Collectible IDs (strings) which are generated by this entry.
---@param generator CollectibleGeneratorConfig The Collectible Generator to be generated from.
---@return table[string]
function Level:evaluateCollectibleGeneratorEntry(generator)
	-- Run any present conditions and check them. If they aren't met, this entry returns an empty list.
	if generator.conditions then
		_Vars:setC("generator", "latestCheckpoint", _Game:getCurrentProfile():getLatestCheckpoint())
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
		return {generator.name}
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
		_Vars:setC("generator", "latestCheckpoint", _Game:getCurrentProfile():getLatestCheckpoint())
		_Vars:setC("level", "combo", self.combo)
		for i = 1, generator.count:evaluate() do
			-- Append the results of each roll separately.
			local subresult = self:evaluateCollectibleGeneratorEntry(generator.entry)
			for j, subentry in ipairs(subresult) do
				table.insert(result, subentry)
			end
		end
		_Vars:unset("generator")
		_Vars:unset("level")
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
---@param pos Vector2 The position where the collectibles will spawn.
---@param entry CollectibleGeneratorConfig The Collectible Generator entry to be evaluated.
function Level:spawnCollectiblesFromEntry(pos, entry)
	local collectibles = self:evaluateCollectibleGeneratorEntry(entry)
	for i, collectible in ipairs(collectibles) do
		self:spawnCollectible(pos, collectible)
	end
end



---Adds score to the current Profile, as well as to level's statistics.
---@param score integer The score to be added.
---@param unmultipliedScore integer The unmultiplied score, for extra life calculation.
function Level:grantScore(score, unmultipliedScore)
	self.score = self.score + score
	_Game:getCurrentProfile():grantScore(score, unmultipliedScore)
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



---Executes a Score Event at the given position and returns a number of points calculated for further usage.
---@param scoreEvent ScoreEventConfig The Score Event config to be used for calculation.
---@param pos Vector2? The position where the Score Event should be executed. If not provided, the score text will not be displayed.
---@return integer
function Level:executeScoreEvent(scoreEvent, pos)
	local score = scoreEvent.score:evaluate()
	if _Game:getCurrentProfile().ultimatelySatisfyingMode then
		score = math.floor(score * (1 + (_Game:getCurrentProfile():getUSMNumber() - 1) * 0.2) + 0.5)
	end
	local unmultipliedScore = score
	if not scoreEvent.ignoreDifficultyMultiplier then
		score = score * _Game:getCurrentProfile():getDifficultyConfig().scoreMultiplier
	end
	_Vars:setC("event", "score", score)
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
			self:spawnFloatingText(text, pos, font)
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
---@param pos Vector2? The position of the effect.
function Level:applyEffect(effect, pos)
	if effect.type == "replaceSphere" then
		self.shooter:getSphere(effect.color)
	elseif effect.type == "multiSphere" then
		self.shooter:getMultiSphere(effect.color, effect.count)
	elseif effect.type == "removeMultiSphere" then
		self.shooter:removeMultiSphere()
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
	elseif effect.type == "destroySpheres" then
		self:destroySelector(effect.selector, pos, effect.scoreEvent, effect.scoreEventPerSphere, true)
	elseif effect.type == "spawnPathEntity" then
		local path = self:getMostDangerousPath()
		if path then
			path:spawnPathEntity(effect.pathEntity)
		end
	elseif effect.type == "lightningStorm" then
		table.insert(self.lightningStorms, {count = effect.count, time = 0})
	elseif effect.type == "activateNet" then
		self.netTime = effect.time
		self:spawnNet()
	elseif effect.type == "changeGameSpeed" then
		self.gameSpeed = effect.speed
		self.gameSpeedTime = effect.duration
	elseif effect.type == "setCombo" then
		self.combo = effect.combo
	elseif effect.type == "executeScoreEvent" then
		self:executeScoreEvent(effect.scoreEvent, pos)
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
	-- if no candidate, the lightning storms are over
	if not sphere then
		self.lightningStorms = {}
		return
	end

	-- spawn a particle, add points etc
	local pos = sphere:getPos()
	sphere:dumpVariables("sphere")
	self:executeScoreEvent(_Game.resourceManager:getScoreEventConfig(_Game.configManager.gameplay.lightningStorm.scoreEvent), pos)
	_Game:spawnParticle(_Game.configManager.gameplay.lightningStorm.particle, pos)
	_Game:playSound(_Game.configManager.gameplay.lightningStorm.sound, pos)
	_Vars:unset("sphere")
	-- destroy it
	sphere.sphereGroup:destroySphere(sphere.sphereGroup:getSphereID(sphere))
end



---Picks a sphere to be destroyed by a lightning storm strike, or `nil` if no spheres are found.
---@return Sphere|nil
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
			if not data.hasToExist or self.colorManager:isColorExistent(color) then
				table.insert(pool, color)
			end
		end
		-- Return a random item from the pool.
		if #pool > 0 then
			return pool[math.random(#pool)]
		end

	elseif data.type == "nearEnd" then
		-- Select a random path.
		local path = self:getRandomPath(true, data.pathsInDangerOnly)
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
					if _Utils.isValueInTable(data.colors, color) then
						if math.random() < data.selectChance then
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
		_Game.uiManager:executeCallback("levelStart")
		self:reset()
	else
		_Game:gameOver()
	end
end



---Starts the Level.
function Level:begin()
	self.music:stop()
	self.music:play()
	self:advanceSequenceStep()
end



---Resumes the Level after loading data.
function Level:beginLoad()
	self.music:stop()
	self.music:play()
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
	if step.type == "pathEntity" then
		self.levelSequenceVars = {pathID = 1, delay = 0}
	elseif step.type == "gameplay" then
		self.levelSequenceVars = {warmupTime = 0}
		if self.warmupLoopName then
			self.warmupLoop = _Game:playSound(self.warmupLoopName)
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
	end
end



---Returns the type of the current level sequence step.
---@return string?
function Level:getCurrentSequenceStepType()
	if self.levelSequenceStep == 0 then
		return
	end
	return self.levelSequence[self.levelSequenceStep].type
end

---Returns the data of the current level sequence step.
---@return table?
function Level:getCurrentSequenceStep()
	if self.levelSequenceStep == 0 then
		return
	end
	return self.levelSequence[self.levelSequenceStep]
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
	self.map:destroy()
	self:destroyNet()

	-- Stop any music.
	if self.music then
		self.music:play(0, 1)
	end
	if self.dangerMusic then
		self.dangerMusic:play(0, 1)
	end
	if self.ambientMusic then
		self.ambientMusic:play(0, 1)
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
	self.combo = 0
	self.destroyedSpheres = 0
	self.time = 0

	self.spheresShot = 0
	self.successfulShots = 0
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
	self.lost = false
	self.ended = false

	self.levelSequenceStep = 0
	self.levelSequenceVars = nil

	self.gameSpeed = 1
	self.gameSpeedTime = 0
	self.lightningStorms = {}
	self.netTime = 0
	self:destroyNet()

	self:updateObjectives()

	self.shooter.speedShotTime = 0
	self.colorManager:reset()
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
	-- stop warmup sound
	if self.warmupLoop then
		self.warmupLoop:stop()
	end
	-- play loss sounds
	if self.failSoundName then
		_Game:playSound(self.failSoundName)
	end
	if self.failLoopName then
		self.failLoop = _Game:playSound(self.failLoopName)
	end
	-- update sequence step
	local jumpTo = self.levelSequence[self.levelSequenceStep].onFail
	if jumpTo then
		self:jumpToSequenceStep(jumpTo)
	else
		self:advanceSequenceStep()
	end
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
	return _Utils.isValueInTable(_Game.configManager.spheres[color1].matches, color2)
end



---Selects spheres based on a provided Sphere Selector Config and destroys them, executing any provided Score Events in the process.
---TODO: Change the parameters from strings to actual objects.
---@param sphereSelector SphereSelectorConfig|string The Sphere Selector that will be used to select the spheres to be destroyed.
---@param pos Vector2? The position used to calculate distances to spheres, and used in Floating Text position, unless `forceEventPosCalculation` is set.
---@param scoreEvent ScoreEventConfig|string? The Score Event that will be executed once on the whole batch.
---@param scoreEventPerSphere ScoreEventConfig|string? The Score Event that will be executed separately for each sphere.
---@param forceEventPosCalculation boolean? If set, the `pos` argument will be ignored and a new position for the Score Event will be calculated anyways.
function Level:destroySelector(sphereSelector, pos, scoreEvent, scoreEventPerSphere, forceEventPosCalculation)
	local selector = type(sphereSelector) == "string" and _Game.resourceManager:getSphereSelectorConfig(sphereSelector) or sphereSelector
	local event = scoreEvent and (type(scoreEvent) == "string" and _Game.resourceManager:getScoreEventConfig(scoreEvent) or scoreEvent)
	local eventPerSphere = scoreEventPerSphere and (type(scoreEventPerSphere) == "string" and _Game.resourceManager:getScoreEventConfig(scoreEventPerSphere) or scoreEventPerSphere)
	SphereSelectorResult(selector, pos):destroy(event, eventPerSphere, forceEventPosCalculation)
end



---Selects spheres based on a provided Sphere Selector Config and changes their colors.
---TODO: Change the parameters from strings to actual objects.
---@param sphereSelector string The Sphere Selector that will be used to select the spheres to be destroyed.
---@param pos Vector2? The position used to calculate distances to spheres.
---@param color integer The color that all selected spheres will be changed to.
---@param particle table? A one-time Particle Effect that will be created at every affected sphere.
function Level:replaceColorSelector(sphereSelector, pos, color, particle)
	SphereSelectorResult(_Game.resourceManager:getSphereSelectorConfig(sphereSelector), pos):changeColor(color, particle)
end



---Returns the lowest length out of all sphere groups of a single color on the screen.
---This function ignores spheres that are offscreen.
---@return integer
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
---@param pos Vector2 The position to be checked against.
---@return table
function Level:getNearestSphere(pos)
	local nearestData = {path = nil, sphereChain = nil, sphereGroup = nil, sphereID = nil, sphere = nil, pos = nil, dist = nil, half = nil}
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local spherePos = sphereGroup:getSpherePos(l)
					local sphereAngle = sphereGroup:getSphereAngle(l)
					local sphereHidden = sphereGroup:getSphereHidden(l)

					local sphereDist = (pos - spherePos):len()

					local sphereDistAngle = (pos - spherePos):angle()
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
---@param pos Vector2 The starting position of the line of sight.
---@param angle number The angle of the line. 0 is up.
---@return table
function Level:getNearestSphereOnLine(pos, angle)
	local nearestData = {path = nil, sphereChain = nil, sphereGroup = nil, sphereID = nil, sphere = nil, pos = nil, dist = nil, targetPos = nil, half = nil}
	for i, path in ipairs(self.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local spherePos = sphereGroup:getSpherePos(l)
					local sphereSize = sphereGroup:getSphereSize(l)
					local sphereAngle = sphereGroup:getSphereAngle(l)
					local sphereHidden = sphereGroup:getSphereHidden(l)

					local sphereTargetCPos = (spherePos - pos):rotate(-angle) + pos
					local sphereTargetY = sphereTargetCPos.y + math.sqrt(math.pow(sphereSize / 2, 2) - math.pow(pos.x - sphereTargetCPos.x, 2))
					local sphereTargetPos = (Vec2(pos.x, sphereTargetY) - pos):rotate(angle) + pos
					local sphereDist = Vec2(pos.x - sphereTargetCPos.x, pos.y - sphereTargetY)

					local sphereDistAngle = (pos - spherePos):angle()
					local sphereAngleDiff = (sphereDistAngle - sphereAngle + math.pi / 2) % (math.pi * 2)
					local sphereHalf = sphereAngleDiff <= math.pi / 2 or sphereAngleDiff > 3 * math.pi / 2
					-- if closer than the closest for now, save it
					if not sphere:isGhost() and not sphereHidden and math.abs(sphereDist.x) <= sphereSize / 2 and sphereDist.y >= 0 and (not nearestData.dist or sphereDist.y < nearestData.dist.y) then
						nearestData.path = path
						nearestData.sphereChain = sphereChain
						nearestData.sphereGroup = sphereGroup
						nearestData.sphereID = l
						nearestData.sphere = sphere
						nearestData.pos = spherePos
						nearestData.dist = sphereDist
						nearestData.targetPos = sphereTargetPos
						nearestData.half = sphereHalf
					end
				end
			end
		end
	end
	return nearestData
end



---Spawns a new Shot Sphere into the level.
---@param shooter Shooter The shooter which has shot the sphere.
---@param pos Vector2 Where the Shot Sphere should be spawned at.
---@param angle number Which direction the Shot Sphere should be moving, in radians. 0 is up.
---@param size number The diameter of the Shot Sphere, in pixels.
---@param color integer The sphere ID to be shot.
---@param speed number The sphere speed.
---@param sphereEntity SphereEntity The Sphere Entity that was attached to the Shooter from which this entity is created.
function Level:spawnShotSphere(shooter, pos, angle, size, color, speed, sphereEntity)
	table.insert(self.shotSpheres, ShotSphere(nil, shooter, pos, angle, size, color, speed, sphereEntity))
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
---@param font string|Font Path to the Font or the Font itself which is going to be used.
function Level:spawnFloatingText(text, pos, font)
	table.insert(self.floatingTexts, FloatingText(text, pos, font))
end



---Spawns the Net particle and sound, if it doesn't exist yet.
function Level:spawnNet()
	local netConfig = _Game.configManager.gameplay.net
	local pos = Vec2(_Game:getNativeResolution().x / 2, netConfig.posY)
	if not self.netParticle then
		self.netParticle = _Game:spawnParticle(netConfig.particle, pos)
	end
	if not self.netSound then
		self.netSound = _Game:playSound(netConfig.sound, pos)
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
	for i, floatingText in ipairs(self.floatingTexts) do
		floatingText:draw()
	end

	-- local p = posOnScreen(Vec2(20, 500))
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
		stats = {
			score = self.score,
			coins = self.coins,
			gems = self.gems,
			spheresShot = self.spheresShot,
			successfulShots = self.successfulShots,
			sphereChainsSpawned = self.sphereChainsSpawned,
			maxChain = self.maxChain,
			maxCombo = self.maxCombo
		},
		time = self.time,
		shooter = self.shooter:serialize(),
		shotSpheres = {},
		collectibles = {},
		combo = self.combo,
		lightningStorms = self.lightningStorms,
		netTime = self.netTime,
		destroyedSpheres = self.destroyedSpheres,
		paths = self.map:serialize(),
		lost = self.lost,
		levelSequenceStep = self.levelSequenceStep,
		levelSequenceVars = self.levelSequenceVars
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
	self.colorManager:reset()

	-- Level stats
	self.score = t.stats.score
	self.coins = t.stats.coins
	self.gems = t.stats.gems
	self.spheresShot = t.stats.spheresShot
	self.successfulShots = t.stats.successfulShots
	self.sphereChainsSpawned = t.stats.sphereChainsSpawned
	self.maxChain = t.stats.maxChain
	self.maxCombo = t.stats.maxCombo
	self.combo = t.combo
	self.destroyedSpheres = t.destroyedSpheres
	self.time = t.time
	self.lost = t.lost
	self.levelSequenceStep = t.levelSequenceStep
	self.levelSequenceVars = t.levelSequenceVars
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
	self.lightningStorms = t.lightningStorms
	self.netTime = t.netTime
	if self.netTime > 0 then
		self:spawnNet()
	end

	-- Pause
	self:setPause(true)
	self:updateObjectives()
end



return Level
