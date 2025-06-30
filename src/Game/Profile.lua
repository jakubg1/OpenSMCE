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

	---@type ProfileSession?
	self.session = nil

	---The level statistics structure is a table with three entries:
	--- - `score` - The currently highest score for this level.
	--- - `won` - How many times this level has been beaten.
	--- - `lost` - How many times this level has been lost.
	---@alias LevelStatistics {score: integer, won: integer, lost: integer}
	---@type table<string, LevelStatistics>
	self.levelStats = {}

	--- This table stores the unlocked checkpoints per level set.
	---@type table<string, integer[]>
	self.unlockedCheckpoints = {}
	self.variables = {}

	if data then
		self:deserialize(data)
	else
		-- Populate all level sets with their starting checkpoints.
		-- TODO: Make a singleton class for the Level Sets.
		for i, id in ipairs(_Game.resourceManager:getResourceList("LevelSet")) do
			local levelSet = _Game.resourceManager:getLevelSetConfig(id)
			self.unlockedCheckpoints[id] = {}
			for j, entry in ipairs(levelSet.levelOrder) do
				if entry.checkpoint and entry.checkpoint.unlockedOnStart then
					table.insert(self.unlockedCheckpoints[id], entry.checkpoint.id)
				end
			end
		end
	end
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

--##############################################--
---------------- L E V E L   S E T ---------------
--##############################################--

-- TODO: Make Level Sets their own singleton class.

---Returns how many sublevels the first N levels have in total in the provided level set.
---@param levelSet LevelSetConfig The level set to be looked for.
---@param levels integer The total number of levels to be considered.
---@return integer
function Profile:getLevelCountFromEntries(levelSet, levels)
	local n = 0
	-- If it's a single level, count 1.
	-- If it's a randomizer, count that many levels as there are defined in the randomizer.
	for i = 1, levels do
		local entry = levelSet.levelOrder[i]
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

---Returns a list of checkpoints this player has unlocked for the provided level set.
---@param levelSet LevelSetConfig The level set to be looked for.
---@return integer[]
function Profile:getUnlockedCheckpoints(levelSet)
	local id = _Game.resourceManager:getResourceReference(levelSet)
	return self.unlockedCheckpoints[id]
end

---Returns whether this player has unlocked a given checkpoint in the provided level set.
---@param levelSet LevelSetConfig The level set to be looked for.
---@param n integer The checkpoint ID to be checked.
---@return boolean
function Profile:isCheckpointUnlocked(levelSet, n)
	local id = _Game.resourceManager:getResourceReference(levelSet)
	return _Utils.isValueInTable(self.unlockedCheckpoints[id], n)
end

---Unlocks a given checkpoint for the player if it has not been unlocked yet in the provided level set.
---@param levelSet LevelSetConfig The level set to be looked for.
---@param n integer The checkpoint ID to be unlocked.
function Profile:unlockCheckpoint(levelSet, n)
	local id = _Game.resourceManager:getResourceReference(levelSet)
	if _Utils.isValueInTable(self.unlockedCheckpoints[id], n) then
		return
	end
	table.insert(self.unlockedCheckpoints[id], n)
end

---Generates checkpoint data for the provided level set. Useful for lookup.
---@param levelSet LevelSetConfig The level set to be looked for.
---@return table<integer, {levelID: integer, unlockedOnStart: boolean}>
function Profile:getCheckpointData(levelSet)
    local checkpoints = {}
	for i, entry in ipairs(levelSet.levelOrder) do
		if entry.checkpoint then
			checkpoints[entry.checkpoint.id] = {levelID = i, unlockedOnStart = entry.checkpoint.unlockedOnStart}
		end
	end
    return checkpoints
end

---Returns the total level number corresponding to the provided checkpoint ID in the provided level set.
---TODO: This should be parsed at the start and stored once. Make a singleton LevelSet class.
---@param levelSet LevelSetConfig The level set to be looked for.
---@param n number The checkpoint ID.
---@return integer
function Profile:getCheckpointLevelN(levelSet, n)
	local entryN = self:getCheckpointData(levelSet)[n].levelID
	return self:getLevelCountFromEntries(levelSet, entryN - 1) + 1
end

--######################################################--
---------------- S E R I A L I Z A T I O N ---------------
--######################################################--

---Serializes the Profile's data for saving purposes.
---@return table
function Profile:serialize()
	local t = {
		session = self.session and self.session:serialize(),
		levelStats = self.levelStats,
		unlockedCheckpoints = self.unlockedCheckpoints,
		variables = self.variables,
		ultimatelySatisfyingMode = self.ultimatelySatisfyingMode
	}
	return t
end

---Restores all data which has been saved by the serialization function.
---@param t table The data to be serialized.
function Profile:deserialize(t)
	self.session = t.session and ProfileSession(self, t.session)
	self.levelStats = t.levelStats
	self.unlockedCheckpoints = t.unlockedCheckpoints
	if t.variables then
		self.variables = t.variables
	end
	self.ultimatelySatisfyingMode = t.ultimatelySatisfyingMode
end

return Profile
