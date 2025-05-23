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
	self.checkpointsUnlocked = {}
	self.variables = {}

	if data then
		self:deserialize(data)
	else
		-- This is a new profile. Unlock the starting checkpoints.
		-- TODO: Currently it is hardcoded to unlock checkpoint 1.
		-- Find a way to store unlocked checkpoints per level set.
		table.insert(self.checkpointsUnlocked, 1)
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
