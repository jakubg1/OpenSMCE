local class = require "com/class"

---@class Path
---@overload fun(map, pathData, pathBehavior):Path
local Path = class:derive("Path")

local Vec2 = require("src/Essentials/Vector2")
local SphereChain = require("src/SphereChain")
local BonusScarab = require("src/BonusScarab")
local Scorpion = require("src/Scorpion")



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
		nodes[i] = {pos = Vec2(node.x, node.y), hidden = node.hidden, warp = node.warp}
	end

	self.colors = pathBehavior.colors
	self.colorStreak = pathBehavior.colorStreak
	self.spawnRules = pathBehavior.spawnRules
	if _Game.satMode then
		local n = _Game:getCurrentProfile():getUSMNumber() * 10
		self.spawnRules = {
			--type = "waves",
			--amount = n
			type = "continuous"
		}
	end
	self.spawnAmount = 0
	self.spawnDistance = pathBehavior.spawnDistance
	self.dangerDistance = pathBehavior.dangerDistance
	self.dangerParticle = pathBehavior.dangerParticle or "particles/warning.json"
	self.speeds = pathBehavior.speeds

	--self:prepareNodes({Vec2(0, 200), Vec2(500, 200), Vec2(515, 200), Vec2(520, 205), Vec2(520, 220), Vec2(520, 400)})
	self:prepareNodes(nodes)

	self.sphereChains = {}
	self.clearOffset = 0
	self.bonusScarab = nil
	self.scorpions = {}
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
		self.nodes[i] = {pos = node.pos, hidden = node.hidden, warp = node.warp, length = length, angle = angle}

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
	if self:shouldSpawn() then self:spawnChain() end
	if self.bonusScarab then self.bonusScarab:update(dt) end

	for i, scorpion in ipairs(self.scorpions) do
		scorpion:update(dt)
	end
	for i = #self.scorpions, 1, -1 do
		local scorpion = self.scorpions[i]
		if scorpion.delQueue then table.remove(self.scorpions, i) end
	end
end



---Returns a random entry from the list of sphere types this Path can spawn.
---@return integer
function Path:newSphereColor()
	return self.colors[math.random(1, #self.colors)]
end



---Returns `true` if this Path will spawn a new Sphere Chain right now.
---@return boolean
function Path:shouldSpawn()
	if _Game:levelExists() and (not self.map.level.started or self.map.level:areAllObjectivesReached() or self.map.level.lost) then return false end
	for i, sphereChain in ipairs(self.sphereChains) do
		if not sphereChain.delQueue and sphereChain.sphereGroups[#sphereChain.sphereGroups].offset < self.length * self.spawnDistance then return false end
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
	local sphereChain = SphereChain(self)
	if self.map.level.controlDelay then sphereChain.sphereGroups[1].speed = self.speeds[1].speed end
	table.insert(self.sphereChains, sphereChain)
	if not self.map.isDummy then
		self.map.level.sphereChainsSpawned = self.map.level.sphereChainsSpawned + 1
		_Game:playSound(_Game.configManager.gameplay.sphereBehaviour.newGroupSound)
	end
end



---Spawns a Bonus Scarab on this Path.
function Path:spawnBonusScarab()
	self.bonusScarab = BonusScarab(self)
end



---Spawns a Scorpion on this Path.
function Path:spawnScorpion()
	table.insert(self.scorpions, Scorpion(self))
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
---These variables are named: `offset`, `offsetE` and `distance`.
---@param offset number The path offset to be used in calculation, in pixels.
function Path:dumpOffsetVars(offset)
	-- Three different variables, to use whichever works best.
	-- offset: ranging from 0 to path length, from start point.
	_Vars:set("offset", offset)
	-- offsetE: ranging from 0 to path length, from end point.
	_Vars:set("offsetE", self.length - offset)
	-- distance: ranging from 0 to 1, from start point. Universal formula for end point: 1 - [distance].
	_Vars:set("distance", offset / self.length)
end



---Deinitializes this Path and its components.
function Path:destroy()
	for i, sphereChain in ipairs(self.sphereChains) do
		sphereChain:destroy()
	end
	if self.bonusScarab then
		self.bonusScarab:destroy()
	end
	--self.bonusScarab = nil
	for i, scorpion in ipairs(self.scorpions) do
		scorpion:destroy()
	end
	--self.scorpions = {}
end



---Draws spheres on this Path.
---@param color integer Only spheres with this ID will be drawn.
---@param hidden boolean Whether to draw spheres in the hidden pass.
---@param shadow boolean If `true`, the shadows will be drawn. Else, the actual sprites.
function Path:drawSpheres(color, hidden, shadow)
	-- color: draw only spheres with a given color - this will enable batching and will reduce drawing time significantly
	-- hidden: with that, you can filter the spheres drawn either to the visible ones or to the invisible ones
	for i, sphereChain in pairs(self.sphereChains) do
		sphereChain:draw(color, hidden, shadow)
	end
end



---Draws entities which are on this Path.
---@param hidden boolean Whether to draw the entities in the hidden pass.
function Path:draw(hidden)
	-- hidden: with that, you can filter the spheres drawn either to the visible ones or to the invisible ones
	if self.bonusScarab then
		self.bonusScarab:draw(hidden, true)
		self.bonusScarab:draw(hidden, false)
	end

	for i, scorpion in ipairs(self.scorpions) do
		scorpion:draw(hidden, true)
		scorpion:draw(hidden, false)
	end

	--if not hidden then self:drawDebugFill() end
end



---Debug stuff.
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
		if i > 1 then love.graphics.line(self.nodes[i - 1].pos.x, self.nodes[i - 1].pos.y, node.pos.x, node.pos.y) end
	end
end



---Another debug function.
function Path:drawDebugBrightness()
	for i = 1, 800 do
		local h = self:getSpeed(i) / 20
		local n, r = self:getNodeID(i)
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
function Path:drawDebugFill()
	love.graphics.setColor(1, 0.2, 0)
	local pos = _PosOnScreen(self:getPos(self:getMaxOffset()))
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
	local satModeMult = 1
	if _Game.satMode and _Game:getCurrentProfile().session then
		satModeMult = 1 + (_Game:getCurrentProfile():getUSMNumber() - 1) * 0.05
	end

	local part = pixels / self.length
	for i, speed in ipairs(self.speeds) do
		if part < speed.distance then
			local prevSpeed = self.speeds[i - 1]
			if prevSpeed and speed.distance - prevSpeed.distance > 0 then
				local t = 1 - (speed.distance - part) / (speed.distance - prevSpeed.distance)

				-- between nodes
				if prevSpeed.transition and prevSpeed.transition.type == "bezier" then
					local p1 = prevSpeed.transition.point1
					local p2 = prevSpeed.transition.point2
					t = _BzLerp(t, p1, p2)
				end
				return (prevSpeed.speed * (1 - t) + speed.speed * t) * satModeMult
			end

			-- at the exact position of node or before first node
			return speed.speed * satModeMult
		end
	end

	-- after last node
	return self.speeds[#self.speeds].speed * satModeMult
end



---Returns `true` if this Path does not contain any spheres.
---Warning: this does NOT check for Scorpions or Bonus Scarabs.
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
---@param p1 Vector2 The start point of the line.
---@param p2 Vector2 The end point of the line.
---@return table
function Path:getIntersectionPoints(p1, p2)
	local distance = 0
	local intersections = {}

	for i, node in ipairs(self.nodes) do
		local node2 = self.nodes[i + 1]
		if not node2 then -- this is the last node; no line there
			break
		end
		-- We're going to use the algorithm from https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect
		-- For convenience, we will arrange and name the variables so that they match the ones described in the website above.
		local p = p1
		local q = node.pos
		local r = p2 - p1
		local s = node2.pos - q
		local t = (q - p):cross(s / r:cross(s))
		local u = (q - p):cross(r / r:cross(s))
		-- t/u < 1 instead of t/u <= 1 is intentional - this way if the line crosses a node perfectly it won't count as two intersections.
		if r:cross(s) ~= 0 and t >= 0 and t < 1 and u >= 0 and u < 1 then
			table.insert(intersections, distance + node.length * u)
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
		clearOffset = self.clearOffset,
		bonusScarab = self.bonusScarab and self.bonusScarab:serialize() or nil,
		scorpions = {},
		sphereEffectGroups = {}
	}
	for i, sphereChain in ipairs(self.sphereChains) do
		table.insert(t.sphereChains, sphereChain:serialize())
	end
	for i, scorpion in ipairs(self.scorpions) do
		table.insert(t.scorpions, scorpion:serialize())
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
	self.clearOffset = t.clearOffset
	self.bonusScarab = t.bonusScarab and BonusScarab(self, t.bonusScarab) or nil
	self.scorpions = {}
	for i, scorpion in ipairs(t.scorpions) do
		table.insert(self.scorpions, Scorpion(self, scorpion))
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
