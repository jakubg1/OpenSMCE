--- A root for all variable things during the game, such as level and player's progress.
-- @module Session

-- NOTE:
-- May consider to ditch this class in the future and spread the contents to Game.lua, Level.lua and Profile.lua.
-- ~jakubg1


-- Class identification
local class = require "com.class"

---@class Session
---@overload fun(path, deserializationTable):Session
local Session = class:derive("Session")

-- Include commons
local Vec2 = require("src.Essentials.Vector2")

-- Include class constructors
local Level = require("src.Level")
local ColorManager = require("src.ColorManager")



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
	if self.level then self.level:update(dt) end
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
	local matches = _Game.configManager.spheres[color1].matches
	for i, v in ipairs(matches) do
		if v == color2 then return true end
	end
	return false
end



---Destroys these spheres, for which the provided function returns `true`. Each sphere is checked separately.
---The playes is also given 100 points for each destroyed sphere.
---@param f function The function to be run for each sphere. Two parameters are allowed: `sphere` (Sphere) and `spherePos` (Vector2). If the function returns `true`, the sphere is destroyed.
---@param scorePos Vector2 The location of the floating text indicator showing how much score the player has gained.
---@param scoreFont string? The font to be used in the score text.
function Session:destroyFunction(f, scorePos, scoreFont)
	-- we pass a function in the f variable
	-- if f(param1, param2, ...) returns true, the sphere is nuked
	local score = 0
	for i, path in ipairs(self.level.map.paths) do
		for j = #path.sphereChains, 1, -1 do
			local sphereChain = path.sphereChains[j]
			for k = #sphereChain.sphereGroups, 1, -1 do
				local sphereGroup = sphereChain.sphereGroups[k]
				for l = #sphereGroup.spheres, 1, -1 do
					local sphere = sphereGroup.spheres[l]
					local spherePos = sphereGroup:getSpherePos(l)
					if f(sphere, spherePos) and sphere.color ~= 0 then
						sphereGroup:destroySphere(l)
						score = score + 100
					end
				end
			end
		end
	end
	self.level:grantScore(score)
	self.level:spawnFloatingText(_NumStr(score), scorePos, scoreFont or "fonts/score0.json")
end



---Changes colors of these spheres, for which the provided function returns `true`, to a given color. Each sphere is checked separately.
---@param f function The function to be run for each sphere. Two parameters are allowed: `sphere` (Sphere) and `spherePos` (Vector2). If the function returns `true`, the sphere is affected by this function.
---@param color integer The new color of affected spheres.
---@param particle table? The particle effect to be used for each affected sphere.
function Session:setColorFunction(f, color, particle)
	-- we pass a function in the f variable
	-- if f(param1, param2, ...) returns true, the sphere color is changed
	for i, path in ipairs(self.level.map.paths) do
		for j = #path.sphereChains, 1, -1 do
			local sphereChain = path.sphereChains[j]
			for k = #sphereChain.sphereGroups, 1, -1 do
				local sphereGroup = sphereChain.sphereGroups[k]
				for l = #sphereGroup.spheres, 1, -1 do
					local sphere = sphereGroup.spheres[l]
					local spherePos = sphereGroup:getSpherePos(l)
					if f(sphere, spherePos) and sphere.color ~= 0 then
						sphere:changeColor(color, particle)
					end
				end
			end
		end
	end
end



---Destroys all spheres on the board.
function Session:destroyAllSpheres()
	self:destroyFunction(
		function(sphere, spherePos) return true end,
		self.level.shooter.pos + Vec2(0, -32)
	)
end



---Destroys a single sphere from the board.
---@param s Sphere The sphere to be destroyed.
function Session:destroySingleSphere(s)
	self:destroyFunction(
		function(sphere, spherePos) return sphere == s end,
		s:getPos(), _Game.configManager.spheres[s.color].matchFont
	)
end



---Destroys all spheres of a given color.
---@param color integer The sphere color to be removed.
function Session:destroyColor(color)
	self:destroyFunction(
		function(sphere, spherePos) return sphere.color == color end,
		self.level.shooter.pos + Vec2(0, -32)
	)
end



---Destroys all spheres that are closer than `radius` pixels to the `pos` position.
---@param pos Vector2 A position relative to which the spheres will be destroyed.
---@param radius number The range in pixels.
function Session:destroyRadius(pos, radius)
	self:destroyFunction(
		function(sphere, spherePos) return (pos - spherePos):len() <= radius end,
		pos
	)
end



---Destroys all spheres that are closer than `width` pixels to the `x` position on the X coordinate.
---@param x number An X coordinate relative to which the spheres will be destroyed.
---@param width number The range in pixels.
function Session:destroyVertical(x, width)
	self:destroyFunction(
		function(sphere, spherePos) return math.abs(x - spherePos.x) <= width / 2 end,
		self.level.shooter.pos + Vec2(0, -32)
	)
end



---Destroys all spheres that are closer than `radius` pixels to the `pos` position and match with a given color.
---@param pos Vector2 A position relative to which the spheres will be destroyed.
---@param radius number The range in pixels.
---@param color integer A color that any sphere must be matching with in order to destroy it.
function Session:destroyRadiusColor(pos, radius, color)
	self:destroyFunction(
		function(sphere, spherePos) return (pos - spherePos):len() <= radius and self:colorsMatch(color, sphere.color) end,
		pos
	)
end



---Destroys all spheres that are closer than `width` pixels to the `x` position on the X coordinate and match with a given color.
---@param x number An X coordinate relative to which the spheres will be destroyed.
---@param width number The range in pixels.
---@param color integer A color that any sphere must be matching with in order to destroy it.
function Session:destroyVerticalColor(x, width, color)
	self:destroyFunction(
		function(sphere, spherePos) return math.abs(x - spherePos.x) <= width / 2 and self:colorsMatch(color, sphere.color) end,
		self.level.shooter.pos + Vec2(0, -32)
	)
end



---Replaces the color of all spheres of a given color with another color.
---@param color1 integer The color to be changed from.
---@param color2 integer The new color of the affected spheres.
---@param particle table? A one-time particle packet to be used for each affected sphere.
function Session:replaceColor(color1, color2, particle)
	self:setColorFunction(
		function(sphere, spherePos) return sphere.color == color1 end,
		color2, particle
	)
end



---Replaces the color of all spheres within a given radius with another color, provided they match with a given sphere.
---@param pos Vector2 A position relative to which the spheres will be affected.
---@param radius number The range in pixels.
---@param color integer A color that any sphere must be matching with in order to destroy it.
---@param color2 integer A target color.
function Session:replaceColorRadiusColor(pos, radius, color, color2)
	self:setColorFunction(
		function(sphere, spherePos) return (pos - spherePos):len() <= radius and self:colorsMatch(color, sphere.color) end,
		color2
	)
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
					local sphereAngle = sphereGroup:getSphereAngle(l)
					local sphereHidden = sphereGroup:getSphereHidden(l)

					-- 16 is half of the sphere size
					local sphereTargetCPos = (spherePos - pos):rotate(-angle) + pos
					local sphereTargetY = sphereTargetCPos.y + math.sqrt(math.pow(16, 2) - math.pow(pos.x - sphereTargetCPos.x, 2))
					local sphereTargetPos = (Vec2(pos.x, sphereTargetY) - pos):rotate(angle) + pos
					local sphereDist = Vec2(pos.x - sphereTargetCPos.x, pos.y - sphereTargetY)

					local sphereDistAngle = (pos - spherePos):angle()
					local sphereAngleDiff = (sphereDistAngle - sphereAngle + math.pi / 2) % (math.pi * 2)
					local sphereHalf = sphereAngleDiff <= math.pi / 2 or sphereAngleDiff > 3 * math.pi / 2
					-- if closer than the closest for now, save it
					if not sphere:isGhost() and not sphereHidden and math.abs(sphereDist.x) <= 16 and sphereDist.y >= 0 and (not nearestData.dist or sphereDist.y < nearestData.dist.y) then
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
