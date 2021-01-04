local class = require "com/class"
local ParticlePiece = class:derive("ParticlePiece")

local Vec2 = require("src/Essentials/Vector2")
local Image = require("src/Essentials/Image")

function ParticlePiece:new(manager, spawner, data)
	self.manager = manager
	self.packet = spawner.packet
	self.spawner = spawner
	self.spawner.pieceCount = self.spawner.pieceCount + 1
	
	self.packetPos = self.packet.pos
	
	self.pos = self.spawner.pos
	if not data.posRelative then
		self.pos = self.spawner:getPos()
	end
	
	local spawnScale = parseVec2(data.spawnScale)
	local spawnRotVec = Vec2(1):rotate(math.random() * math.pi * 2)
	local spawnPos = spawnRotVec * spawnScale
	self.pos = self.pos + spawnPos
	if data.spawnScaleAffectsSpeed then
		self.speed = spawnPos * parseVec2(data.speed)
	else
		self.speed = parseVec2(data.speed)
	end
	
	self.acceleration = parseVec2(data.acceleration)
	
	self.lifespan = parseNumber(data.lifespan) -- nil if it lives indefinitely
	self.lifetime = self.lifespan
	self.time = 0
	
	self.image = game.resourceBank:getImage(data.image)
	self.animationSpeed = data.animationSpeed
	self.animationFrameCount = data.animationFrameCount
	self.animationLoop = data.animationLoop
	self.fadeInPoint = data.fadeInPoint
	self.fadeOutPoint = data.fadeOutPoint
	self.posRelative = data.posRelative
	self.directionDeviation = false -- is switched to true after directionDeviationTime seconds (if that exists)
	self.directionDeviationTime = parseNumber(data.directionDeviationTime)
	self.directionDeviationSpeed = data.directionDeviationSpeed -- evaluated every frame
	
	self.animationFrame = data.animationFrameRandom and math.random(1, self.animationFrameCount) or 1
	
	self.colorPalette = data.colorPalette and game.resourceBank:getColorPalette(data.colorPalette)
	self.colorPaletteSpeed = data.colorPaletteSpeed
	
	self.delQueue = false
end

function ParticlePiece:update(dt)
	-- lifespan
	if self.lifetime then
		self.lifetime = self.lifetime - dt
		if self.lifetime <= 0 then self:destroy() end
	end
	self.time = self.time + dt
	if not self.directionDeviation and self.directionDeviationTime and self.time >= self.directionDeviationTime then
		self.directionDeviation = true
	end
	
	-- position stuff
	if self.directionDeviation then self.speed = self.speed:rotate(parseNumber(self.directionDeviationSpeed) * dt) end
	self.speed = self.speed + self.acceleration * dt
	self.pos = self.pos + self.speed * dt
	-- cache last packet position
	if self.packet then
		self.packetPos = self.packet.pos
	end
	
	-- animation
	self.animationFrame = self.animationFrame + self.animationSpeed * dt
	if self.animationFrame >= self.animationFrameCount + 1 then
		if self.animationLoop then self.animationFrame = self.animationFrame - self.animationFrameCount end
		--self:destroy()
	end
	
	-- detach when spawner/packet is gone
	if self.spawner and self.spawner.delQueue then
		self.spawner = nil
	end
	if self.packet and self.packet.delQueue then
		self.packet = nil
	end
	
	-- when living indefinitely and packet inexistent, destroy
	if not self.packet and not self.lifetime then
		self:destroy()
	end
end



function ParticlePiece:destroy()
	if self.delQueue then return end
	self.delQueue = true
	
	self.manager:destroyParticlePiece(self)
	if self.spawner then
		self.spawner.pieceCount = self.spawner.pieceCount - 1
	end
end



function ParticlePiece:getPos()
	if self.posRelative then
		return self.packetPos + self.pos
	else
		return self.pos
	end
end

function ParticlePiece:getColor()
	if self.colorPalette then
		local t = (self.colorPaletteSpeed and self.time * self.colorPaletteSpeed or 0)
		return self.colorPalette:getColor(t)
	end
end

function ParticlePiece:getAlpha()
	if not self.lifespan then
		return 1
	end
	
	if self.lifetime < self.lifespan * (1 - self.fadeOutPoint) then
		return self.lifetime / (self.lifespan * (1 - self.fadeOutPoint))
	elseif self.lifetime > self.lifespan * (1 - self.fadeInPoint) then
		return 1 - (self.lifetime - self.lifespan * (1 - self.fadeInPoint)) / (self.lifespan * self.fadeInPoint)
	else
		return 1
	end
end

function ParticlePiece:draw()
	self.image:draw(self:getPos(), Vec2(0.5), Vec2(math.min(math.floor(self.animationFrame), self.animationFrameCount), 1), nil, self:getColor(), self:getAlpha())
end

return ParticlePiece