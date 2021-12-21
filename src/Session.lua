--- A root for all variable things during the game, such as level and player's progress.
-- @module Session

-- NOTE:
-- May consider to ditch this class in the future and spread the contents to Game.lua, Level.lua and Profile.lua.
-- ~jakubg1


-- Class identification
local class = require "com/class"
local Session = class:derive("Session")

-- Include commons
local Vec2 = require("src/Essentials/Vector2")

-- Include class constructors
local Level = require("src/Level")
local ColorManager = require("src/ColorManager")



--- Object constructor.
-- A callback executed when this object is created.
function Session:new()
	self.level = nil
	self.colorManager = ColorManager()
end



--- An initialization callback.
function Session:init()
	_Game.uiManager:executeCallback("sessionInit")
end



--- An update callback.
-- @tparam number dt Delta time in seconds.
function Session:update(dt)
	if self.level then self.level:update(dt) end
end



--- Initializes a new level.
-- The level number is derived from the current Profile.
function Session:startLevel()
	self.level = Level(_Game:getCurrentProfile():getCurrentLevelConfig())
	local savedLevelData = _Game:getCurrentProfile():getSavedLevel()
	if savedLevelData then
		self.level:deserialize(savedLevelData)
		_Game.uiManager:executeCallback("levelLoaded")
	else
		_Game.uiManager:executeCallback("levelStart")
	end
end

function Session:levelEnd()
	self.level:unsave()
	self.level:destroy()
	self.level = nil
end

function Session:levelWin()
	self.level:win()
	self.level:destroy()
	self.level = nil
end

function Session:levelSave()
	self.level:save()
	self.level:destroy()
	self.level = nil
end



--- Triggers a Game Over.
-- Deinitializates the level and shows an appropriate widget.
function Session:terminate()
	self.level = nil
	_Game.uiManager:executeCallback("gameOver")
end



--- A drawing callback.
function Session:draw()
	if self.level then self.level:draw() end
end



--- Returns whether both provided colors can attract or make valid scoring combinations with each other.
-- @tparam number color1 The first color to check.
-- @tparam number color2 The second color to check.
-- @treturn boolean Whether the check has passed.
function Session:colorsMatch(color1, color2)
	local matches = _Game.configManager.spheres[color1].matches
	for i, v in ipairs(matches) do
		if v == color2 then return true end
	end
	return false
end



--- Destroys all spheres on the board if a call of the function f(sphere, spherePos) returns true.
-- @tparam function t The function that has to return true in order for a given sphere to be deleted.
-- @tparam Vector2 scorePos A position where the score text should be located.
function Session:destroyFunction(f, scorePos, scoreFont)
	-- we pass a function in the f variable
	-- if f(param1, param2, ...) returns true, the sphere is nuked
	local score = 0
	for i, path in ipairs(self.level.map.paths.objects) do
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



--- Changes all sphere colors on the board if a call of the function f(sphere, spherePos) returns true.
-- @tparam function t The function that has to return true in order for a given sphere's color to be changed.
-- @tparam number color A color to which the given spheres will be painted.
function Session:setColorFunction(f, color, particle)
	-- we pass a function in the f variable
	-- if f(param1, param2, ...) returns true, the sphere color is changed
	for i, path in ipairs(self.level.map.paths.objects) do
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



--- Destroys all spheres on the board.
function Session:destroyAllSpheres()
	self:destroyFunction(
		function(sphere, spherePos) return true end,
		self.level.shooter.pos + Vec2(0, -32)
	)
end



function Session:destroySingleSphere(s)
	self:destroyFunction(
		function(sphere, spherePos) return sphere == s end,
		s:getPos(), _Game.configManager.spheres[s.color].matchFont
	)
end



--- Destroys all spheres on the board if they are a given color.
-- @tparam number color The sphere color to be deleted.
function Session:destroyColor(color)
	self:destroyFunction(
		function(sphere, spherePos) return sphere.color == color end,
		self.level.shooter.pos + Vec2(0, -32)
	)
end



--- Destroys all spheres that are closer than radius pixels to the pos position.
-- @tparam Vector2 pos A position relative to which the spheres will be destroyed.
-- @tparam number radius The range in pixels.
function Session:destroyRadius(pos, radius)
	self:destroyFunction(
		function(sphere, spherePos) return (pos - spherePos):len() <= radius end,
		pos
	)
end



--- Destroys all spheres that are closer than width pixels to the x position on X coordinate.
-- @tparam number x An X coordinate relative to which the spheres will be destroyed.
-- @tparam number width The range in pixels.
function Session:destroyVertical(x, width)
	self:destroyFunction(
		function(sphere, spherePos) return math.abs(x - spherePos.x) <= width / 2 end,
		self.level.shooter.pos + Vec2(0, -32)
	)
end



--- Destroys all spheres that are closer than radius pixels to the pos position.
-- @tparam Vector2 pos A position relative to which the spheres will be destroyed.
-- @tparam number radius The range in pixels.
-- @tparam number color A color that any sphere must be matching with in order to destroy it.
function Session:destroyRadiusColor(pos, radius, color)
	self:destroyFunction(
		function(sphere, spherePos) return (pos - spherePos):len() <= radius and self:colorsMatch(color, sphere.color) end,
		pos
	)
end



--- Destroys all spheres that are closer than width pixels to the x position on X coordinate.
-- @tparam number x An X coordinate relative to which the spheres will be destroyed.
-- @tparam number width The range in pixels.
-- @tparam number color A color that any sphere must be matching with in order to destroy it.
function Session:destroyVerticalColor(x, width, color)
	self:destroyFunction(
		function(sphere, spherePos) return math.abs(x - spherePos.x) <= width / 2 and self:colorsMatch(color, sphere.color) end,
		self.level.shooter.pos + Vec2(0, -32)
	)
end

function Session:replaceColor(color1, color2, particle)
	self:setColorFunction(
		function(sphere, spherePos) return sphere.color == color1 end,
		color2, particle
	)
end

function Session:replaceColorRadiusColor(pos, radius, color, color2)
	self:setColorFunction(
		function(sphere, spherePos) return (pos - spherePos):len() <= radius and self:colorsMatch(color, sphere.color) end,
		color2
	)
end

function Session:getLowestMatchLength()
	local lowest = nil
	for i, path in ipairs(self.level.map.paths.objects) do
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

function Session:getSpheresWithMatchLength(matchLength, encourageMatches)
	if not matchLength then return {} end
	local spheres = {}
	for i, path in ipairs(self.level.map.paths.objects) do
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

function Session:getNearestSphere(pos)
	local nearestData = {path = nil, sphereChain = nil, sphereGroup = nil, sphereID = nil, sphere = nil, pos = nil, dist = nil, half = nil}
	for i, path in ipairs(self.level.map.paths.objects) do
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
					if not sphereHidden and (not nearestData.dist or sphereDist < nearestData.dist) then
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

function Session:getNearestSphereY(pos)
	local nearestData = {path = nil, sphereChain = nil, sphereGroup = nil, sphereID = nil, sphere = nil, pos = nil, dist = nil, targetPos = nil, half = nil}
	for i, path in ipairs(self.level.map.paths.objects) do
		for j, sphereChain in ipairs(path.sphereChains) do
			for k, sphereGroup in ipairs(sphereChain.sphereGroups) do
				for l, sphere in ipairs(sphereGroup.spheres) do
					local spherePos = sphereGroup:getSpherePos(l)
					local sphereAngle = sphereGroup:getSphereAngle(l)
					local sphereHidden = sphereGroup:getSphereHidden(l)

					local sphereTargetY = spherePos.y + math.sqrt(math.pow(16 --[[half of sphere size // note for placing constant here]], 2) - math.pow(pos.x - spherePos.x, 2))
					local sphereDist = Vec2(pos.x - spherePos.x, pos.y - sphereTargetY)

					local sphereDistAngle = (pos - spherePos):angle()
					local sphereAngleDiff = (sphereDistAngle - sphereAngle + math.pi / 2) % (math.pi * 2)
					local sphereHalf = sphereAngleDiff <= math.pi / 2 or sphereAngleDiff > 3 * math.pi / 2
					-- if closer than the closest for now, save it
					if not sphereHidden and math.abs(sphereDist.x) <= 16 and sphereDist.y >= 0 and (not nearestData.dist or sphereDist.y < nearestData.dist.y) then
						nearestData.path = path
						nearestData.sphereChain = sphereChain
						nearestData.sphereGroup = sphereGroup
						nearestData.sphereID = l
						nearestData.sphere = sphere
						nearestData.pos = spherePos
						nearestData.dist = sphereDist
						nearestData.targetPos = Vec2(pos.x, sphereTargetY)
						nearestData.half = sphereHalf
					end
				end
			end
		end
	end
	return nearestData
end



return Session
