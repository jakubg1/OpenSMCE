local class = require "com/class"
local Profile = class:derive("Profile")

function Profile:new(data, name)
	self.name = name
	
	if data then
		self.data = data[name]
	else
		-- default if not found
		-- TODO: change behavior after ProfileManager is done
		self:reset()
	end
	
	self.mapData = nil
	self:reloadMapData()
end



function Profile:reset()
	self.data = {}
	self.data.levels = {}
	self.data.session = {}
	self.data.session.lives = 2
	self.data.session.coins = 0
	self.data.session.score = 0
	self.data.session.level = 1
	self.data.session.difficulty = 1
end



function Profile:getCurrentLevel()
	return self.data.levels[tostring(self.data.session.level)]
end

function Profile:getCurrentLevelData()
	return game.config.levels[self.data.session.level]
end

function Profile:setCurrentLevel(data)
	self.data.levels[tostring(self.data.session.level)] = data
end

function Profile:reloadMapData()
	local levelData = loadJson(parsePath(self:getCurrentLevelData().path))
	local path = "maps/" .. levelData.map
	self.mapData = loadJson(parsePath(path .. "/config.json"))
end



function Profile:getScore()
	return self.data.session.score
end

function Profile:grantScore(score)
	if self.data.session.ultimatelySatisfyingMode then
		self.data.session.score = self.data.session.score + score * (1 + (self.data.session.level - 1) * 0.2)
	else
		self.data.session.score = self.data.session.score + score
	end
end


function Profile:getCoins()
	return self.data.session.coins
end

function Profile:grantCoin()
	self.data.session.coins = self.data.session.coins + 1
	if self.data.session.coins == 30 then self:grantLife() end
end


function Profile:getLives()
	return self.data.session.lives
end

function Profile:grantLife()
	self.data.session.lives = self.data.session.lives + 1
	self.data.session.coins = 0
	game:getWidget(game.config.hudPathsTEMP.profile_extralife):show()
end

function Profile:takeLife()
	if self.data.session.lives == 0 then return false end
	self.data.session.lives = self.data.session.lives - 1
	-- returns true if the player can retry
	return true
end


function Profile:winLevel(score)
	local currentLevel = self:getCurrentLevel() or {score = 0, won = 0, lost = 0}
	
	currentLevel.score = math.max(currentLevel.score, score)
	currentLevel.won = currentLevel.won + 1
	self:setCurrentLevel(currentLevel)
	self.data.session.level = self.data.session.level + 1
	self:reloadMapData()
	self:unsaveLevel()
	game:playSound("level_advance")
end

function Profile:getLevelHighscoreInfo(score)
	-- Returns true if score given in parameter would yield a new record for the current level.
	local currentLevel = self:getCurrentLevel()
	return not currentLevel or score > currentLevel.score
end

function Profile:loseLevel()
	local currentLevel = self:getCurrentLevel() or {score = 0, won = 0, lost = 0}
	
	currentLevel.lost = currentLevel.lost + 1
	self:setCurrentLevel(currentLevel)
	
	local canRetry = self:takeLife()
	
	return canRetry
end

function Profile:saveLevel(t)
	self.data.session.levelSaveData = t
end

function Profile:getSavedLevel()
	return self.data.session.levelSaveData
end

function Profile:unsaveLevel()
	self.data.session.levelSaveData = nil
end



function Profile:writeHighscore()
	local pos = game.runtimeManager.highscores:getPosition(self:getScore())
	if not pos then return false end
	
	-- returns true if it got into top 10
	game.runtimeManager.highscores:storeProfile(self, pos)
	return true
end



return Profile