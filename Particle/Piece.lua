local class = require "class"
local ParticlePiece = class:derive("ParticlePiece")

local Vec2 = require("Essentials/Vector2")
local Image = require("Essentials/Image")

function ParticlePiece:new(manager, data, pos)
	self.manager = manager
	
	self.pos = pos + parseVec2(data.pos)
	self.speed = parseVec2(data.speed)
	self.speedRotation = parseNumber(data.speedRotation)
	--if self.speedRotation then self.speed = self.speed:rotate(math.random() * math.pi * 2) end
	self.acceleration = parseVec2(data.acceleration)
	self.lifespan = parseNumber(data.lifespan) -- nil if it lives indefinitely
	self.lifetime = self.lifespan
	
	self.image = game.resourceBank:getImage(data.image)
	self.animationSpeed = data.animationSpeed
	self.animationFrameCount = data.animationFrameCount
	self.animationLoop = data.animationLoop
	self.fadeInPoint = data.fadeInPoint
	self.fadeOutPoint = data.fadeOutPoint
	
	self.animationFrame = data.animationFrameRandom and math.random(1, self.animationFrameCount) or 1
	self.alpha = 1
	
	self.delQueue = false
end

function ParticlePiece:update(dt)
	if self.speedRotation then self.speed = self.speed:rotate(self.speedRotation * dt) end
	self.speed = self.speed + self.acceleration * dt
	self.pos = self.pos + self.speed * dt
	if self.lifetime then
		self.lifetime = self.lifetime - dt
		if self.lifetime <= 0 then self:destroy() end
	end
	self.animationFrame = self.animationFrame + self.animationSpeed * dt
	if self.animationFrame >= self.animationFrameCount + 1 then
		if self.animationLoop then self.animationFrame = self.animationFrame - self.animationFrameCount end
		--self:destroy()
	end
	if self.lifetime < self.lifespan * (1 - self.fadeOutPoint) then
		self.alpha = self.lifetime / (self.lifespan * (1 - self.fadeOutPoint))
	elseif self.lifetime > self.lifespan * (1 - self.fadeInPoint) then
		self.alpha = 1 - (self.lifetime - self.lifespan * (1 - self.fadeInPoint)) / (self.lifespan * self.fadeInPoint)
	else
		self.alpha = 1
	end
end



function ParticlePiece:destroy()
	if self.delQueue then return end
	self.delQueue = true
	
	self.manager:destroyParticlePiece(self)
end



function ParticlePiece:draw()
	self.image:draw(self.pos, Vec2(0.5), Vec2(math.min(math.floor(self.animationFrame), self.animationFrameCount), 1), nil, nil, self.alpha)
end

return ParticlePiece