local class = require "com/class"
local Profile = class:derive("Profile")

function Profile:new(data, name)
	self.name = name

	self.levels = {}
	self.checkpoints = {1}
	self.variables = {}

	if data then
		self:deserialize(data)
	end
end



-- Core stuff

function Profile:getSession()
	return self.session
end

function Profile:getLevelData()
	-- Returns what is written in levels/*.json.
	return game.configManager.levels[self:getLevelPath()]
end

function Profile:getMapData()
	return game.configManager.maps[self:getLevelData().map]
end



-- Variables

function Profile:setVariable(name, value)
	self.variables[name] = value
end

function Profile:getVariable(name)
	return self.variables[name]
end



-- Core level stuff

function Profile:getLevel()
	return self.session.level
end

function Profile:getLevelStr()
	return tostring(self.session.level.journey) .. "," .. tostring(self.session.level.level)
end

function Profile:getNextLevel()
	local l = {journey = self.session.level.journey, level = self.session.level.level}

	if self:getLevelsInJourney(l.journey) == l.level then
		-- advance to next journey
		l.journey = game.configManager.levelSet.journeys[l.journey].nextJourney
		l.level = 1
	else
		l.level = l.level + 1
	end

	return l
end

function Profile:getLevelPath()
	local l = self.session.level
	return game.configManager.levelSet.journeys[l.journey].levels[l.level]
end

function Profile:setJourney(journey)
	self.session.level.journey = journey
end

function Profile:getLevelsInJourney(journey)
	return #game.configManager.levelSet.journeys[journey].levels
end

function Profile:incrementLevel()
	self.session.level = self:getNextLevel()
end

function Profile:getCurrentJourney()
	return game.configManager.levelSet.journeys[self.session.level.journey]
end


function Profile:getCurrentLevelData()
	return self.levels[self:getLevelStr()]
end

function Profile:setCurrentLevelData(data)
	self.levels[self:getLevelStr()] = data
end



-- Score

function Profile:getScore()
	return self.session.score
end

function Profile:grantScore(score)
	if self.ultimatelySatisfyingMode then
		self.session.score = self.session.score + score * (1 + (self.session.level - 1) * 0.2)
	else
		self.session.score = self.session.score + score
	end
end



-- Coins

function Profile:getCoins()
	return self.session.coins
end

function Profile:grantCoin()
	self.session.coins = self.session.coins + 1
	if self.session.coins == 30 then self:grantLife() end
	game.uiManager:executeCallback("newCoin")
end



-- Lives

function Profile:getLives()
	return self.session.lives
end

function Profile:grantLife()
	self.session.lives = self.session.lives + 1
	self.session.coins = 0
	game.uiManager:executeCallback("newLife")
end

function Profile:takeLife()
	if self.session.lives == 0 then return false end
	self.session.lives = self.session.lives - 1
	-- returns true if the player can retry
	return true
end



-- Unlocked checkpoints

function Profile:getUnlockedCheckpoints()
	return self.checkpoints
end

function Profile:isCheckpointUnlocked(n)
	for i, o in ipairs(self.checkpoints) do
		if n == o then
			return true
		end
	end
	return false
end

function Profile:unlockCheckpoint(n)
	if self:isCheckpointUnlocked(n) then return end
	table.insert(self.checkpoints, n)
end



-- General

function Profile:newGame(checkpoint)
	self.session = {}
	self.session.lives = 2
	self.session.coins = 0
	self.session.score = 0
	self.session.difficulty = 1

	self.session.level = {}
	self.session.level.journey = game.configManager.levelSet.checkpoints[checkpoint or 1].journey
	self.session.level.level = game.configManager.levelSet.checkpoints[checkpoint or 1].level
end

function Profile:deleteGame()
	self.session = nil
end



-- Level

function Profile:winLevel(score)
	local levelData = self:getCurrentLevelData() or {score = 0, won = 0, lost = 0}

	levelData.score = math.max(levelData.score, score)
	levelData.won = levelData.won + 1
	self:setCurrentLevelData(levelData)
	self:unsaveLevel()
end

function Profile:advanceLevel()
	self:incrementLevel()
	game:playSound("sound_events/level_advance.json")
	-- TODO: HARDCODED - make it more flexible
	-- specifically, in this case we need more data in the future about levels:
	-- when do we unlock or lock checkpoints
	if self:getLevel().level == 1 then
		self:unlockCheckpoint(self:getLevel().journey)
	end
end

function Profile:getLevelHighscoreInfo(score)
	-- Returns true if score given in parameter would yield a new record for the current level.
	local levelData = self:getCurrentLevelData()
	return not levelData or score > levelData.score
end

function Profile:loseLevel()
	local levelData = self:getCurrentLevelData() or {score = 0, won = 0, lost = 0}

	levelData.lost = levelData.lost + 1
	self:setCurrentLevelData(levelData)

	local canRetry = self:takeLife()

	return canRetry
end

function Profile:saveLevel(t)
	self.session.levelSaveData = t
end

function Profile:getSavedLevel()
	return self.session.levelSaveData
end

function Profile:unsaveLevel()
	self.session.levelSaveData = nil
end



function Profile:writeHighscore()
	local pos = game.runtimeManager.highscores:getPosition(self:getScore())
	if not pos then return false end

	-- returns the position if it got into top 10
	game.runtimeManager.highscores:storeProfile(self, pos)
	return pos
end



-- Serialization

function Profile:serialize()
	local t = {
		session = self.session,
		levels = self.levels,
		checkpoints = self.checkpoints,
		variables = self.variables,
		ultimatelySatisfyingMode = self.ultimatelySatisfyingMode
	}
	return t
end

function Profile:deserialize(t)
	self.session = t.session
	self.levels = t.levels
	self.checkpoints = t.checkpoints
	if t.variables then
		self.variables = t.variables
	end
	self.ultimatelySatisfyingMode = t.ultimatelySatisfyingMode
end



return Profile
