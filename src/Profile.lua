local class = require "com/class"
local Profile = class:derive("Profile")

function Profile:new(data, name)
	self.name = name

	self.levels = {}
	self.checkpoints = {}
	self.variables = {}

	if data then
		self:deserialize(data)
	else
		for i, checkpoint in ipairs(_Game.configManager.levelSet.startCheckpoints) do
			self.checkpoints[i] = checkpoint
		end
	end
end



-- Core stuff

function Profile:getSession()
	return self.session
end

function Profile:getLevelData()
	-- Returns what is written in config/levels/level_*.json.
	return _Game.configManager.levels[self:getLevelID()]
end

function Profile:getMapData()
	return _Game.configManager.maps[self:getLevelData().map]
end



-- Variables

function Profile:setVariable(name, value)
	self.variables[name] = value
end

function Profile:getVariable(name)
	return self.variables[name]
end



-- Core level stuff
-- Level number: Starts at one and points towards an entry in the level order.
-- Level ID: ID of a particular level file.
-- Level data: Stores profile-related data per level, such as win/lose count or some other statistics.

-- Returns the player's current level number.
function Profile:getLevel()
	return self.session.level
end

-- Returns the player's current level number as a string.
function Profile:getLevelStr()
	return tostring(self.session.level)
end

-- Returns the player's current level entry.
function Profile:getLevelEntry()
	return _Game.configManager.levelSet.level_order[self.session.level]
end

-- Returns the player's current level ID.
function Profile:getLevelID()
	return self:getLevelEntry().level
end

-- Returns the player's current level ID as a string.
function Profile:getLevelIDStr()
	return tostring(self:getLevelID())
end

-- Adds one to the player's current level number.
function Profile:incrementLevel()
	self.session.level = self.session.level + 1
end

-- Returns the checkpoint ID which is assigned to the most recent level
-- compared to the player's current level number.
function Profile:getLatestCheckpoint()
	local checkpoint = nil
	local diff = nil

	for i, level in ipairs(_Game.configManager.levelSet.checkpoints) do
		if level == self.session.level then
			return i
		end
		local d = self.session.level - level
		if d > 0 and (not diff or diff > d) then
			checkpoint = i
			diff = d
		end
	end

	return checkpoint
end

-- Returns true if the player's next level number is on the checkpoint list.
function Profile:isCheckpointUpcoming()
	for i, level in ipairs(_Game.configManager.levelSet.checkpoints) do
		if level == self.session.level + 1 then
			return true
		end
	end
	return false
end


-- Returns the player's current level data.
function Profile:getCurrentLevelData()
	return self.levels[self:getLevelIDStr()]
end

-- Overwrites the player's current level data with the given data.
function Profile:setCurrentLevelData(data)
	self.levels[self:getLevelIDStr()] = data
end



-- Score

function Profile:getScore()
	return self.session.score
end

function Profile:grantScore(score)
	if self.ultimatelySatisfyingMode then
		self.session.score = self.session.score + score * (1 + (self:getLevelNumber() - 1) * 0.2)
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
	_Game.uiManager:executeCallback("newCoin")
end



-- Lives

function Profile:getLives()
	return self.session.lives
end

function Profile:grantLife()
	self.session.lives = self.session.lives + 1
	self.session.coins = 0
	_Game.uiManager:executeCallback("newLife")
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
	if self:isCheckpointUnlocked(n) then
		return
	end
	table.insert(self.checkpoints, n)
end



-- General

function Profile:newGame(checkpoint)
	self.session = {}
	self.session.lives = 2
	self.session.coins = 0
	self.session.score = 0
	self.session.difficulty = 1

	self.session.level = _Game.configManager.levelSet.checkpoints[checkpoint]
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
	-- Check if beating this level unlocks some checkpoints.
	local checkpoints = self:getLevelEntry().unlock_checkpoints_on_beat
	if checkpoints then
		for i, checkpoint in ipairs(checkpoints) do
			self:unlockCheckpoint(checkpoint)
		end
	end

	self:incrementLevel()
	_Game:playSound("sound_events/level_advance.json")
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
	local pos = _Game.runtimeManager.highscores:getPosition(self:getScore())
	if not pos then return false end

	-- returns the position if it got into top 10
	_Game.runtimeManager.highscores:storeProfile(self, pos)
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
