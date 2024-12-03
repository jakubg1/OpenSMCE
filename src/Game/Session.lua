-- NOTE:
-- May consider to ditch this class in the future and spread the contents to Game.lua, Level.lua and Profile.lua.
-- ~jakubg1


-- Class identification
local class = require "com.class"

---A root for all variable things during the game, such as level and player's progress.
---This class will be going bye-bye soon.
---To axe it, we need to have Sphere Selectors up and running.
---We have Sphere Selectors already. Now what?
---@class Session
---@overload fun(path, deserializationTable):Session
local Session = class:derive("Session")

-- Include class constructors
local Level = require("src.Game.Level")



---Constructs a new Session.
function Session:new()
	self.level = nil
end



---An initialization callback.
function Session:init()
	_Game.uiManager:executeCallback("sessionInit")
end



---Updates the Session.
---@param dt number Delta time in seconds.
function Session:update(dt)
	if self.level then
		self.level:update(dt)
	end
end



---Starts a new Level from the current Profile, or loads one in progress if it has one.
function Session:startLevel()
	self.level = Level(_Game:getCurrentProfile():getLevelData())
	local savedLevelData = _Game:getCurrentProfile():getSavedLevel()
	if savedLevelData then
		self.level:deserialize(savedLevelData)
		_Game.uiManager:executeCallback("levelLoaded")
	else
		_Game.uiManager:executeCallback("levelStart")
	end
end



---Destroys the level along with its save data.
function Session:levelEnd()
	self.level:unsave()
	self.level:destroy()
	self.level = nil
end

---Destroys the level and marks it as won.
function Session:levelWin()
	self.level:win()
	self.level:destroy()
	self.level = nil
end

---Destroys this level and saves it for the future.
function Session:levelSave()
	self.level:save()
	self.level:destroy()
	self.level = nil
end

---Destroys this level and triggers a `gameOver` callback in the UI script.
function Session:terminate()
	self.level:destroy()
	self.level = nil
	_Game.uiManager:executeCallback("gameOver")
end



---Draws itself... It's actually just the level, from which all its components are drawn.
function Session:draw()
	if self.level then
		self.level:draw()
	end
end



return Session
