local class = require "com/class"

---@class Profile
---@overload fun(data, name):Profile
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
-- Level number: Starts at one, each level and each subsequent entry in randomizers count separately.
-- Level pointer: Starts at one and points towards an entry in the level order.
-- Level ID: ID of a particular level file.
-- Level data: Stores profile-related data per level, such as win/lose count or some other statistics.

-- Returns the player's current level number.
function Profile:getLevel()
	-- Count (current level pointer - 1) entries from the level set.
	local n = _Game.configManager:getLevelCountFromEntries(self.session.level - 1)

	return n + self.session.sublevel
end

-- Returns the player's current level number as a string.
function Profile:getLevelStr()
	return tostring(self:getLevel())
end

-- Returns the player's current level pointer value.
function Profile:getLevelPtr()
	return self.session.level
end

-- Returns the player's current level pointer value as a string.
function Profile:getLevelPtrStr()
	return tostring(self:getLevel())
end

-- Returns the player's current level entry.
function Profile:getLevelEntry()
	return _Game.configManager.levelSet.level_order[self.session.level]
end

-- Returns the player's current level ID.
function Profile:getLevelID()
	return self.session.levelID
end

-- Returns the player's current level ID as a string.
function Profile:getLevelIDStr()
	return tostring(self:getLevelID())
end

-- Returns the player's current level name.
function Profile:getLevelName()
	local entry = self:getLevelEntry()
	
	if entry.type == "level" then
		return entry.name
	elseif entry.type == "randomizer" then
		return entry.names[self.session.sublevel]
	end
end

-- Goes on to a next level, either another one in a subset, or in a main level set.
function Profile:incrementLevel()
	local entry = self:getLevelEntry()

	-- Update the pointers.
	if entry.type == "level" then
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

-- Generates a new level ID, based on the current entry type and data.
function Profile:generateLevelID()
	local entry = self:getLevelEntry()

	-- Now we are going to generate the level ID from the pool, if this is a randomizer,
	-- or just replace it if it's a normal level.
	if entry.type == "level" then
		self.session.levelID = entry.level
	elseif entry.type == "randomizer" then
		-- Use local data to generate a level.
		if entry.mode == "repeat" then
			self.session.levelID = self.session.sublevel_pool[math.random(#self.session.sublevel_pool)]
		elseif entry.mode == "no_repeat" then
			local i = math.random(#self.session.sublevel_pool)
			self.session.levelID = self.session.sublevel_pool[i]
			table.remove(self.session.sublevel_pool, i)
		elseif entry.mode == "order" then
			while true do
				local chance = (entry.count - self.session.sublevel + 1) / #self.session.sublevel_pool
				local n = self.session.sublevel_pool[1]
				table.remove(self.session.sublevel_pool, 1)
				if chance then
					self.session.levelID = n
					break
				end
			end
		end
	end
end

-- Sets up values for a level set entry the level pointer is currently pointing to.
function Profile:setupLevel()
	local entry = self:getLevelEntry()

	self.session.sublevel = 1
	self.session.sublevel_pool = {}
	-- If this entry is a randomizer, copy the pool to an internal profile field.
	if entry.type == "randomizer" then
		for i, levelID in ipairs(entry.pool) do
			self.session.sublevel_pool[i] = levelID
		end
	end
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
	local entry = self:getLevelEntry()

	-- A checkpoint can't be upcoming if we are in the middle of a randomizer section.
	if entry.type == "randomizer" and self.session.sublevel < entry.count then
		return
	end

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



-- Game

function Profile:newGame(checkpoint)
	self.session = {}
	self.session.lives = 2
	self.session.coins = 0
	self.session.score = 0
	self.session.difficulty = 1

	self.session.level = _Game.configManager.levelSet.checkpoints[checkpoint]
	self.session.sublevel = 1
	self.session.sublevel_pool = {}
	self.session.levelID = 0
	
	self:setupLevel()
	self:generateLevelID()
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

-- Returns true if score given in parameter would yield a new record for the current level.
function Profile:getLevelHighscoreInfo(score)
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



-- Level saves

function Profile:saveLevel(t)
	self.session.levelSaveData = t
end

function Profile:getSavedLevel()
	return self.session.levelSaveData
end

function Profile:unsaveLevel()
	self.session.levelSaveData = nil
end



-- Highscore

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
