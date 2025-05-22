local class = require "com.class"

---Represents a single Profile.
---@class Profile
---@overload fun(data, name):Profile
local Profile = class:derive("Profile")

local ProfileSession = require("src.Game.ProfileSession")

---Constructs a Profile.
---@param data table? Data to be deserialized, if any.
---@param name string The profile name.
function Profile:new(data, name)
	self.name = name

	self.session = nil

	---The level statistics structure is a table with three entries:
	--- - `score` - The currently highest score for this level.
	--- - `won` - How many times this level has been beaten.
	--- - `lost` - How many times this level has been lost.
	---@alias LevelStatistics {score: integer, won: integer, lost: integer}
	---@type table<integer, LevelStatistics>
	self.levelStats = {}
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




---Returns the player's current level's map data. This is the raw map data which is written in `maps/*/config.json`.
---Returns `nil` if the current level is a UI script entry.
---@return table?
function Profile:getMapData()
	return self:getLevelData() and _Game.configManager.maps[self:getLevelData().map]
end

--##############################################--
---------------- V A R I A B L E S ---------------
--##############################################--

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

--################################################--
---------------- L E V E L   C O R E ---------------
--################################################--

---Returns the player's current level number, including all previous sublevels.
---@return integer
function Profile:getTotalLevel()
	return self:getLevelCountFromEntries(self.session.level - 1) + (self.session.sublevel or 1)
end

---Returns the player's current level number, corresponding to an entry in the level set.
---@return integer
function Profile:getLevel()
	return self.session.level
end

---Returns the player's current sublevel number.
---Returns `nil` if the current level is not a randomizer.
---@return integer?
function Profile:getSublevel()
	return self.session.sublevel
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

---Returns the player's current level's configuration.
---@return LevelConfig
function Profile:getLevelData()
	return self.session.levelID
end

---Returns a string reference to the player's current level config.
---@return string
function Profile:getLevelID()
	return _Game.resourceManager:getResourceReference(self.session.levelID)
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
	error("Invalid level entry type")
end

---Goes on to a next level, either another one in a subset, or in a main level set.
function Profile:incrementLevel()
	local entry = self:getLevelEntry()
	-- Update the pointers.
	if entry.type == "level" or entry.type == "uiScript" then
		self.session.level = self.session.level + 1
		self:setupSublevelPool()
	elseif entry.type == "randomizer" then
		-- Check whether it's the last sublevel.  If so, get outta there and move on.
		if self.session.sublevel == entry.count then
			self.session.level = self.session.level + 1
			self:setupSublevelPool()
		else
			self.session.sublevel = self.session.sublevel + 1
		end
	end
	-- Generate a new level ID.
	self.session.levelID = self:generateLevelID()
end

---Generates a new level ID, based on the current entry type and data.
---The returned level is removed from the pool if the current entry is configured so.
---@return LevelConfig
function Profile:generateLevelID()
	local entry = self:getLevelEntry()

	-- Now we are going to generate the level ID from the pool, if this is a randomizer,
	-- or just replace it if it's a normal level.
	if entry.type == "level" then
		return entry.level
	elseif entry.type == "randomizer" then
		-- Use local data to generate a level.
		if entry.mode == "repeat" then
			return self.session.sublevelPool[math.random(#self.session.sublevelPool)]
		elseif entry.mode == "noRepeat" then
			return table.remove(self.session.sublevelPool, math.random(#self.session.sublevelPool))
		elseif entry.mode == "order" then
			while true do
				local chance = (entry.count - self.session.sublevel + 1) / #self.session.sublevelPool
				local sublevel = self.session.sublevelPool[1]
				table.remove(self.session.sublevelPool, 1)
				if math.random() < chance then
					return sublevel
				end
			end
		end
	end
	error("Invalid level entry type")
end

---Sets up sublevel values for the current level entry if this entry is a randomizer.
---Otherwise, the sublevel values are cleared.
---@private
function Profile:setupSublevelPool()
	local entry = self:getLevelEntry()

	-- If this entry is a randomizer, copy the pool to an internal profile field.
	if entry.type == "randomizer" then
		self.session.sublevel = 1
		self.session.sublevelPool = {}
		for i, levelID in ipairs(entry.pool) do
			self.session.sublevelPool[i] = levelID
		end
	else
		self.session.sublevel = nil
		self.session.sublevelPool = nil
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



---Returns the player's current level statistics.
---@return LevelStatistics
function Profile:getCurrentLevelStats()
	return self.levelStats[self:getLevelID()]
end

---Overwrites the player's current level statistics with the provided statistics.
---@param data LevelStatistics
function Profile:setCurrentLevelStats(data)
	self.levelStats[self:getLevelID()] = data
end

---Temporary function for UltimatelySatisfyingMode.
---@return integer
function Profile:getUSMNumber()
	return self:getSession() and self:getLevel() or 1
end



---Returns the level number corresponding to the provided checkpoint ID.
---TODO: This should be parsed at the start and stored once.
---@param checkpoint number The checkpoint ID.
---@return integer
function Profile:getCheckpointLevelN(checkpoint)
	local entryN = self.checkpoints[checkpoint].levelID

	return self:getLevelCountFromEntries(entryN - 1) + 1
end



---Returns how many sublevels the first N levels have in total.
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



--##################################################--
---------------- C H E C K P O I N T S ---------------
--##################################################--

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

--##########################################--
---------------- S E S S I O N ---------------
--##########################################--

---Returns the player's current session, if a game is ongoing.
---@return ProfileSession?
function Profile:getSession()
	return self.session
end

---Starts a new game for this player, starting from a specified checkpoint.
---@param checkpoint integer The checkpoint ID of the game's starting point.
---@param difficulty DifficultyConfig The difficulty resource which is going to be used as a difficulty for this game.
function Profile:newGame(checkpoint, difficulty)
	self.session = ProfileSession(self, nil, difficulty, checkpoint)
	self:setupSublevelPool()
	self.session.levelID = self:generateLevelID()
end

---Ends a game for the player and removes all its data.
function Profile:deleteGame()
	self.session = nil
end

---Sets the Expression Variables in the `session` context.
---If the player does not have a game session active, the variables are removed.
---
---@see ProfileSession.dumpVariables
function Profile:dumpVariables()
	if self.session then
		self.session:dumpVariables()
	else
		_Vars:unset("session")
	end
end

--######################################--
---------------- L E V E L ---------------
--######################################--

---Saves the current score as a rollback score if score rollback is enabled.
function Profile:startLevel()
	self.session:saveRollback()
end

---Increments the level win count, updates the level record if needed and removes the saved level data.
---Does not increment the level itself!
---@param score integer The level score.
function Profile:winLevel(score)
	local levelData = self:getCurrentLevelStats() or {score = 0, won = 0, lost = 0}
	levelData.score = math.max(levelData.score, score)
	levelData.won = levelData.won + 1
	self:setCurrentLevelStats(levelData)
	self:unsaveLevel()
end

---Increments the level lose count and takes one life. Returns `false` if the player has had already zero lives, per `ProfileSession:takeLife()`.
---
---@see ProfileSession.takeLife
---@return boolean
function Profile:loseLevel()
	local levelData = self:getCurrentLevelStats() or {score = 0, won = 0, lost = 0}
	levelData.lost = levelData.lost + 1
	self:setCurrentLevelStats(levelData)
	local canRetry = self.session:takeLife()
	-- Rollback the score if defined in the life config.
	if canRetry then
		self.session:doRollback()
	end
	return canRetry
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
function Profile:getLevelHighscore(score)
	local levelData = self:getCurrentLevelStats()
	return not levelData or score > levelData.score
end

--##########################################################--
---------------- L E V E L   S A V E   D A T A ---------------
--##########################################################--

---Saves a level to the profile.
---@param t table The serialized level data to be saved.
function Profile:saveLevel(t)
	self.session:setLevelSaveData(t)
end

---Returns a previously saved level from the profile, if there is any.
---Otherwise, returns `nil`.
---@return table?
function Profile:getSavedLevel()
	return self.session:getLevelSaveData()
end

---Removes level save data from this profile.
function Profile:unsaveLevel()
	self.session:setLevelSaveData()
end

--################################################--
---------------- H I G H S C O R E S ---------------
--################################################--

---Writes this profile onto the highscore list using its current score.
---If successful, returns the position on the leaderboard. If not, returns `nil`.
---@return integer?
function Profile:writeHighscore()
	local pos = _Game.runtimeManager.highscores:getPosition(self.session:getScore())
	if not pos then
		return
	end
	-- returns the position if it got into top 10
	_Game.runtimeManager.highscores:storeEntry(pos, self.name, self.session:getScore(), self:getLevelName())
	return pos
end

--######################################################--
---------------- S E R I A L I Z A T I O N ---------------
--######################################################--

---Serializes the Profile's data for saving purposes.
---@return table
function Profile:serialize()
	local t = {
		session = self.session:serialize(),
		levelStats = self.levelStats,
		checkpoints = self.checkpointsUnlocked,
		variables = self.variables,
		ultimatelySatisfyingMode = self.ultimatelySatisfyingMode
	}
	return t
end

---Restores all data which has been saved by the serialization function.
---@param t table The data to be serialized.
function Profile:deserialize(t)
	self.session = ProfileSession(self, t.session)
	self.levelStats = t.levelStats
	self.checkpointsUnlocked = t.checkpoints
	if t.variables then
		self.variables = t.variables
	end
	self.ultimatelySatisfyingMode = t.ultimatelySatisfyingMode
end

return Profile
