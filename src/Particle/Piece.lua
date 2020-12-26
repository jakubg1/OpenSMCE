local class = require "com/class"
local ParticlePiece = class:derive("ParticlePiece")

local Vec2 = require("src/Essentials/Vector2")
local Image = require("src/Essentials/Image")

function ParticlePiece:new(manager, spawner, data, pos)
	self.manager = manager
	self.packet = spawner.packet
	self.spawner = spawner
	self.spawner.pieceCount = self.spawner.pieceCount + 1
	
	self.pos = pos + parseVec2(data.pos)
	self.speed = parseVec2(data.speed)
	self.speedRotation = parseNumber(data.speedRotation)
	--if self.speedRotation then self.speed = self.speed:rotate(math.random() * math.pi * 2) end
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
	self.rainbow = data.rainbow
	self.rainbowSpeed = data.rainbowSpeed
	
	self.animationFrame = data.animationFrameRandom and math.random(1, self.animationFrameCount) or 1
	
	self.delQueue = false
end

function ParticlePiece:update(dt)
	-- position stuff
	if self.speedRotation then self.speed = self.speed:rotate(self.speedRotation * dt) end
	self.speed = self.speed + self.acceleration * dt
	self.pos = self.pos + self.speed * dt
	
	-- lifespan
	if self.lifetime then
		self.lifetime = self.lifetime - dt
		if self.lifetime <= 0 then self:destroy() end
	end
	self.time = self.time + dt
	
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
	if self.posRelative and self.packet then
		return self.packet.pos + self.pos
	else
		return self.pos
	end
end

function ParticlePiece:getColor()
	if not self.rainbow then
		return nil
	end
	return getRainbowColor(self.time * self.rainbowSpeed / 30)
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