local class = require "class"
local Highscores = class:derive("Highscores")

function Highscores:new()
	self.entries = self:load()
end

function Highscores:save()
	local data = loadJson(parsePath("runtime.json"))
	data.highscores = self.entries
	saveJson(parsePath("runtime.json"), data)
end

function Highscores:load()
	return loadJson(parsePath("runtime.json")).highscores
end



function Highscores:getPosition(score)
	-- nil if it does not qualify
	for i = 10, 1, -1 do
		local entry = self.entries[i]
		if score <= entry.score then
			if i == 10 then return nil else return i + 1 end
		end
	end
	return 1
end

function Highscores:storeProfile(profile, pos)
	for i = 9, pos, -1 do
		-- everyone who is lower than the new highscore goes down
		self.entries[i + 1] = self.entries[i]
	end
	self.entries[pos] = {name = profile.name, score = profile:getScore(), level = profile:getCurrentLevelData().name}
	
	self:save()
	for i, entry in ipairs(self.entries) do print(entry.score, entry.name, entry.level) end
	return true
end



return Highscores