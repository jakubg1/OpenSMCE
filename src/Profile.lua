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



-- Core stuff

function Profile:reset()
	self.data = {}
	self.data.levels = {}
	self:newGame()
end

function Profile:reloadMapData()
	local levelData = loadJson(parsePath(self:getCurrentLevelConfig().path))
	local path = "maps/" .. levelData.map
	self.mapData = loadJson(parsePath(path .. "/config.json"))
end



-- Core level stuff

function Profile:getLevel()
	return self.data.session.level
end

function Profile:setLevel(level)
	self.data.session.level = level
	self:reloadMapData()
end

function Profile:incrementLevel()
	self:setLevel(self:getLevel() + 1)
end


function Profile:getCurrentLevelConfig()
	return game.configManager.config.levels[self:getLevel()]
end


function Profile:getCurrentLevelData()
	return self.data.levels[tostring(self:getLevel())]
end

function Profile:setCurrentLevelData(data)
	self.data.levels[tostring(self:getLevel())] = data
end



-- Score

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



-- Coins

function Profile:getCoins()
	return self.data.session.coins
end

function Profile:grantCoin()
	self.data.session.coins = self.data.session.coins + 1
	if self.data.session.coins == 30 then self:grantLife() end
end



-- Lives

function Profile:getLives()
	return self.data.session.lives
end

function Profile:grantLife()
	self.data.session.lives = self.data.session.lives + 1
	self.data.session.coins = 0
	game:getWidget(game.configManager.config.hudPathsTEMP.profile_extralife):show()
end

function Profile:takeLife()
	if self.data.session.lives == 0 then return false end
	self.data.session.lives = self.data.session.lives - 1
	-- returns true if the player can retry
	return true
end



-- General

function Profile:newGame()
	self.data.session = {}
	self.data.session.lives = 2
	self.data.session.coins = 0
	self.data.session.score = 0
	self.data.session.difficulty = 1
	self:setLevel(1)
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
	self:incrementLevel()
	game:playSound("level_advance")
	local checkpoint = self:getCurrentLevelConfig().checkpoint
	if checkpoint then
		game:playSound("checkpoint")
	end
end

function Profile:getLevelHighscoreInfo(score)
	-- Returns true if score given in parameter would yield a new record for the current level.
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
