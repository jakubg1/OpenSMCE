local class = require "com.class"

---@class ProfileSession
---@overload fun(profile, data, difficulty, checkpoint):ProfileSession
local ProfileSession = class:derive("ProfileSession")

-- Place your imports here

---Constructs a new Profile Session.
---Represents a saved game, with information about score, lives, level, etc.
---@param profile Profile The Profile this Session belongs to.
---@param data table? Optional savedata to be deserialized. If not specified, it is assumed that a new game is started.
---@param difficulty DifficultyConfig? Difficulty for the new game.
---@param checkpoint integer? The checkpoint ID of the game's starting point.
function ProfileSession:new(profile, data, difficulty, checkpoint)
    self.profile = profile

    if data then
        self:deserialize(data)
    else
        self.difficulty = assert(difficulty, "No difficulty given; you need to specify a difficulty and a checkpoint if you're starting a new game!")
        self.levelSet = self.difficulty.levelSet
        self.lifeConfig = self.difficulty.lifeConfig
        self.checkpointData = self:getCheckpointData()

        self.score = 0
        if self.lifeConfig.type ~= "none" then
            self.lives = self.lifeConfig.startingLives
        end
        self.coins = 0
        if self.lifeConfig.type == "score" then
            self.lifeScore = 0
        end

        assert(checkpoint, "No checkpoint given; you need to specify a difficulty and a checkpoint if you're starting a new game!")
        self.level = self.checkpointData[checkpoint].levelID
        self.sublevel = nil
        self.sublevelPool = nil
        self:setupSublevelPool()
        self.levelID = self:generateLevelID()
        self.levelSaveData = nil
    end
end

--######################################################--
---------------- C O N F I G U R A T I O N ---------------
--######################################################--

---Returns the current difficulty config.
---@return DifficultyConfig
function ProfileSession:getDifficultyConfig()
    return self.difficulty
end

---Returns the current difficulty's life config.
---@return table
function ProfileSession:getLifeConfig()
	return self.lifeConfig
end

--######################################--
---------------- S C O R E ---------------
--######################################--

---Returns the player's current score.
---@return integer
function ProfileSession:getScore()
	return self.score
end

---Adds a given amount of points to the player's current score.
---@param score integer The score to be added.
---@param unmultipliedScore integer The unmultiplied score to be added. The Level class generates this value for use in the life system, since Score Events are evaluated there.
function ProfileSession:grantScore(score, unmultipliedScore)
	self.score = self.score + score
	if self.lifeConfig.type == "score" then
		self.lifeScore = self.lifeScore + (self.lifeConfig.countUnmultipliedScore and unmultipliedScore or score)
		while self.lifeScore >= self.lifeConfig.scorePerLife do
			self:grantLife()
			self.lifeScore = self.lifeScore - self.lifeConfig.scorePerLife
		end
	end
end

--######################################--
---------------- C O I N S ---------------
--######################################--

---Returns the player's current coin count.
---@return integer
function ProfileSession:getCoins()
	return self.coins
end

---Sets the player's coin count to the specified value.
---This function does not check for an extra life and does not execute any UI callbacks.
---@param amount integer The new amount of coins.
function ProfileSession:setCoins(amount)
	self.coins = amount
end

---Adds one coin to the player's current coin count. If reached 30, the player is granted an extra life, and the coin counter is reset back to 0.
---Executes a `newCoin` UI callback and immediately updates the `session.coins` variable.
function ProfileSession:grantCoin()
	self.coins = self.coins + 1
	if self.lifeConfig.type == "coins" then
		while self.coins >= self.lifeConfig.coinsPerLife do
			self:grantLife()
			self.coins = self.coins - self.lifeConfig.coinsPerLife
		end
	end
	_Game.uiManager:executeCallback("newCoin")
	_Vars:set("session.coins", self.coins)
end

--######################################--
---------------- L I V E S ---------------
--######################################--

---Returns the player's current life count.
---@return unknown
function ProfileSession:getLives()
	return self.lives
end

---Grants an extra life to the player and executes a `newLife` UI callback.
function ProfileSession:grantLife()
	self.lives = self.lives + 1
	_Game.uiManager:executeCallback("newLife")
end

---Takes one life away from the player.
function ProfileSession:takeLife()
	-- You can always retry if there is no life system.
	if self.lifeConfig.type == "none" then
		return
	end
	self.lives = self.lives - 1
end

--######################################--
---------------- L E V E L ---------------
--######################################--

---Advances the profile to the next level.
---If beating the current level set entry causes a checkpoint to be unlocked, unlocks a checkpoint on this profile.
function ProfileSession:advanceLevel()
	-- Check if beating this level unlocks some checkpoints.
	local checkpoints = self:getLevelEntry().unlockCheckpointsOnBeat
	if checkpoints then
		for i, checkpoint in ipairs(checkpoints) do
			self:unlockCheckpoint(checkpoint)
		end
	end

	self:incrementLevel()
end

--##############################################--
---------------- L E V E L   S E T ---------------
--##############################################--

---Returns the player's current level number, corresponding to an entry in the level set.
---@return integer
function ProfileSession:getLevel()
	return self.level
end

---Returns the player's current sublevel number.
---Returns `nil` if the current level is not a randomizer.
---@return integer?
function ProfileSession:getSublevel()
	return self.sublevel
end

---Returns the player's current level number, including all previous sublevels.
---@return integer
function ProfileSession:getTotalLevel()
	return self:getLevelCountFromEntries(self.level - 1) + (self.sublevel or 1)
end

---Returns the player's current level set entry.
---@return table
function ProfileSession:getLevelEntry()
	return self.levelSet.levelOrder[self.level]
end

---Returns the player's next level set entry. If the current level set entry is the last one, returns `nil`.
---@return table?
function ProfileSession:getNextLevelEntry()
	return self.levelSet.levelOrder[self.level + 1]
end

---Returns the player's current level's configuration.
---@return LevelConfig
function ProfileSession:getLevelData()
	return self.levelID
end

---Returns a string reference to the player's current level config.
---@return string
function ProfileSession:getLevelID()
	return _Game.resourceManager:getResourceReference(self.levelID)
end

---Returns the player's current level's map data. This is the raw map data which is written in `maps/*/config.json`.
---Returns `nil` if the current level is a UI script entry.
---@return table?
function ProfileSession:getMapData()
	return self.levelID and _Game.configManager.maps[self.levelID.map]
end

---Returns the player's current level set entry name.
---@return string
function ProfileSession:getLevelName()
	local entry = self:getLevelEntry()
	if entry.type == "level" then
		return entry.name
	elseif entry.type == "randomizer" then
		return entry.names[self.sublevel]
	end
	error("Invalid level entry type")
end

---Returns how many sublevels the first N levels have in total.
---@param levels integer The total number of levels to be considered.
---@return integer
function ProfileSession:getLevelCountFromEntries(levels)
	return self.profile:getLevelCountFromEntries(self.levelSet, levels)
end

---Advances one level in the level entry list, or one sublevel, if the level has more sublevels.
function ProfileSession:incrementLevel()
	local entry = self:getLevelEntry()
	-- Update the pointers.
	if entry.type == "level" or entry.type == "uiScript" then
		self.level = self.level + 1
		self:setupSublevelPool()
	elseif entry.type == "randomizer" then
		-- Check whether it's the last sublevel.  If so, get outta there and move on.
		if self.sublevel == entry.count then
			self.level = self.level + 1
			self:setupSublevelPool()
		else
			self.sublevel = self.sublevel + 1
		end
	end
	-- Generate a new level ID.
	self.levelID = self:generateLevelID()
end

---Generates a new level ID, based on the current level set entry type and data.
---The returned level is removed from the pool if the current entry is configured so.
---@return LevelConfig
function ProfileSession:generateLevelID()
	local entry = self:getLevelEntry()

	-- Now we are going to generate the level ID from the pool, if this is a randomizer,
	-- or just replace it if it's a normal level.
	if entry.type == "level" then
		return entry.level
	elseif entry.type == "randomizer" then
		-- Use local data to generate a level.
		if entry.mode == "repeat" then
			return self.sublevelPool[math.random(#self.sublevelPool)]
		elseif entry.mode == "noRepeat" then
			return table.remove(self.sublevelPool, math.random(#self.sublevelPool))
		elseif entry.mode == "order" then
			while true do
				local chance = (entry.count - self.sublevel + 1) / #self.sublevelPool
				local sublevel = self.sublevelPool[1]
				table.remove(self.sublevelPool, 1)
				if math.random() < chance then
					return sublevel
				end
			end
		end
	end
	error("Invalid level entry type")
end

---Sets up sublevel values for the current level set entry if this entry is a randomizer.
---Otherwise, the sublevel values are cleared.
---@private
function ProfileSession:setupSublevelPool()
	local entry = self:getLevelEntry()

	-- If this entry is a randomizer, copy the pool to an internal profile field.
	if entry.type == "randomizer" then
		self.sublevel = 1
		self.sublevelPool = {}
		for i, levelID in ipairs(entry.pool) do
			self.sublevelPool[i] = levelID
		end
	else
		self.sublevel = nil
		self.sublevelPool = nil
	end
end

--##################################################--
---------------- C H E C K P O I N T S ---------------
--##################################################--

---Returns a list of checkpoints this player has unlocked for this game.
---@return integer[]
function ProfileSession:getUnlockedCheckpoints()
	return self.profile:getUnlockedCheckpoints(self.levelSet)
end

---Returns whether this player has unlocked a given checkpoint in this game.
---@param n integer The checkpoint ID to be checked.
---@return boolean
function ProfileSession:isCheckpointUnlocked(n)
	return self.profile:isCheckpointUnlocked(self.levelSet, n)
end

---Unlocks a given checkpoint for the player if it has not been unlocked yet in this game.
---@param n integer The checkpoint ID to be unlocked.
function ProfileSession:unlockCheckpoint(n)
	self.profile:unlockCheckpoint(self.levelSet, n)
end

---Generates checkpoint data based on the current level set. Useful for lookup.
---@return table<integer, {levelID: integer, unlockedOnStart: boolean}>
function ProfileSession:getCheckpointData()
	return self.profile:getCheckpointData(self.levelSet)
end

---Returns the total level number corresponding to the provided checkpoint ID.
---TODO: This should be parsed at the start and stored once.
---@param n number The checkpoint ID.
---@return integer
function ProfileSession:getCheckpointLevelN(n)
	return self.profile:getCheckpointLevelN(self.levelSet, n)
end

---Returns a checkpoint ID which is assigned to the most recent level set entry which has one.
---If none of the checkpoints have been beaten yet, returns `nil`.
---@return integer?
function ProfileSession:getLatestCheckpoint()
	for i = self.level, 1, -1 do
		local entry = self.levelSet.levelOrder[i]
		if entry.checkpoint then
			return entry.checkpoint.id
		end
	end
end

---Returns `true` if the player's next level set entry has a checkpoint (and the player is not in the middle of a list of sublevels).
---@return boolean
function ProfileSession:isCheckpointUpcoming()
	-- A checkpoint can't be upcoming if we are in the middle of a randomizer section.
	local entry = self:getLevelEntry()
	if entry.type == "randomizer" and self.sublevel < entry.count then
		return false
	end

	local nextEntry = self:getNextLevelEntry()
	return nextEntry and nextEntry.checkpoint ~= nil or false
end

--############################################################--
---------------- L E V E L   S T A T I S T I C S ---------------
--############################################################--

---Returns the player's current level statistics.
---Returns `nil` if the player currently has no session in progress.
---@return LevelStatistics?
function ProfileSession:getCurrentLevelStats()
	return self.profile.levelStats[self:getLevelID()]
end

---Overwrites the player's current level statistics with the provided statistics.
---@param data LevelStatistics The statistics to be set for the level.
function ProfileSession:setCurrentLevelStats(data)
	self.profile.levelStats[self:getLevelID()] = data
end

---Updates the player's current level statistics by adding one to either win or loss count and updating the highscore if beaten.
---If no entry is available for that level's statistics yet, a new one is made.
---@param won boolean Whether the level has been won (`true`) or lost (`false`).
---@param score integer The score result for this level. Ignored if the level was lost.
function ProfileSession:updateCurrentLevelStats(won, score)
	local stats = self:getCurrentLevelStats() or {score = 0, won = 0, lost = 0}
	if won then
		stats.won = stats.won + 1
		stats.score = math.max(stats.score, score)
	else
		stats.lost = stats.lost + 1
	end
	self:setCurrentLevelStats(stats)
end

---Returns `true` if score given in parameter would yield a new record for the current level.
---@param score integer The score value to be checked against.
---@return boolean
function ProfileSession:getLevelHighscore(score)
	local levelData = self:getCurrentLevelStats()
	return not levelData or score > levelData.score
end

--############################################--
---------------- R O L L B A C K ---------------
--############################################--

---Saves the current score and/or coins as rollback values if rollback is enabled.
function ProfileSession:saveRollback()
	if self.lifeConfig.rollbackScoreAfterFailure then
		self.rollbackScore = self.score
	end
	if self.lifeConfig.rollbackCoinsAfterFailure then
		self.rollbackCoins = self.coins
	end
end

---Restores the saved score and/or coins from rollback values if rollback is enabled.
function ProfileSession:doRollback()
    if self.rollbackScore then
        self.score = self.rollbackScore
    end
    if self.rollbackCoins then
        self.coins = self.rollbackCoins
    end
end

--################################################--
---------------- H I G H S C O R E S ---------------
--################################################--

---Writes this profile onto the highscore list using its current score.
---If successful, returns the position on the leaderboard. If not, returns `nil`.
---@return integer?
function ProfileSession:writeHighscore()
	local pos = _Game.runtimeManager.highscores:getPosition(self.score)
	if not pos then
		return
	end
	_Game.runtimeManager.highscores:storeEntry(pos, self.profile.name, self.score, self:getLevelName())
	return pos
end

--##############################################--
---------------- V A R I A B L E S ---------------
--##############################################--

---Sets the Expression Variables in the `session` context:
--- - `session.lives` - The amount of lives that the player currently has.
--- - `session.coins` - The amount of coins.
--- - `session.score` - The player's current score.
--- - `session.lifeScore` - The player's score. When it reaches a defined amount, an extra life is given.
function ProfileSession:dumpVariables()
    _Vars:set("session.lives", self.lives)
    _Vars:set("session.coins", self.coins)
    _Vars:set("session.score", self.score)
    _Vars:set("session.lifeScore", self.lifeScore)
end

---Temporary function for UltimatelySatisfyingMode.
---@return integer
function ProfileSession:getUSMNumber()
	return self:getLevel() or 1
end


--##########################################################--
---------------- L E V E L   S A V E   D A T A ---------------
--##########################################################--

---Sets (or unsets) level save data for this Session to store.
---@param levelSaveData table? Level save data. Call without this parameter to clear level save data.
function ProfileSession:setLevelSaveData(levelSaveData)
    self.levelSaveData = levelSaveData
end

---Returns previously saved level save data, if it is currently stored.
---@return table?
function ProfileSession:getLevelSaveData()
    return self.levelSaveData
end

--######################################################--
---------------- S E R I A L I Z A T I O N ---------------
--######################################################--

---Serializes this session's data for later use.
---@return table
function ProfileSession:serialize()
    local t = {
        difficulty = _Game.resourceManager:getResourceReference(self.difficulty),
        score = self.score,
        lives = self.lives,
        coins = self.coins,
        lifeScore = self.lifeScore,
        level = self.level,
        sublevel = self.sublevel,
        sublevelPool = self.sublevelPool,
        levelID = _Game.resourceManager:getResourceReference(self.levelID),
        levelSaveData = self.levelSaveData
    }
    return t
end

---Deserializes previously saved session data and restores its state.
---@param t table The data to be deserialized.
function ProfileSession:deserialize(t)
    self.difficulty = _Game.resourceManager:getDifficultyConfig(t.difficulty)
    self.levelSet = self.difficulty.levelSet
    self.lifeConfig = self.difficulty.lifeConfig
    self.checkpointData = self:getCheckpointData()
    self.score = t.score
    self.lives = t.lives
    self.coins = t.coins
    self.lifeScore = t.lifeScore
    self.level = t.level
    self.sublevel = t.sublevel
    self.sublevelPool = t.sublevelPool
    self.levelID = _Game.resourceManager:getLevelConfig(t.levelID)
    self.levelSaveData = t.levelSaveData
end

return ProfileSession