local class = require "com.class"

---Represents a single Profile.
---@class Profile
---@overload fun(data, name):Profile
local Profile = class:derive("Profile")



---Constructs a Profile.
---@param data table? Data to be deserialized, if any.
---@param name string The profile name.
function Profile:new(data, name)
	self.name = name

	-- TODO: Consider extracting this variable and associated functions to ProfileSession.lua
	self.session = nil
	self.levels = {}
	self.checkpoints = {}
	self.checkpointsUnlocked = {}
	self.variables = {}

	self.levelSetConfig = _Game.resourceManager:getLevelSetConfig("config/level_set.json")

	-- Generate some shortcut data for checkpoints from the level config data.
	for i, entry in ipairs(self.levelSetConfig.levelOrder) do
		if entry.checkpoint then
			self.checkpoints[entry.checkpoint.id] = {levelID = i, unlockedOnStart = entry.checkpoint.unlockedOnStart}
		end
	end

	if data then
		self:deserialize(data)
	else
		-- This is a new profile. Unlock the starting checkpoints.
		for i, checkpoint in pairs(self.checkpoints) do
			if checkpoint.unlockedOnStart then
				table.insert(self.checkpointsUnlocked, i)
			end
		end
	end
end



-- Core stuff

---Returns the player's session data. This does NOT return a Session instance; they are separate entities.
---@return table
function Profile:getSession()
	return self.session
end



---Returns the player's current level data. This is the raw level data which is written in `config/levels/level_*.json`.
---@return table
function Profile:getLevelData()
	return _Game.configManager.levels[self:getLevelID()]
end



---Returns the player's current level's map data. This is the raw map data which is written in `maps/*/config.json`.
---Returns `nil` if the current level is a UI script entry.
---@return table?
function Profile:getMapData()
	return self:getLevelData() and _Game.configManager.maps[self:getLevelData().map]
end



---Returns the player's current difficulty config.
---@return DifficultyConfig
function Profile:getDifficultyConfig()
	return _Game.resourceManager:getDifficultyConfig(self.session.difficulty)
end

---Returns the player's current life config.
---@return table
function Profile:getLifeConfig()
	return self:getDifficultyConfig().lifeConfig
end



-- Variables

---Sets the player's variable. Used to store various states per profile. They persist after reopening the game.
---@param name string The name of the variable.
---@param value any The value to be stored. Only primitive types are allowed.
function Profile:setVariable(name, value)
	self.variables[name] = value
end



---Retrieves a previously stored profile variable. If it has not been stored, this function will return `nil`.
---@param name string The name of a previously stored variable.
---@return any
function Profile:getVariable(name)
	return self.variables[name]
end



-- Core level stuff
-- Level number: Starts at one, each level and each subsequent entry in randomizers count separately.
-- Level pointer: Starts at one and points towards an entry in the level order.
-- Level ID: ID of a particular level file.
-- Level data: Stores profile-related data per level, such as win/lose count or some other statistics.

---Returns the player's current level number.
---@return integer
function Profile:getLevel()
	-- Count (current level pointer - 1) entries from the level set.
	local n = self:getLevelCountFromEntries(self.session.level - 1)

	return n + self.session.sublevel
end

---Returns the player's current level number as a string.
---@return string
function Profile:getLevelStr()
	return tostring(self:getLevel())
end



---Returns the player's current level pointer value.
---@return integer
function Profile:getLevelPtr()
	return self.session.level
end

---Returns the player's current level pointer value as a string.
---@return string
function Profile:getLevelPtrStr()
	return tostring(self:getLevel())
end



---Returns the player's current level entry.
---@return table
function Profile:getLevelEntry()
	return self.levelSetConfig.levelOrder[self.session.level]
end

---Returns the player's next level entry. If the current level entry is the last one, returns `nil`.
---@return table?
function Profile:getNextLevelEntry()
	return self.levelSetConfig.levelOrder[self.session.level + 1]
end



---Returns the player's current level ID.
---@return integer
function Profile:getLevelID()
	return self.session.levelID
end

---Returns the player's current level ID as a string.
---@return string
function Profile:getLevelIDStr()
	return tostring(self:getLevelID())
end



---Returns the player's current level name.
---@return string
function Profile:getLevelName()
	local entry = self:getLevelEntry()

	if entry.type == "level" then
		return entry.name
	elseif entry.type == "randomizer" then
		return entry.names[self.session.sublevel]
	end
	return "ERROR"
end



---Goes on to a next level, either another one in a subset, or in a main level set.
function Profile:incrementLevel()
	local entry = self:getLevelEntry()

	-- Update the pointers.
	if entry.type == "level" or entry.type == "uiScript" then
		self.session.level = self.session.level + 1
		self:setupLevel()
	elseif entry.type == "randomizer" then
		-- Check whether it's the last sublevel.  If so, get outta there and move on.
		if self.session.sublevel == entry.count then
			self.session.level = self.session.level + 1
			self:setupLevel()
		else
			self.session.sublevel = self.session.sublevel + 1
		end
	end

	-- Generate a new level ID.
	self:generateLevelID()
end



---Generates a new level ID, based on the current entry type and data.
function Profile:generateLevelID()
	local entry = self:getLevelEntry()

	-- Now we are going to generate the level ID from the pool, if this is a randomizer,
	-- or just replace it if it's a normal level.
	if entry.type == "level" then
		self.session.levelID = entry.level
	elseif entry.type == "randomizer" then
		-- Use local data to generate a level.
		if entry.mode == "repeat" then
			self.session.levelID = self.session.sublevelPool[math.random(#self.session.sublevelPool)]
		elseif entry.mode == "noRepeat" then
			local i = math.random(#self.session.sublevelPool)
			self.session.levelID = self.session.sublevelPool[i]
			table.remove(self.session.sublevelPool, i)
		elseif entry.mode == "order" then
			while true do
				local chance = (entry.count - self.session.sublevel + 1) / #self.session.sublevelPool
				local n = self.session.sublevelPool[1]
				table.remove(self.session.sublevelPool, 1)
				if math.random() < chance then
					self.session.levelID = n
					break
				end
			end
		end
	end
end



---Sets up values for a level set entry the level pointer is currently pointing to.
function Profile:setupLevel()
	local entry = self:getLevelEntry()

	self.session.sublevel = 1
	self.session.sublevelPool = {}
	-- If this entry is a randomizer, copy the pool to an internal profile field.
	if entry.type == "randomizer" then
		for i, levelID in ipairs(entry.pool) do
			self.session.sublevelPool[i] = levelID
		end
	end
end



---Returns the checkpoint ID which is assigned to the most recent level compared to the player's current level number.
---@return integer
function Profile:getLatestCheckpoint()
	for i = self.session.level, 1, -1 do
		local entry = self.levelSetConfig.levelOrder[i]
		if entry.checkpoint then
			return entry.checkpoint.id
		end
	end
	-- TODO: What should be returned if none of the checkpoints have been beaten yet?
	return -1000
end



---Returns `true` if the player's next level number is on the checkpoint list.
---@return boolean
function Profile:isCheckpointUpcoming()
	local entry = self:getLevelEntry()

	-- A checkpoint can't be upcoming if we are in the middle of a randomizer section.
	if entry.type == "randomizer" and self.session.sublevel < entry.count then
		return false
	end

	local nextEntry = self:getNextLevelEntry()
	if nextEntry and nextEntry.checkpoint then
		return true
	end
	return false
end



---Returns the player's current level data. This is NOT level data which is stored on any config file!
---The returned level data structure is a table with three entries:
--- - `score` - The currently highest score for this level.
--- - `won` - How many times this level has been beaten.
--- - `lost` - How many times this level has been lost.
---@return table
function Profile:getCurrentLevelData()
	return self.levels[self:getLevelIDStr()]
end

---Overwrites the player's current level data with the given data.
---See `Profile:getCurrentLevelData()` for more information about the data.
---@param data table
function Profile:setCurrentLevelData(data)
	self.levels[self:getLevelIDStr()] = data
end

---Temporary function for UltimatelySatisfyingMode.
---@return integer
function Profile:getUSMNumber()
	return self:getSession() and self:getLevelPtr() or 1
end



---Returns the level number corresponding to the provided checkpoint ID.
---TODO: This should be parsed at the start and stored once.
---@param checkpoint number The checkpoint ID.
---@return integer
function Profile:getCheckpointLevelN(checkpoint)
	local entryN = self.checkpoints[checkpoint].levelID

	return self:getLevelCountFromEntries(entryN - 1) + 1
end



---Returns how many levels the first N level set entries have in total.
---@param entries integer The total number of entries to be considered.
---@return integer
function Profile:getLevelCountFromEntries(entries)
	local n = 0

	-- If it's a single level, count 1.
	-- If it's a randomizer, count that many levels as there are defined in the randomizer.
	for i = 1, entries do
		local entry = self.levelSetConfig.levelOrder[i]
		if entry.type == "level" then
			n = n + 1
		elseif entry.type == "randomizer" then
			n = n + entry.count
		end
	end

	return n
end



-- Score

---Returns the player's current score.
---@return integer
function Profile:getScore()
	return self.session.score
end

---Adds a given amount of points to the player's current score.
---@param score integer The score to be added.
---@param unmultipliedScore integer The unmultiplied score to be added. The Level class generates this value for use in the life system, since Score Events are evaluated there.
function Profile:grantScore(score, unmultipliedScore)
	self.session.score = self.session.score + score
	if self:getLifeConfig().type == "score" then
		self.session.lifeScore = self.session.lifeScore + (self:getLifeConfig().countUnmultipliedScore and unmultipliedScore or score)
		while self.session.lifeScore >= self:getLifeConfig().scorePerLife do
			self:grantLife()
			self.session.lifeScore = self.session.lifeScore - self:getLifeConfig().scorePerLife
		end
	end
end



-- Coins

---Returns the player's current coin count.
---@return integer
function Profile:getCoins()
	return self.session.coins
end

---Sets the player's coin count to the specified value.
---This function does not check for an extra life and does not execute any UI callbacks.
---@param amount integer The new amount of coins.
function Profile:setCoins(amount)
	self.session.coins = amount
end

---Adds one coin to the player's current coin count. If reached 30, the player is granted an extra life, and the coin counter is reset back to 0.
function Profile:grantCoin()
	self.session.coins = self.session.coins + 1
	if self:getLifeConfig().type == "coins" then
		while self.session.coins >= self:getLifeConfig().coinsPerLife do
			self:grantLife()
			self.session.coins = self.session.coins - self:getLifeConfig().coinsPerLife
		end
	end
	_Game.uiManager:executeCallback("newCoin")
end



-- Lives

---Returns the player's current life count.
---@return unknown
function Profile:getLives()
	return self.session.lives
end

---Grants an extra life to the player.
function Profile:grantLife()
	self.session.lives = self.session.lives + 1
	_Game.uiManager:executeCallback("newLife")
end

---Takes one life away from the player and returns `true`, if the player has any. If not, returns `false`.
---@return boolean
function Profile:takeLife()
	-- You can always retry if there is no life system.
	if self:getLifeConfig().type == "none" then
		return true
	end
	-- Otherwise, check if there is a game over.
	if self.session.lives == 0 then
		return false
	end
	self.session.lives = self.session.lives - 1
	-- Return `true` if the player can retry the level.
	return true
end



-- Unlocked checkpoints

---Returns a list of checkpoints this player has unlocked.
---@return table
function Profile:getUnlockedCheckpoints()
	return self.checkpointsUnlocked
end

---Returns whether this player has unlocked a given checkpoint.
---@param n integer The checkpoint ID to be checked.
---@return boolean
function Profile:isCheckpointUnlocked(n)
	return _Utils.isValueInTable(self.checkpointsUnlocked, n)
end

---Unlocks a given checkpoint for the player if it has not been unlocked yet.
---@param n integer The checkpoint ID to be unlocked.
function Profile:unlockCheckpoint(n)
	if self:isCheckpointUnlocked(n) then
		return
	end
	table.insert(self.checkpointsUnlocked, n)
end



-- Game

---Starts a new game for this player, starting from a specified checkpoint.
---@param checkpoint integer The checkpoint ID of the game's starting point.
---@param difficulty string The path to the difficulty resource which is going to be used as a difficulty for this game.
function Profile:newGame(checkpoint, difficulty)
	self.session = {}
	self.session.difficulty = difficulty
	if self:getLifeConfig().type ~= "none" then
		self.session.lives = self:getLifeConfig().startingLives
	end
	self.session.coins = 0
	self.session.score = 0
	if self:getLifeConfig().type == "score" then
		self.session.lifeScore = 0
	end

	self.session.level = self.checkpoints[checkpoint].levelID
	self.session.sublevel = 1
	self.session.sublevelPool = {}
	self.session.levelID = 0
	
	self:setupLevel()
	self:generateLevelID()
end

---Ends a game for the player and removes all its data.
function Profile:deleteGame()
	self.session = nil
end



---Sets the Expression Variables in the `session` context:
--- - `session.lives` - The amount of lives that the player currently has.
--- - `session.coins` - The amount of coins.
--- - `session.score` - The player's current score.
--- - `session.lifeScore` - The player's score. When it reaches a defined amount, an extra life is given.
---
---If the player does not have a game session active, the variables are removed.
function Profile:dumpVariables()
	if self.session then
		_Vars:setC("session", "lives", self.session.lives)
		_Vars:setC("session", "coins", self.session.coins)
		_Vars:setC("session", "score", self.session.score)
		_Vars:setC("session", "lifeScore", self.session.lifeScore)
	else
		_Vars:unset("session")
	end
end



-- Level

---Saves the current score as a rollback score if score rollback is enabled.
function Profile:startLevel()
	-- Save the current score. We will roll back to it if we lose this level.
	if self:getLifeConfig().rollbackScoreAfterFailure then
		self.session.rollbackScore = self.session.score
	end
	if self:getLifeConfig().rollbackCoinsAfterFailure then
		self.session.rollbackCoins = self.session.coins
	end
end



---Increments the level win count, updates the level record if needed and removes the saved level data.
---Does not increment the level itself!
---@param score integer The level score.
function Profile:winLevel(score)
	local levelData = self:getCurrentLevelData() or {score = 0, won = 0, lost = 0}

	levelData.score = math.max(levelData.score, score)
	levelData.won = levelData.won + 1
	self:setCurrentLevelData(levelData)
	self:unsaveLevel()
end



---Advances the profile to the next level.
function Profile:advanceLevel()
	-- Check if beating this level unlocks some checkpoints.
	local checkpoints = self:getLevelEntry().unlockCheckpointsOnBeat
	if checkpoints then
		for i, checkpoint in ipairs(checkpoints) do
			self:unlockCheckpoint(checkpoint)
		end
	end

	self:incrementLevel()
end



---Returns `true` if score given in parameter would yield a new record for the current level.
---@param score integer The score value to be checked against.
---@return boolean
function Profile:getLevelHighscoreInfo(score)
	local levelData = self:getCurrentLevelData()
	return not levelData or score > levelData.score
end



---Increments the level lose count and takes one life. Returns `false` if the player has had already zero lives, per `Profile:takeLife()`.
---@see Profile.takeLife()
---@return boolean
function Profile:loseLevel()
	local levelData = self:getCurrentLevelData() or {score = 0, won = 0, lost = 0}

	levelData.lost = levelData.lost + 1
	self:setCurrentLevelData(levelData)

	local canRetry = self:takeLife()

	-- Rollback the score if defined in the life config.
	if canRetry then
		if self.session.rollbackScore then
			self.session.score = self.session.rollbackScore
		end
		if self.session.rollbackCoins then
			self.session.coins = self.session.rollbackCoins
		end
	end

	return canRetry
end



-- Level saves

---Saves a level to the profile.
---@param t table The serialized level data to be saved.
function Profile:saveLevel(t)
	self.session.levelSaveData = t
end

---Returns a previously saved level from the profile.
---@return table
function Profile:getSavedLevel()
	return self.session.levelSaveData
end

---Removes level save data from this profile.
function Profile:unsaveLevel()
	self.session.levelSaveData = nil
end



-- Highscore

---Writes this profile onto the highscore list using its current score.
---If successful, returns the position on the leaderboard. If not, returns `false`.
---@return integer|boolean
function Profile:writeHighscore()
	local pos = _Game.runtimeManager.highscores:getPosition(self:getScore())
	if not pos then
		return false
	end

	-- returns the position if it got into top 10
	_Game.runtimeManager.highscores:storeProfile(self, pos)
	return pos
end



-- Serialization

---Serializes the Profile's data for saving purposes.
---@return table
function Profile:serialize()
	local t = {
		session = self.session,
		levels = self.levels,
		checkpoints = self.checkpointsUnlocked,
		variables = self.variables,
		ultimatelySatisfyingMode = self.ultimatelySatisfyingMode
	}
	return t
end



---Restores all data which has been saved by the serialization function.
---@param t table The data to be serialized.
function Profile:deserialize(t)
	self.session = t.session
	self.levels = t.levels
	self.checkpointsUnlocked = t.checkpoints
	if t.variables then
		self.variables = t.variables
	end
	self.ultimatelySatisfyingMode = t.ultimatelySatisfyingMode
end



return Profile
