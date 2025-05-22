local class = require "com.class"

---Handles the Game's leaderboard.
---@class Highscores
---@overload fun(data):Highscores
local Highscores = class:derive("Highscores")



---Constructs a new Highscores object.
---@param data table? Data to be loaded. If not specified, a default leaderboard will be loaded.
function Highscores:new(data)
	self.data = data
	self.config = _Game.configManager.highscores

	-- default if not found
	if not self.data then
		self:reset()
	end
end



---Resets the leaderboard to default values.
function Highscores:reset()
	_Log:printt("Highscores", "Resetting Highscores...")

	self.data = {entries = {}}
	for i = 1, self.config.size do
		local def = self.config.defaultScores[i]
		self.data.entries[i] = {
			name = def.name,
			score = def.score,
			level = def.level
		}
	end
end



---Returns a specified entry from the leaderboard.
---@param n integer An entry index.
---@return table
function Highscores:getEntry(n)
	return self.data.entries[n]
end



---Returns a hypothetical position a player would get with given score, or `nil` if it does not qualify.
---@param score integer The score to be considered.
---@return integer?
function Highscores:getPosition(score)
	for i = self.config.size, 1, -1 do
		local entry = self:getEntry(i)
		if score <= entry.score then
			if i == self.config.size then
				-- We've hit the end of the highscore table, better luck next time!
				return nil
			else
				return i + 1
			end
		end
	end
	return 1
end



---Stores a given Profile's progress into a specified position of the leaderboard.
---That position and all entries below it are moved down by one space.
---@param position integer The place at which the entry will be created.
---@param name string The name of the player who should be written on the scoreboard.
---@param score integer How much score that player has scored.
---@param level string The level name at which the game has ended.
function Highscores:storeEntry(position, name, score, level)
	for i = self.config.size - 1, position, -1 do
		self.data.entries[i + 1] = self.data.entries[i]
	end
	self.data.entries[position] = {name = name, score = score, level = level}
end



return Highscores
