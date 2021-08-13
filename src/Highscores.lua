local class = require "com/class"
local Highscores = class:derive("Highscores")

function Highscores:new(data)
	self.data = data

	-- default if not found
	if not self.data then self:reset() end
end



function Highscores:reset()
	print("Resetting Highscores...")

	self.data = {}
	self.data.entries = game.configManager.highscores.default_scores
end

function Highscores:getEntry(n)
	return self.data.entries[n]
end

function Highscores:getPosition(score)
	-- nil if it does not qualify
	for i = 10, 1, -1 do
		local entry = self:getEntry(i)
		if score <= entry.score then
			if i == 10 then return nil else return i + 1 end
		end
	end
	return 1
end

function Highscores:storeProfile(profile, pos)
	for i = 9, pos, -1 do
		-- everyone who is lower than the new highscore goes down
		self.data.entries[i + 1] = self:getEntry(i)
	end
	self.data.entries[pos] = {name = profile.name, score = profile:getScore(), level = profile:getCurrentLevelConfig().name}

	for i, entry in ipairs(self.data.entries) do print(entry.score, entry.name, entry.level) end
	return true
end



return Highscores
