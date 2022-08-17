local class = require "com/class"

---@class Highscores
---@overload fun(data):Highscores
local Highscores = class:derive("Highscores")



function Highscores:new(data)
	self.data = data
	self.config = _Game.configManager.highscores

	-- default if not found
	if not self.data then self:reset() end
end



function Highscores:reset()
	print("Resetting Highscores...")

	self.data = {entries = {}}
	for i = 1, self.config.size do
		local def = self.config.default_scores[i]
		self.data.entries[i] = {
			name = def.name,
			score = def.score,
			level = def.level
		}
	end
end

function Highscores:getEntry(n)
	return self.data.entries[n]
end

function Highscores:getPosition(score)
	-- nil if it does not qualify
	for i = self.config.size, 1, -1 do
		local entry = self:getEntry(i)
		if score <= entry.score then
			if i == self.config.size then return nil else return i + 1 end
		end
	end
	return 1
end

function Highscores:storeProfile(profile, pos)
	for i = self.config.size - 1, pos, -1 do
		-- everyone who is lower than the new highscore goes down
		self.data.entries[i + 1] = self:getEntry(i)
	end
	self.data.entries[pos] = {name = profile.name, score = profile:getScore(), level = profile:getLevelData().name}

	for i, entry in ipairs(self.data.entries) do print(entry.score, entry.name, entry.level) end
	return true
end



return Highscores
