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
        assert(checkpoint, "No checkpoint given; you need to specify a difficulty and a checkpoint if you're starting a new game!")
        self.score = 0
        if self:getLifeConfig().type ~= "none" then
            self.lives = self:getLifeConfig().startingLives
        end
        self.coins = 0
        if self:getLifeConfig().type == "score" then
            self.lifeScore = 0
        end

        self.level = self.profile.checkpoints[checkpoint].levelID
        self.sublevel = 1
        self.sublevelPool = {}
        self.levelID = nil
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
	return self.difficulty.lifeConfig
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
	if self:getLifeConfig().type == "score" then
		self.lifeScore = self.lifeScore + (self:getLifeConfig().countUnmultipliedScore and unmultipliedScore or score)
		while self.lifeScore >= self:getLifeConfig().scorePerLife do
			self:grantLife()
			self.lifeScore = self.lifeScore - self:getLifeConfig().scorePerLife
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
	if self:getLifeConfig().type == "coins" then
		while self.coins >= self:getLifeConfig().coinsPerLife do
			self:grantLife()
			self.coins = self.coins - self:getLifeConfig().coinsPerLife
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

---Takes one life away from the player and returns `true`, if the player has any. If not, returns `false`.
---@return boolean
function ProfileSession:takeLife()
	-- You can always retry if there is no life system.
	if self:getLifeConfig().type == "none" then
		return true
	end
	-- Otherwise, check if there is a game over.
	if self.lives == 0 then
		return false
	end
	self.lives = self.lives - 1
	-- Return `true` if the player can retry the level.
	return true
end

--############################################--
---------------- R O L L B A C K ---------------
--############################################--

---Saves the current score and/or coins as rollback values if rollback is enabled.
function ProfileSession:saveRollback()
	if self:getLifeConfig().rollbackScoreAfterFailure then
		self.rollbackScore = self.score
	end
	if self:getLifeConfig().rollbackCoinsAfterFailure then
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