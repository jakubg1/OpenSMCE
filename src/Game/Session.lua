-- NOTE:
-- May consider to ditch this class in the future and spread the contents to Game.lua, Level.lua and Profile.lua.
-- ~jakubg1


-- Class identification
local class = require "com.class"

---A root for all variable things during the game, such as level and player's progress.
---This class will be going bye-bye soon.
---To axe it, we need to have Sphere Selectors up and running.
---@class Session
---@overload fun(path, deserializationTable):Session
local Session = class:derive("Session")

-- Include commons
local Vec2 = require("src.Essentials.Vector2")

-- Include class constructors
local Level = require("src.Game.Level")
local ColorManager = require("src.Game.ColorManager")
local SphereSelectorResult = require("src.Game.SphereSelectorResult")



---Constructs a new Session.
function Session:new()
	self.level = nil
	self.colorManager = ColorManager()
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



---Returns whether both provided colors can attract or make valid scoring combinations with each other.
---@param color1 integer The first color to be checked against.
---@param color2 integer The second color to be checked against.
---@return boolean
function Session:colorsMatch(color1, color2)
	return _Utils.isValueInTable(_Game.configManager.spheres[color1].matches, color2)
end



---Selects spheres based on a provided Sphere Selector Config and destroys them, executing any provided Score Events in the process.
---TODO: Move this to Level.lua, and at some point change the parameters from strings to actual objects.
---@param sphereSelector SphereSelectorConfig|string The Sphere Selector that will be used to select the spheres to be destroyed.
---@param pos Vector2? The position used to calculate distances to spheres, and used in Floating Text position, unless `forceEventPosCalculation` is set.
---@param scoreEvent ScoreEventConfig|string? The Score Event that will be executed once on the whole batch.
---@param scoreEventPerSphere ScoreEventConfig|string? The Score Event that will be executed separately for each sphere.
---@param forceEventPosCalculation boolean? If set, the `pos` argument will be ignored and a new position for the Score Event will be calculated anyways.
function Session:destroySelector(sphereSelector, pos, scoreEvent, scoreEventPerSphere, forceEventPosCalculation)
	local selector = type(sphereSelector) == "string" and _Game.resourceManager:getSphereSelectorConfig(sphereSelector) or sphereSelector
	local event = scoreEvent and (type(scoreEvent) == "string" and _Game.resourceManager:getScoreEventConfig(scoreEvent) or scoreEvent)
	local eventPerSphere = scoreEventPerSphere and (type(scoreEventPerSphere) == "string" and _Game.resourceManager:getScoreEventConfig(scoreEventPerSphere) or scoreEventPerSphere)
	SphereSelectorResult(selector, pos):destroy(event, eventPerSphere, forceEventPosCalculation)
end



---Selects spheres based on a provided Sphere Selector Config and changes their colors.
---TODO: Move this to Level.lua, and at some point change the parameters from strings to actual objects.
---@param sphereSelector string The Sphere Selector that will be used to select the spheres to be destroyed.
---@param pos Vector2? The position used to calculate distances to spheres.
---@param color integer The color that all selected spheres will be changed to.
---@param particle table? A one-time Particle Effect that will be created at every affected sphere.
function Session:replaceColorSelector(sphereSelector, pos, color, particle)
	SphereSelectorResult(_Game.resourceManager:getSphereSelectorConfig(sphereSelector), pos):changeColor(color, particle)
end



---Returns the lowest length out of all sphere groups of a single color on the screen.
---This function ignores spheres that are offscreen.
---@return integer
function Session:getLowestMatchLength()
	local lowest = nil
	for i, path in ipairs(self.level.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local matchLength = sphereGroup:getMatchLengthInChain(l)
					if sphere.color ~= 0 and not sphere:isOffscreen() and (not lowest or lowest > matchLength) then
						lowest = matchLength
						if lowest == 1 then -- can't go any lower
							return 1
						end
					end
				end
			end
		end
	end
	return lowest
end



---Returns a list of spheres which can be destroyed by Lightning Storm the next time it decides to impale a sphere.
---@param matchLength integer? The exact length of a single-color group which will be targeted.
---@param encourageMatches boolean? If `true`, the function will prioritize groups which have the same color on either end.
---@return table
function Session:getSpheresWithMatchLength(matchLength, encourageMatches)
	if not matchLength then return {} end
	local spheres = {}
	for i, path in ipairs(self.level.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local valid = true
					-- Encourage matches: target groups that when destroyed will make a match.
					if encourageMatches then
						local color1, color2 = sphereGroup:getMatchBoundColorsInChain(l)
						valid = color1 and color2 and self:colorsMatch(color1, color2)
					end
					-- If one sphere can be destroyed in a large group to make a big match, don't trim edges to avoid lost opportunities.
					if matchLength > 3 then
						valid = sphereGroup.spheres[l - 1] and sphereGroup.spheres[l + 1] and self:colorsMatch(sphereGroup.spheres[l - 1].color, sphereGroup.spheres[l + 1].color)
					end
					if sphere.color ~= 0 and not sphere:isOffscreen() and sphereGroup:getMatchLengthInChain(l) == matchLength and valid then
						table.insert(spheres, sphere)
					end
				end
			end
		end
	end
	return spheres
end



---Returns the nearest sphere to the given position along with some extra data.
---The returned table has the following fields:
---
--- - `path` (Path),
--- - `sphereChain` (SphereChain),
--- - `sphereGroup` (SphereGroup),
--- - `sphere` (Sphere),
--- - `sphereID` (integer) - the sphere ID in the group,
--- - `pos` (Vector2) - the position of this sphere,
--- - `dist` (number) - the distance to this sphere,
--- - `half` (boolean) - if `true`, this is a half pointing to the end of the path, `false` if to the beginning of said path.
---@param pos Vector2 The position to be checked against.
---@return table
function Session:getNearestSphere(pos)
	local nearestData = {path = nil, sphereChain = nil, sphereGroup = nil, sphereID = nil, sphere = nil, pos = nil, dist = nil, half = nil}
	for i, path in ipairs(self.level.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local spherePos = sphereGroup:getSpherePos(l)
					local sphereAngle = sphereGroup:getSphereAngle(l)
					local sphereHidden = sphereGroup:getSphereHidden(l)

					local sphereDist = (pos - spherePos):len()

					local sphereDistAngle = (pos - spherePos):angle()
					local sphereAngleDiff = (sphereDistAngle - sphereAngle + math.pi / 2) % (math.pi * 2)
					local sphereHalf = sphereAngleDiff <= math.pi / 2 or sphereAngleDiff > 3 * math.pi / 2
					-- if closer than the closest for now, save it
					if not sphere:isGhost() and not sphereHidden and (not nearestData.dist or sphereDist < nearestData.dist) then
						nearestData.path = path
						nearestData.sphereChain = sphereChain
						nearestData.sphereGroup = sphereGroup
						nearestData.sphereID = l
						nearestData.sphere = sphere
						nearestData.pos = spherePos
						nearestData.dist = sphereDist
						nearestData.half = sphereHalf
					end
				end
			end
		end
	end
	return nearestData
end



---Returns the first sphere to collide with a provided line of sight along with some extra data.
---The returned table has the following fields:
---
--- - `path` (Path),
--- - `sphereChain` (SphereChain),
--- - `sphereGroup` (SphereGroup),
--- - `sphere` (Sphere),
--- - `sphereID` (integer) - the sphere ID in the group,
--- - `pos` (Vector2) - the position of this sphere,
--- - `dist` (number) - the distance to this sphere,
--- - `targetPos` (Vector2) - the collision position (used for i.e. drawing the reticle),
--- - `half` (boolean) - if `true`, this is a half pointing to the end of the path, `false` if to the beginning of said path.
---@param pos Vector2 The starting position of the line of sight.
---@param angle number The angle of the line. 0 is up.
---@return table
function Session:getNearestSphereOnLine(pos, angle)
	local nearestData = {path = nil, sphereChain = nil, sphereGroup = nil, sphereID = nil, sphere = nil, pos = nil, dist = nil, targetPos = nil, half = nil}
	for i, path in ipairs(self.level.map.paths) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local spherePos = sphereGroup:getSpherePos(l)
					local sphereSize = sphereGroup:getSphereSize(l)
					local sphereAngle = sphereGroup:getSphereAngle(l)
					local sphereHidden = sphereGroup:getSphereHidden(l)

					local sphereTargetCPos = (spherePos - pos):rotate(-angle) + pos
					local sphereTargetY = sphereTargetCPos.y + math.sqrt(math.pow(sphereSize / 2, 2) - math.pow(pos.x - sphereTargetCPos.x, 2))
					local sphereTargetPos = (Vec2(pos.x, sphereTargetY) - pos):rotate(angle) + pos
					local sphereDist = Vec2(pos.x - sphereTargetCPos.x, pos.y - sphereTargetY)

					local sphereDistAngle = (pos - spherePos):angle()
					local sphereAngleDiff = (sphereDistAngle - sphereAngle + math.pi / 2) % (math.pi * 2)
					local sphereHalf = sphereAngleDiff <= math.pi / 2 or sphereAngleDiff > 3 * math.pi / 2
					-- if closer than the closest for now, save it
					if not sphere:isGhost() and not sphereHidden and math.abs(sphereDist.x) <= sphereSize / 2 and sphereDist.y >= 0 and (not nearestData.dist or sphereDist.y < nearestData.dist.y) then
						nearestData.path = path
						nearestData.sphereChain = sphereChain
						nearestData.sphereGroup = sphereGroup
						nearestData.sphereID = l
						nearestData.sphere = sphere
						nearestData.pos = spherePos
						nearestData.dist = sphereDist
						nearestData.targetPos = sphereTargetPos
						nearestData.half = sphereHalf
					end
				end
			end
		end
	end
	return nearestData
end



return Session
