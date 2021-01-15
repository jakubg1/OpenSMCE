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
	self.scoreDisplay = 0
	
	self.level = nil
	self.colorManager = ColorManager()
end



--- An initialization callback.
function Session:init()
	game:executeCallback("sessionInit")
end



--- An update callback.
-- @tparam number dt Delta time in seconds.
function Session:update(dt)
	if self.level then self.level:update(dt) end
	
	-- TODO: HARDCODED - make it more flexible
	if self.scoreDisplay < game.runtimeManager.profile:getScore() then self.scoreDisplay = self.scoreDisplay + math.ceil((game.runtimeManager.profile:getScore() - self.scoreDisplay) / 10) end
end



--- Initializes a new level.
-- The level number is derived from the current Profile.
function Session:startLevel()
	--self.level = Level({path = "levels/level_7_2.json", name = game.runtimeManager.profile.data.session.level})
	--self.level = Level({path = "levels/seven_lines.json", name = "0-0"})
	self.level = Level(game.runtimeManager.profile:getCurrentLevelData())
	local savedLevelData = game.runtimeManager.profile:getSavedLevel()
	if savedLevelData then
		self.level:deserialize(savedLevelData)
		game:executeCallback("levelLoaded")
	else
		game:executeCallback("levelStart")
	end
end



--- Triggers a Game Over.
-- Deinitializates the level and shows an appropriate widget.
function Session:terminate()
	self.level = nil
	game:executeCallback("gameOver")
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
	local matches = game.spheres[color1].matches
	for i, v in ipairs(matches) do
		if v == color2 then return true end
	end
	return false
end



function Session:usePowerupEffect(effect, color)
	if effect.type == "replaceSphere" then
		self.level.shooter:getSphere(effect.color)
	elseif effect.type == "multiSphere" then
		self.level.shooter:getMultiSphere(effect.color, effect.count)
	elseif effect.type == "speedShot" then
		self.level.shooter.speedShotTime = effect.time
	elseif effect.type == "slow" then
		for i, path in ipairs(self.level.map.paths.objects) do
			for j, sphereChain in ipairs(path.sphereChains) do
				sphereChain.slowTime = effect.time
				sphereChain.stopTime = 0
				sphereChain.reverseTime = 0
			end
		end
	elseif effect.type == "stop" then
		for i, path in ipairs(self.level.map.paths.objects) do
			for j, sphereChain in ipairs(path.sphereChains) do
				sphereChain.slowTime = 0
				sphereChain.stopTime = effect.time
				sphereChain.reverseTime = 0
			end
		end
	elseif effect.type == "reverse" then
		for i, path in ipairs(self.level.map.paths.objects) do
			for j, sphereChain in ipairs(path.sphereChains) do
				sphereChain.slowTime = 0
				sphereChain.stopTime = 0
				sphereChain.reverseTime = effect.time
			end
		end
	elseif effect.type == "destroyColor" then
		self:destroyColor(color)
	end
end



--- Destroys all spheres on the board if a call of the function f(sphere, spherePos) returns true.
-- @tparam function t The function that has to return true in order for a given sphere to be deleted.
-- @tparam Vector2 scorePos A position where the score text should be located.
function Session:destroyFunction(f, scorePos)
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
	self.level:spawnFloatingText(numStr(score), scorePos, "fonts/score0.json")
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