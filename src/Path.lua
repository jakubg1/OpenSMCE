local class = require "com/class"
local Path = class:derive("Path")

local Vec2 = require("src/Essentials/Vector2")
local SphereChain = require("src/SphereChain")
local BonusScarab = require("src/BonusScarab")
local Scorpion = require("src/Scorpion")

function Path:new(map, pathData)
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

	--self:prepareNodes({Vec2(0, 200), Vec2(500, 200), Vec2(515, 200), Vec2(520, 205), Vec2(520, 220), Vec2(520, 400)})
	self:prepareNodes(nodes)

	self.sphereChains = {}
	self.clearOffset = 0
	self.bonusScarab = nil
	self.scorpions = {}
end

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

function Path:update(dt)
	for i, sphereChain in ipairs(self.sphereChains) do
		if not sphereChain.delQueue then
			sphereChain:update(dt)
			if i > 1 and
				not self.sphereChains[i - 1].delQueue and
				sphereChain.sphereGroups[1]:getLastSphereOffset() >= self.sphereChains[i - 1]:getLastSphereGroup():getSphereOffset(1) - 32
			then
				self.sphereChains[i - 1]:join()
			end
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

function Path:shouldSpawn()
	if game:levelExists() and (not self.map.level.started or self.map.level.targetReached or self.map.level.lost) then return false end
	for i, sphereChain in ipairs(self.sphereChains) do
		if not sphereChain.delQueue and sphereChain.sphereGroups[#sphereChain.sphereGroups].offset < self.length * self.map.level.spawnDistance then return false end
	end
	return true
end

function Path:spawnChain()
	local sphereChain = SphereChain(self)
	if self.map.level.controlDelay then sphereChain.sphereGroups[1].speed = self.map.level.speeds[1].speed end
	table.insert(self.sphereChains, sphereChain)
	if not self.map.isDummy then
		self.map.level.sphereChainsSpawned = self.map.level.sphereChainsSpawned + 1
		game:playSound("sphere_chain_spawn")
	end
end

function Path:spawnBonusScarab()
	self.bonusScarab = BonusScarab(self)
end

function Path:spawnScorpion()
	table.insert(self.scorpions, Scorpion(self))
end



function Path:drawSpheres(color, hidden)
	-- color: draw only spheres with a given color - this will enable batching and will reduce drawing time significantly
	-- hidden: with that, you can filter the spheres drawn either to the visible ones or to the invisible ones
	for i, sphereChain in pairs(self.sphereChains) do
		sphereChain:draw(color, hidden, true)
		sphereChain:draw(color, hidden, false)
	end
end

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

function Path:drawDebugLine()
	for i = 0, self.length, 5 do
		love.graphics.setColor(math.sqrt(self:getSpeed(i)) / 30, 0, 0)
		local pos = self:getPos(i)
		love.graphics.circle("fill", pos.x, pos.y, 5)
	end
end

function Path:drawDebugFill()
	love.graphics.setColor(1, 0.2, 0)
	local pos = posOnScreen(self:getPos(self:getMaxOffset()))
	love.graphics.circle("fill", pos.x, pos.y, 10)
end

function Path:getSphereChainID(sphereChain)
	for i, sphereChainT in pairs(self.sphereChains) do if sphereChainT == sphereChain then return i end end
end

function Path:getMaxOffset()
	local offset = 0
	for i, sphereChain in ipairs(self.sphereChains) do
		offset = math.max(offset, sphereChain.maxOffset)
	end
	return offset
end

function Path:getSpeed(pixels)
	local part = pixels / self.length
	for i, speed in ipairs(self.map.level.speeds) do
		if part < speed.distance then
			local prevSpeed = self.map.level.speeds[i - 1]
			if prevSpeed and speed.distance - prevSpeed.distance > 0 then
				local t = (speed.distance - part) / (speed.distance - prevSpeed.distance)

				-- between nodes
				if game.satMode then
					return (prevSpeed.speed * t + speed.speed * (1 - t)) * (1 + (game.runtimeManager.profile.data.session.level - 1) * 0.05)
				else
					return prevSpeed.speed * t + speed.speed * (1 - t)
				end
			end

			-- at the exact position of node or before first node
			if game.satMode then
				return speed.speed * (1 + (game.runtimeManager.profile.data.session.level - 1) * 0.05)
			else
				return speed.speed
			end
		end
	end

	-- after last node
	if game.satMode then
		return self.map.level.speeds[#self.map.level.speeds].speed * (1 + (game.runtimeManager.profile.data.session.level - 1) * 0.05)
	else
		return self.map.level.speeds[#self.map.level.speeds].speed
	end
end

function Path:getEmpty()
	return #self.sphereChains == 0
end

function Path:getDanger(pixels)
	return pixels / self.length >= self.map.level.dangerDistance
end

function Path:getBookmarkID(pixels)
	return math.min(math.floor(pixels / self.NODE_BOOKMARK_DELAY), self.nodeBookmarkCount - 1)
end

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

function Path:getPos(pixels)
	if pixels then
		local nodeID, remainder = self:getNodeID(pixels)
		if nodeID == 0 then return self.nodes[1].pos end
		if nodeID > #self.nodes then return self.nodes[#self.nodes].pos end -- + Vec2(0, -remainder):rotate(self.nodes[#self.nodes].angle) end
		local part = remainder / self.nodes[nodeID].length
		return self.nodes[nodeID].pos * (1 - part) + self.nodes[nodeID + 1].pos * part
	else
		return nil
	end
end

function Path:getAngle(pixels)
	if pixels then
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
	else
		return nil
	end
end

function Path:getHidden(pixels)
	local nodeID = self:getNodeID(pixels)
	if nodeID == 0 then return self.nodes[1].hidden end
	if nodeID > #self.nodes then return self.nodes[#self.nodes].hidden end
	return self.nodes[nodeID].hidden
end

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



function Path:serialize()
	local t = {
		sphereChains = {},
		clearOffset = self.clearOffset,
		bonusScarab = self.bonusScarab and self.bonusScarab:serialize() or nil,
		scorpions = {}
	}
	for i, sphereChain in ipairs(self.sphereChains) do
		table.insert(t.sphereChains, sphereChain:serialize())
	end
	for i, scorpion in ipairs(self.scorpions) do
		table.insert(t.scorpions, scorpion:serialize())
	end
	return t
end

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
end

return Path
