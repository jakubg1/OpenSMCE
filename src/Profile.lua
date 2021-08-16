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

function Profile:getMapData()
	return game.configManager.maps[game.configManager.levels[self:getLevel()].map]
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

function Profile:setLevel(level)
	self.session.level = level
end

function Profile:incrementLevel()
	self:setLevel(self:getLevel() + 1)
end


function Profile:getCurrentLevelConfig()
	return game.configManager.config.levels[self:getLevel()]
end

function Profile:getNextLevelConfig()
	return game.configManager.config.levels[self:getLevel() + 1]
end

function Profile:getCurrentCheckpointConfig()
	return game.configManager.config.checkpoints[self:getCurrentLevelConfig().stage]
end


function Profile:getCurrentLevelData()
	return self.levels[tostring(self:getLevel())]
end

function Profile:setCurrentLevelData(data)
	self.levels[tostring(self:getLevel())] = data
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
	self:setLevel(game.configManager.config.checkpoints[checkpoint or 1].level)
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
	game:playSound("level_advance")
	if self:getCurrentLevelConfig().checkpoint > 0 then
		self:unlockCheckpoint(self:getCurrentLevelConfig().checkpoint)
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
