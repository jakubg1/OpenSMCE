local class = require "com.class"

---@class ParticlePiece
---@overload fun(manager, spawner, data):ParticlePiece
local ParticlePiece = class:derive("ParticlePiece")

---Constructs a new particle piece.
---@param manager ParticleManager The particle owner.
---@param spawner ParticleSpawner The spawner which has spawned this particle.
---@param data ParticleConfig Particle data.
function ParticlePiece:new(manager, spawner, data)
	self.manager = manager
	self.packet = spawner.packet
	self.spawner = spawner

	if data.posRelative then
		self.startX, self.startY = self.spawner:getRelativePos()
	else
		self.startX, self.startY = self.spawner:getPos()
	end
	self.x, self.y = self.startX, self.startY
	-- These values must be cached because they are saved when the packet is gone.
	self.packetX, self.packetY = self.packet:getPos()
	self.layer = self.spawner.layer

	self.speedMode = data.movement.type
	local spawnScale = data.spawnScale:evaluate()
	self.spawnScaleX, self.spawnScaleY = spawnScale.x, spawnScale.y
	self.posAngle = math.random() * math.pi * 2
	local posAngleX, posAngleY = _V.rotate(1, 0, self.posAngle)
	local spawnX, spawnY = posAngleX * self.spawnScaleX, posAngleY * self.spawnScaleY
	self.x, self.y = self.x + spawnX, self.y + spawnY

	if self.speedMode == "loose" then
		local vec = data.movement.speed:evaluate()
		self.speedX, self.speedY = vec.x, vec.y
	elseif self.speedMode == "radius" then
		local vec = data.movement.speed:evaluate()
		self.speedX, self.speedY = spawnX * vec.x, spawnY * vec.y
	elseif self.speedMode == "circle" then
		local speed = data.movement.speed:evaluate()
		self.speed = speed * math.pi / 180 -- convert degrees to radians
	else
		error("Unknown particle speed mode: " .. tostring(self.speedMode))
	end

	if self.speedMode == "circle" then
		self.acceleration = data.movement.acceleration
	else
		self.accelerationX, self.accelerationY = data.movement.acceleration.x, data.movement.acceleration.y
	end

	self.lifespan = data.lifespan and data.lifespan:evaluate() -- nil if it lives indefinitely
	self.time = 0

	self.sprite = data.sprite
	self.animationSpeed = data.animationSpeed
	self.animationFrameCount = data.animationFrameCount
	self.animationLoop = data.animationLoop
	self.fadeTime = data.fadeTime and data.fadeTime:evaluate()
	self.fadeInPoint = data.fadeInPoint
	self.fadeOutPoint = data.fadeOutPoint
	self.posRelative = data.posRelative
	self.directionDeviation = false -- is switched to true after directionDeviationTime seconds (if that exists)
	self.directionDeviationTime = data.directionDeviationTime
	self.directionDeviationSpeed = data.directionDeviationSpeed -- evaluated every frame
	self.angle = data.angle and data.angle:evaluate()
	self.angleSpeed = data.angleSpeed and data.angleSpeed:evaluate()

	self.animationFrame = data.animationFrameRandom and math.random(1, self.animationFrameCount) or 1

	self.colorPalette = data.colorPalette
	self.colorPaletteSpeed = data.colorPaletteSpeed

	self.delQueue = false
end

---Updates this particle piece.
---@param dt number Time delta in seconds.
function ParticlePiece:update(dt)
	-- Calculate lifespan and time.
	self.time = self.time + dt
	if self.lifespan and self.time >= self.lifespan then
		self:destroy()
	end

	-- Determine whether direction deviation should happen.
	if not self.directionDeviation and self.directionDeviationTime and self.time >= self.directionDeviationTime then
		self.directionDeviation = true
	end

	-- Calculate position and speed.
	if self.directionDeviation then
		self.speedX, self.speedY = _V.rotate(self.speedX, self.speedY, self.directionDeviationSpeed:evaluate() * dt)
	end
	if self.speedMode == "circle" then
		self.speed = self.speed + self.acceleration * dt
		self.posAngle = self.posAngle + self.speed * dt
		local posAngleX, posAngleY = _V.rotate(1, 0, self.posAngle)
		self.x, self.y = self.startX + self.spawnScaleX * posAngleX, self.startY + self.spawnScaleY * posAngleY
	else
		self.speedX, self.speedY = self.speedX + self.accelerationX * dt, self.speedY + self.accelerationY * dt
		self.x, self.y = self.x + self.speedX * dt, self.y + self.speedY * dt
	end

	-- Update last packet position.
	if self.packet then
		self.packetX, self.packetY = self.packet:getPos()
	end

	-- Animate the sprite.
	self.animationFrame = self.animationFrame + self.animationSpeed * dt
	if self.animationFrame >= self.animationFrameCount + 1 then
		-- Animation has finished. If looping, go back to the first frame.
		if self.animationLoop then
			self.animationFrame = self.animationFrame - self.animationFrameCount
		end
	end

	-- Update the speed.
	if self.angle and self.angleSpeed then
		self.angle = (self.angle + self.angleSpeed * dt) % (math.pi * 2)
	end

	-- Detach from parents if they are gone.
	if self.spawner and self.spawner.delQueue then
		self.spawner = nil
	end
	if self.packet and self.packet.delQueue then
		self.packet = nil
	end

	-- Destroy this particle if it has an infinite lifespan and its packet dies.
	if not self.packet and not self.lifespan then
		self:destroy()
	end
end

---Flags this particle piece as ready to be removed.
function ParticlePiece:destroy()
	if self.delQueue then
		return
	end
	self.delQueue = true
end

---Returns the actual position of this particle piece.
---@return integer, integer
function ParticlePiece:getPos()
	if self.posRelative then
		return self.packetX + self.x, self.packetY + self.y
	else
		return self.x, self.y
	end
end

---Returns the optional color tint for this particle piece, if it has a color palette defined.
---@private
---@return Color?
function ParticlePiece:getColor()
	if self.colorPalette then
		local t = self.colorPaletteSpeed and self.time * self.colorPaletteSpeed or 0
		return self.colorPalette:getColor(t)
	end
end

---Returns the opacity of this particle piece.
---@private
---@return number
function ParticlePiece:getAlpha()
	local totalTime = self.lifespan or self.fadeTime
	if not totalTime then
		return 1
	end
	if self.fadeInPoint then
		local inEnd = totalTime * self.fadeInPoint
		if self.time < inEnd then
			return _Utils.mapc(0, 1, 0, inEnd, self.time)
		end
	end
	if self.fadeOutPoint then
		local outStart = totalTime * self.fadeOutPoint
		if self.time > outStart then
			return _Utils.mapc(1, 0, outStart, totalTime, self.time)
		end
	end
	return 1
end

---Draws this particle piece on the screen.
function ParticlePiece:draw()
	local x, y = self:getPos()
	local frame = math.min(math.floor(self.animationFrame), self.animationFrameCount)
	_Renderer:setLayer(self.layer or "MAIN")
	self.sprite:draw(x, y, 0.5, 0.5, nil, frame, self.angle, self:getColor(), self:getAlpha())
end

return ParticlePiece
