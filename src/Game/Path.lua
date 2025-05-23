local class = require "com.class"

---Represents a single Path on which the Spheres move. Can have entites such as Bonus Scarabs or Scorpions.
---@class Path
---@overload fun(map, pathData, pathBehavior):Path
local Path = class:derive("Path")

local Vec2 = require("src.Essentials.Vector2")
local SphereChain = require("src.Game.SphereChain")
local PathEntity = require("src.Game.PathEntity")



---Constructs a new Path instance.
---@param map Map The map which this Path belongs to.
---@param pathData table A list of nodes this path has.
---@param pathBehavior table Path behavior which is going to be used in this level.
function Path:new(map, pathData, pathBehavior)
	self.map = map

	self.nodes = {}
	self.brightnesses = {}
	self.length = 0

	self.nodeBookmarks = {} -- node bookmark IDs start from 0 !!!
	self.nodeBookmarkCount = 0
	self.NODE_BOOKMARK_DELAY = 500

	local nodes = {}
	for i, node in ipairs(pathData) do
		nodes[i] = {pos = Vec2(node.x, node.y), scale = node.scale or 1, hidden = node.hidden, warp = node.warp}
	end

	self.trainRules = pathBehavior.trainRules
	self.currentWave = 0
	self.reachedFinalWave = false
	--[[
	if _Game.satMode then
		local n = _Game:getSession():getUSMNumber() * 10
		self.spawnRules = {
			--type = "waves",
			--amount = n
			type = "continuous"
		}
	end
	]]
	self.spawnAmount = 0
	self.spawnDistance = pathBehavior.spawnDistance
	self.dangerDistance = pathBehavior.dangerDistance
	self.dangerParticle = pathBehavior.dangerParticle or "particles/warning.json"
	self.speeds = pathBehavior.speeds

	self:prepareNodes(nodes)

	self.sphereChains = {}
	self.cascade = 0
	self.cascadeScore = 0
	self.clearOffset = 0
	self.pathEntities = {}
	self.sphereEffectGroups = {}
end



---Generates necessary data from node positions.
---@param nodes table The list of nodes.
function Path:prepareNodes(nodes)
	for i, node in ipairs(nodes) do
		local length = 0
		if nodes[i + 1] and not node.warp then length = (nodes[i + 1].pos - node.pos):len() end
		local angle1 = nil
		local angle2 = nil
		if nodes[i - 1] and not nodes[i - 1].warp then angle1 = (node.pos - nodes[i - 1].pos):angle() end
		if nodes[i + 1] and not node.warp then angle2 = (nodes[i + 1].pos - node.pos):angle() end
		-- compensation if wraps around 360°
		if angle1 and angle2 then
			if angle2 - angle1 > math.pi then angle2 = angle2 - 2 * math.pi end
			if angle1 - angle2 > math.pi then angle1 = angle1 - 2 * math.pi end
		end
		local angle = nil
		if angle1 then
			if angle2 then angle = (angle1 + angle2) / 2 else angle = angle1 end
		else
			if angle2 then angle = angle2 else angle = 0 end
		end
		angle = (angle + math.pi / 2) % (math.pi * 2)
		self.nodes[i] = {pos = node.pos, scale = node.scale, hidden = node.hidden, warp = node.warp, length = length, angle = angle}

		-- brightnesses stuff
		if node.hidden then
			if nodes[i - 1] and not nodes[i - 1].hidden then -- visible->hidden
				table.insert(self.brightnesses, {distance = self.length - 8, value = 1})
				table.insert(self.brightnesses, {distance = self.length + 8, value = 0.5})
			end
		else
			if nodes[i - 1] and nodes[i - 1].hidden then -- hidden->visible
				table.insert(self.brightnesses, {distance = self.length - 8, value = 0.5})
				table.insert(self.brightnesses, {distance = self.length + 8, value = 1})
			end
		end

		-- node bookmark stuff
		while (self.length + length) / self.NODE_BOOKMARK_DELAY > self.nodeBookmarkCount do
			self.nodeBookmarks[self.nodeBookmarkCount] = {id = i, distance = self.length + length}
			self.nodeBookmarkCount = self.nodeBookmarkCount + 1
			--print("Node Bookmark:", self.nodeBookmarkCount - 1, i)
		end

		self.length = self.length + length
	end

	-- if no tunnels we must add a placeholder
	if #self.brightnesses == 0 then table.insert(self.brightnesses, {distance = 0, value = 1}) end
end



---Updates the Path.
---@param dt number Delta time in seconds.
function Path:update(dt)
	for i, sphereChain in ipairs(self.sphereChains) do
		if not sphereChain.delQueue then
			sphereChain:update(dt)
		end
	end

	if self:shouldSpawn() then
		self:spawnChain()
	end

	for i, pathEntity in ipairs(self.pathEntities) do
		pathEntity:update(dt)
	end
	for i = #self.pathEntities, 1, -1 do
		local pathEntity = self.pathEntities[i]
		if pathEntity.delQueue then
			table.remove(self.pathEntities, i)
		end
	end

	-- Reset the cascade combo if necessary.
	if _Game.configManager.gameplay.sphereBehavior.cascadeScope == "path" and not self:isMatchPredicted() then
		self:endCascade()
	end
end



---Returns `true` if this Path will spawn a new Sphere Chain right now.
---@return boolean
function Path:shouldSpawn()
	if not self.map.isDummy and (self.map.level:getCurrentSequenceStepType() ~= "gameplay" or self.map.level:areAllObjectivesReached()) then
		return false
	end
	for i, sphereChain in ipairs(self.sphereChains) do
		if not sphereChain.delQueue and sphereChain.sphereGroups[#sphereChain.sphereGroups].offset < self.length * self.spawnDistance then
			return false
		end
	end
	return true
end



---Returns whether this path is in danger (spheres exist past the danger offset).
---@return boolean
function Path:isInDanger()
	return self:getDanger(self:getMaxOffset())
end



---Summons a new Sphere Chain on this Path.
function Path:spawnChain()
	self:advanceWave()
	local sphereChain = SphereChain(self)
	-- TODO: HARDCODED - make it configurable (launch speed - zero? path speed?)
	if not self.map.isDummy and self.map.level.levelSequenceVars.warmupTime then
		sphereChain.sphereGroups[1].speed = self.speeds[1].speed
	end
	table.insert(self.sphereChains, sphereChain)
	if not self.map.isDummy then
		self.map.level.sphereChainsSpawned = self.map.level.sphereChainsSpawned + 1
		_Game:playSound(_Game.resourceManager:getSoundEvent(_Game.configManager.gameplay.sphereBehavior.newGroupSound), self:getPos(0))
	end
end



---Returns `true` if at least one of the Sphere Chains on this Path has a predicted match.
---@return boolean
function Path:isMatchPredicted()
	for i, sphereChain in ipairs(self.sphereChains) do
		if sphereChain:isMatchPredicted() then
			return true
		end
	end
	return false
end



---Resets the cascade combo value for this Path to 0 and emits a `cascadeEnded` UI callback if the values were greater than 0.
function Path:endCascade()
	if self.cascade == 0 and self.cascadeScore == 0 then
		return
	end
	--_Debug.console:print("path " .. self.cascadeScore)
	_Game.uiManager:executeCallback({
		name = "cascadeEnded",
		parameters = {self.cascade, self.cascadeScore}
	})
	self.cascade = 0
	self.cascadeScore = 0
end



---Spawns a Path Entity on this Path.
---@param config PathEntityConfig The Path Entity Config to be used to create this Path Entity.
function Path:spawnPathEntity(config)
	table.insert(self.pathEntities, PathEntity(self, config))
end



---Returns whether there are any Path Entities on this Path.
---@return boolean
function Path:hasPathEntities()
	return #self.pathEntities > 0
end



-- TODO: Make a separate class for Train Rules.

---Returns all sphere colors that can spawn on this Path.
---@return table
function Path:getSpawnableColors()
	if self.trainRules.type == "random" then
		return _Utils.tableRemoveDuplicates(self.trainRules.colors)
	elseif self.trainRules.type == "pattern" then
		return _Utils.tableRemoveDuplicates(self.trainRules.pattern)
	elseif self.trainRules.type == "waves" then
		local colors = {}
		for i, key in ipairs(self.trainRules.key) do
			colors = _Utils.tableUnion(colors, key.colors)
		end
		return colors
	end
	error(string.format("Invalid trainRules type for the level: %s", self.trainRules.type))
end

---Advances or resets the wave pointer for the `"waves"` train rule type.
function Path:advanceWave()
	if not self.trainRules.type == "waves" then
		return
	end
	if self.trainRules.behavior == "random" then
		self.currentWave = math.random(#self.trainRules.waves)
	elseif self.trainRules.behavior == "panic" then
		if not self.reachedFinalWave then
			self.currentWave = self.currentWave + 1
			if self.currentWave == #self.trainRules.waves then
				self.reachedFinalWave = true
			end
		else
			self.currentWave = math.random(#self.trainRules.waves)
		end
	elseif self.trainRules.behavior == "repeatLast" then
		if self.currentWave < #self.trainRules.waves then
			self.currentWave = self.currentWave + 1
		end
	elseif self.trainRules.behavior == "repeat" then
		if self.currentWave < #self.trainRules.waves then
			self.currentWave = self.currentWave + 1
		else
			self.currentWave = 1
		end
	end
end

---Works only if `trainRules.type == "waves"`. Returns the current wave as a string.
---@return string
function Path:getCurrentTrainPreset()
	assert(self.trainRules.type == "waves", "Incorrect getCurrentTrainPreset call, this should never happen")
	return self.trainRules.waves[self.currentWave]
end

---Returns the length of the current train (on the current wave), or `nil` if the train is going to be continuous.
---@return integer?
function Path:getCurrentTrainLength()
	if self.trainRules.type == "waves" then
		local preset = self.trainRules.waves[self.currentWave]
		if not tonumber(preset:sub(1, 1)) then
			return preset:len()
		else
			local length = 0
			-- Count the length of each block.
			for i, strBlock in ipairs(_Utils.strSplit(preset, ",")) do
				local spl = _Utils.strSplit(strBlock, ":")
				spl = _Utils.strSplit(spl[1], "*")
				length = length + tonumber(spl[1]) * tonumber(spl[2])
			end
			return length
		end
	else
		return self.trainRules.length
	end
end



-- TODO: Make a Sphere Effect Group a separate class.

---Creates a new sphere effect group and returns its ID.
---These are used to group spheres which have the same effect caused by a single sphere.
---@param sphere Sphere The "cause" sphere.
---@return integer
function Path:createSphereEffectGroup(sphere)
	-- Generate first non-occupied sphere effect group ID.
	local n = 1
	while self.sphereEffectGroups[n] do
		n = n + 1
	end
	-- Insert startup data.
	self.sphereEffectGroups[n] = {
		count = 0,
		cause = sphere
	}
	-- Return the ID of the group for usage in the future.
	return n
end



---Returns data of a sphere effect group with given ID.
---@param n integer The ID of a sphere effect.
---@return table
function Path:getSphereEffectGroup(n)
	return self.sphereEffectGroups[n]
end



---Increments a sphere effect group counter.
---@param n integer The ID of a sphere effect.
function Path:incrementSphereEffectGroup(n)
	self.sphereEffectGroups[n].count = self.sphereEffectGroups[n].count + 1
end



---Decrements a sphere effect group counter. If it reaches 0, it's destroyed.
---@param n integer The ID of a sphere effect.
function Path:decrementSphereEffectGroup(n)
	self.sphereEffectGroups[n].count = self.sphereEffectGroups[n].count - 1
	if self.sphereEffectGroups[n].count == 0 then
		self.sphereEffectGroups[n] = nil
	end
end



---Sets three Expression Variables corresponding to this Path to be used in Expressions.
---
---These variables are:
--- - `offset`: ranging from 0 to path length, from start point.
--- - `offsetE`: ranging from 0 to path length, from end point.
--- - `distance`: ranging from 0 to 1, from start point. Universal formula for end point: `1 - [distance]`.
---
--- Warning: These variables are NOT clamped and can go outside of the path.
---@param context string The Expression Context inside which these values will be located.
---@param offset number The path offset to be used in calculation, in pixels.
function Path:setOffsetVars(context, offset)
	_Vars:set(context .. ".offset", offset)
	_Vars:set(context .. ".offsetE", self.length - offset)
	_Vars:set(context .. ".distance", offset / self.length)
end



---Deinitializes this Path and its components.
function Path:destroy()
	for i, sphereChain in ipairs(self.sphereChains) do
		sphereChain:destroy()
	end
	for i, pathEntity in ipairs(self.pathEntities) do
		pathEntity:destroy()
	end
end



---Draws spheres on this Path.
---@param hidden boolean Whether to draw spheres in the hidden pass.
---@param shadow boolean If `true`, the shadows will be drawn. Else, the actual sprites.
function Path:drawSpheres(hidden, shadow)
	-- hidden: with that, you can filter the spheres drawn either to the visible ones or to the invisible ones
	for i, sphereChain in pairs(self.sphereChains) do
		sphereChain:draw(hidden, shadow)
	end
end



---Draws entities which are on this Path.
---@param hidden boolean Whether to draw the entities in the hidden pass.
function Path:draw(hidden)
	-- hidden: with that, you can filter the spheres drawn either to the visible ones or to the invisible ones
	for i, pathEntity in ipairs(self.pathEntities) do
		pathEntity:draw(hidden, true)
		pathEntity:draw(hidden, false)
	end

	if not hidden then
		--self:drawDebugBrightness()
	end
end



---Draws a light blue line of the path, with highlighted nodes.
function Path:drawDebug()
	-- todo: make the mouse position global
	--local mx, my = love.mouse.getPosition()

	love.graphics.setLineWidth(1)
	love.graphics.setColor(0, 1, 1)
	for i, node in ipairs(self.nodes) do
		love.graphics.rectangle("line", node.pos.x - 4, node.pos.y - 4, 8, 8)
		--if mx > node.pos.x - 4 and mx < node.pos.x + 4 and my > node.pos.y - 4 and my < node.pos.y + 4 then
		--	love.graphics.print(tostring(node.angle), node.pos.x + 8, node.pos.y)
		--end
		if i > 1 then
			love.graphics.line(self.nodes[i - 1].pos.x, self.nodes[i - 1].pos.y, node.pos.x, node.pos.y)
		end
	end
end



---Another debug function.
function Path:drawDebugBrightness()
	for i = 0, 799 do
		local d = self.length / 799 * i
		local h = self:getSpeed(d) / 20
		local n, r = self:getNodeID(d)
		local t = r < 1
		if t then
			love.graphics.setColor(0, 1, 1)
			love.graphics.rectangle("fill", i, 36, 1, 64)
		else
			love.graphics.setColor(1, 0, 0)
			love.graphics.rectangle("fill", i, 100 - h, 1, h)
		end
	end
end



---Yet another debug function.
function Path:drawDebugLine()
	for i = 0, self.length, 5 do
		love.graphics.setColor(math.sqrt(self:getSpeed(i)) / 30, 0, 0)
		local pos = self:getPos(i)
		love.graphics.circle("fill", pos.x, pos.y, 5)
	end
end



---Even one more debug function.
---This one draws a circle where the max offset is located.
function Path:drawDebugFill()
	love.graphics.setColor(1, 0.2, 0)
	local pos = self:getPos(self:getMaxOffset())
	love.graphics.circle("fill", pos.x, pos.y, 10)
end



---Returns the ID of a given Sphere Chain. If not found, returns `nil`.
---@param sphereChain SphereChain The Sphere Chain of which ID will be returned.
---@return integer|nil
function Path:getSphereChainID(sphereChain)
	for i, sphereChainT in pairs(self.sphereChains) do
		if sphereChainT == sphereChain then
			return i
		end
	end
end

---Returns the first (frontmost) Sphere Chain on this Path.
---@return SphereChain
function Path:getFirstSphereChain()
	return self.sphereChains[1]
end

---Returns the last (backmost) Sphere Chain on this Path.
---@return SphereChain
function Path:getLastSphereChain()
	return self.sphereChains[#self.sphereChains]
end



---Returns the offset of the frontmost sphere on this Path.
---@return number
function Path:getMaxOffset()
	local offset = 0
	for i, sphereChain in ipairs(self.sphereChains) do
		offset = math.max(offset, sphereChain.maxOffset)
	end
	return offset
end



---Returns 0 if this path is not in danger, and linearly interpolates from 0 (danger point) to 1 (end of the path).
---@return number
function Path:getDangerProgress()
	local maxOffset = self:getMaxOffset()
	if not self:getDanger(maxOffset) then
		return 0
	end
	return ((maxOffset / self.length) - self.dangerDistance) / (1 - self.dangerDistance)
end



---Returns the path speed at a given offset.
---@param pixels number The path offset to be checked, in pixels.
---@return number
function Path:getSpeed(pixels)
	local speedMultiplier = 1
	if not self.map.isDummy and _Game:getSession() then
		if _Game.satMode then
			speedMultiplier = 1 + (_Game:getSession():getUSMNumber() - 1) * 0.05
		end
		speedMultiplier = speedMultiplier * _Game:getSession():getDifficultyConfig().speedMultiplier
	end

	for i, speed in ipairs(self.speeds) do
		local speedOffset = self:getSpeedOffset(speed)
		if pixels < speedOffset then
			local prevSpeed = self.speeds[i - 1]
			local prevSpeedOffset = prevSpeed and self:getSpeedOffset(prevSpeed)
			if prevSpeed and speedOffset - prevSpeedOffset > 0 then
				-- between nodes
				-- The transition is linear by default.
				local t = 1 - (speedOffset - pixels) / (speedOffset - prevSpeedOffset)
				if prevSpeed.transition and prevSpeed.transition.type == "bezier" then
					local p1 = prevSpeed.transition.point1
					local p2 = prevSpeed.transition.point2
					t = _Utils.bzLerp(t, p1, p2)
				elseif prevSpeed.transition.type == "instant" then
					t = 0
				end
				return (prevSpeed.speed * (1 - t) + speed.speed * t) * speedMultiplier
			end

			-- at the exact position of node or before first node
			return speed.speed * speedMultiplier
		end
	end

	-- after last node
	return self.speeds[#self.speeds].speed * speedMultiplier
end



---Returns the offset (distance of a speed node in pixels counting from the first node), depending on what data is contained inside.
---@param speed table The speed data, an entry from `self.speeds`.
---@return number
function Path:getSpeedOffset(speed)
	if speed.distance then
		return speed.distance * self.length
	elseif speed.offset then
		return speed.offset
	elseif speed.offsetFromEnd then
		return self.length - speed.offsetFromEnd
	end
	error("Level error: in a speed node - neither `distance`, `offset` nor `offsetFromEnd` were specified")
end



---Returns `true` if this Path does not contain any spheres.
---
---Warning: this does NOT check for Path Entities. Use `:hasPathEntities()` for that instead.
---@return boolean
function Path:getEmpty()
	return #self.sphereChains == 0
end



---Returns `true` if the given offset is past the danger point.
---@param pixels number The path offset to be considered, in pixels.
---@return boolean
function Path:getDanger(pixels)
	return pixels / self.length >= self.dangerDistance
end



---Unused, or at least that's what they told me. Or did I tell that to myself?
---@param pixels number The path offset to be considered, in pixels.
---@return integer
function Path:getBookmarkID(pixels)
	return math.min(math.floor(pixels / self.NODE_BOOKMARK_DELAY), self.nodeBookmarkCount - 1)
end



---Returns a node ID and how many pixels afterwards the given position is.
---@param pixels number The path offset to be considered, in pixels.
---@return integer
---@return number
function Path:getNodeID(pixels)
	if pixels < 0 then return 0, pixels end

	local nodeBookmark = self.nodeBookmarks[self:getBookmarkID(pixels)]
	local nodeID = nodeBookmark.id
	pixels = pixels - nodeBookmark.distance
	while pixels > 0 do
		nodeID = nodeID + 1
		if not self.nodes[nodeID] then break end
		pixels = pixels - self.nodes[nodeID].length
	end
	-- returns a node ID and how many pixels afterwards the given position is
	local remainder = pixels
	if self.nodes[nodeID] then remainder = self.nodes[nodeID].length + pixels end
	return nodeID, remainder
end



---Returns the onscreen position at the given offset of this Path.
---@param pixels number The path offset to be considered, in pixels.
---@return Vector2
function Path:getPos(pixels)
	local nodeID, remainder = self:getNodeID(pixels)
	if nodeID == 0 then
		return self.nodes[1].pos
	elseif nodeID > #self.nodes then
		return self.nodes[#self.nodes].pos
		-- uncomment the below one for extending after the final node
		--return self.nodes[#self.nodes].pos + Vec2(0, -remainder):rotate(self.nodes[#self.nodes].angle) end
	end
	local part = remainder / self.nodes[nodeID].length
	---@type Vector2
	local p1 = self.nodes[nodeID].pos
	---@type Vector2
	local p2 = self.nodes[nodeID + 1].pos
	return p1 * (1 - part) + p2 * part
end



---Returns the path angle at the given offset of this Path, in radians.
---@param pixels number The path offset to be considered, in pixels.
---@return number
function Path:getAngle(pixels)
	local p1 = self:getPos(pixels - 16)
	local p2 = self:getPos(pixels + 16)
	-- get IDs of this node, and ID of nodes 16 pixels behind and 16 pixels ahead
	local id1 = self:getNodeID(pixels - 16)
	local id = self:getNodeID(pixels)
	local id2 = self:getNodeID(pixels + 16)
	-- look for warp nodes behind
	for i = id1, id - 1 do
		if self.nodes[i] and self.nodes[i].warp then
			p1 = self.nodes[i + 1].pos
			break
		end
	end
	-- and ahead
	for i = id, id2 do
		if self.nodes[i] and self.nodes[i].warp then
			p2 = self.nodes[i].pos
			break
		end
	end
	return (p2 - p1):angle() + math.pi / 2
end



---Returns the scale of the spheres at the given offset of this Path.
---@param pixels number The path offset to be considered, in pixels.
---@return number
function Path:getScale(pixels)
	local nodeID, remainder = self:getNodeID(pixels)
	if nodeID == 0 then
		return self.nodes[1].scale
	elseif nodeID > #self.nodes then
		return self.nodes[#self.nodes].scale
	end
	local part = remainder / self.nodes[nodeID].length
	---@type Vector2
	local p1 = self.nodes[nodeID].scale
	---@type Vector2
	local p2 = self.nodes[nodeID + 1].scale
	return p1 * (1 - part) + p2 * part
end



---Returns `true` if this path is hidden at a given offset.
---@param pixels number The path offset to be considered, in pixels.
---@return boolean
function Path:getHidden(pixels)
	local nodeID = self:getNodeID(pixels)
	if nodeID == 0 then return self.nodes[1].hidden end
	if nodeID > #self.nodes then return self.nodes[#self.nodes].hidden end
	return self.nodes[nodeID].hidden
end



---Returns the path brightness at a given point of the path.
---@param pixels number The path offset to be considered, in pixels.
---@return number
function Path:getBrightness(pixels)
	for i, brightness in ipairs(self.brightnesses) do
		if pixels < brightness.distance then
			local prevBrightness = self.brightnesses[i - 1]
			if prevBrightness and brightness.distance - prevBrightness.distance > 0 then
				local t = (brightness.distance - pixels) / (brightness.distance - prevBrightness.distance)
				return prevBrightness.value * t + brightness.value * (1 - t)
			end
			return brightness.value
		end
	end
	return self.brightnesses[#self.brightnesses].value
end



---Returns the path offset(s) at which the given line intersects this path. Only crossings with a single distinct point count.
---@param p1x number The X coordinate of the start point of the line.
---@param p1y number The Y coordinate of the start point of the line.
---@param p2x number The X coordinate of the end point of the line.
---@param p2y number The Y coordinate of the end point of the line.
---@return table
function Path:getIntersectionPoints(p1x, p1y, p2x, p2y)
	local pminX, pminY = math.min(p1x, p2x), math.min(p1y, p2y)
	local pmaxX, pmaxY = math.max(p1x, p2x), math.max(p1y, p2y)
	local distance = 0
	local intersections = {}

	for i, node in ipairs(self.nodes) do
		local node2 = self.nodes[i + 1]
		if not node2 then -- this is the last node; no line there
			break
		end
		-- Eliminate all impossible cases for optimization.
		local p3x, p3y = node.pos.x, node.pos.y
		local p4x, p4y = node2.pos.x, node2.pos.y
		if not (math.max(p3x, p4x) < pminX or math.min(p3x, p4x) > pmaxX or math.max(p3y, p4y) < pminY or math.min(p3y, p4y) > pmaxY) then
			-- We're going to use the algorithm from https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect
			-- For convenience, we will arrange and name the variables so that they match the ones described in the website above.
			local px, py = p1x, p1y
			local qx, qy = p3x, p3y
			local rx, ry = p2x - p1x, p2y - p1y
			local sx, sy = p4x - p3x, p4y - p3y
			local rcs = _V.cross(rx, ry, sx, sy)
			local t = _V.cross(qx - px, qy - py, sx / rcs, sy / rcs)
			local u = _V.cross(qx - px, qy - py, rx / rcs, ry / rcs)
			-- t/u < 1 instead of t/u <= 1 is intentional - this way if the line crosses a node perfectly it won't count as two intersections.
			if rcs ~= 0 and t >= 0 and t < 1 and u >= 0 and u < 1 then
				table.insert(intersections, distance + node.length * u)
			end
		end
		distance = distance + node.length
	end

	return intersections
end



---If this path has no spheres at a given offset and is in the middle of a sphere chain, returns the length of the gap and the first sphere group enclosing it, `nil` otherwise.
---@param offset number Path offset in pixels.
---@return number?
---@return SphereGroup?
function Path:getGapSize(offset)
	for i, sphereChain in ipairs(self.sphereChains) do
		-- Consider only a sphere chain which has the given offset inside itself.
		if sphereChain:getFirstSphereGroup():getFrontPos() > offset and sphereChain:getLastSphereGroup():getBackPos() < offset then
			for j, sphereGroup in ipairs(sphereChain.sphereGroups) do
				if sphereGroup.nextGroup and sphereGroup.nextGroup:getBackPos() > offset and sphereGroup:getFrontPos() < offset then
					return sphereGroup.nextGroup:getBackPos() - sphereGroup:getFrontPos(), sphereGroup
				end
			end
		end
	end
	return nil, nil
end



---Returns serialized data of this Path to be saved.
---@return table
function Path:serialize()
	local t = {
		sphereChains = {},
		currentWave = self.currentWave,
		reachedFinalWave = self.reachedFinalWave,
		cascade = self.cascade,
		cascadeScore = self.cascadeScore,
		clearOffset = self.clearOffset,
		pathEntities = {},
		sphereEffectGroups = {}
	}
	for i, sphereChain in ipairs(self.sphereChains) do
		table.insert(t.sphereChains, sphereChain:serialize())
	end
	for i, pathEntity in ipairs(self.pathEntities) do
		table.insert(t.pathEntities, pathEntity:serialize())
	end
	for i, sphereEffectGroup in pairs(self.sphereEffectGroups) do
		local tt = {}
		tt.count = sphereEffectGroup.count
		tt.cause = sphereEffectGroup.cause:getIDs()
		t.sphereEffectGroups[tostring(i)] = tt
	end
	return t
end



---Deserializes and loads data from previously serialized data.
---@param t table Data to be deserialized.
function Path:deserialize(t)
	self.sphereChains = {}
	for i, sphereChain in ipairs(t.sphereChains) do
		table.insert(self.sphereChains, SphereChain(self, sphereChain))
	end
	self.currentWave = t.currentWave
	self.reachedFinalWave = t.reachedFinalWave
	self.cascade = t.cascade
	self.cascadeScore = t.cascadeScore
	self.clearOffset = t.clearOffset
	self.pathEntities = {}
	for i, pathEntity in ipairs(t.pathEntities) do
		table.insert(self.pathEntities, PathEntity(self, pathEntity))
	end
	self.sphereEffectGroups = {}
	for i, sphereEffectGroup in pairs(t.sphereEffectGroups) do
		local tt = {}
		tt.count = sphereEffectGroup.count
		tt.cause = self.sphereChains[sphereEffectGroup.cause.chainID].sphereGroups[sphereEffectGroup.cause.groupID].spheres[sphereEffectGroup.cause.sphereID]
		self.sphereEffectGroups[tonumber(i)] = tt
	end
end



return Path
