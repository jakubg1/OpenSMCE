local class = require "class"
local Highscores = class:derive("Highscores")

function Highscores:new(data)
	self.data = data
	
	-- default if not found
	if not self.data then self:reset() end
end



function Highscores:reset()
	print("Resetting Highscores...")
	
	self.data = {}
	self.data.entries = {
		{name = "AAA", score = 10000, level = "1-1"},
		{name = "BBB", score = 9000, level = "1-1"},
		{name = "CCC", score = 8000, level = "1-1"},
		{name = "DDD", score = 7000, level = "1-1"},
		{name = "EEE", score = 6000, level = "1-1"},
		{name = "FFF", score = 5000, level = "1-1"},
		{name = "GGG", score = 4000, level = "1-1"},
		{name = "HHH", score = 3000, level = "1-1"},
		{name = "III", score = 2000, level = "1-1"},
		{name = "JJJ", score = 1000, level = "1-1"}
	}
end

function Highscores:getPosition(score)
	-- nil if it does not qualify
	for i = 10, 1, -1 do
		local entry = self.data.entries[i]
		if score <= entry.score then
			if i == 10 then return nil else return i + 1 end
		end
	end
	return 1
end

function Highscores:storeProfile(profile, pos)
	for i = 9, pos, -1 do
		-- everyone who is lower than the new highscore goes down
		self.data.entries[i + 1] = self.data.entries[i]
	end
	self.data.entries[pos] = {name = profile.name, score = profile:getScore(), level = profile:getCurrentLevelData().name}
	
	for i, entry in ipairs(self.data.entries) do print(entry.score, entry.name, entry.level) end
	return true
end



return Highscores