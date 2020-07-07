local class = require "class"
local SpriteImage = class:derive("SpriteImage")

local Vec2 = require("Essentials/Vector2")
local Color = require("Essentials/Color")
local Image = require("Essentials/Image")

-- Things that are not sprites yet:
-- Map elements

function SpriteImage:new(data, variables)
	self.image = game.resourceBank:getImage(parseString(data.path, variables))
	self.frame = parseVec2(data.frame) or Vec2(1)
	self.frameCount = parseVec2(data.frameCount) or Vec2(1)
	self.offset = parseVec2(data.offset) or Vec2()
	self.anchor = parseVec2(data.anchor) or Vec2()
	self.effects = data.effects or {}
	
	self.time = 0
end

function SpriteImage:update(dt)
	self.time = self.time + dt
end

function SpriteImage:draw(pos, variables)
	local angle = 0
	local frame = parseVec2(self.frame, variables)
	local color = Color()
	local alpha = 1
	for i, effect in ipairs(self.effects) do
		local properties = {frame = frame}
		if effect.type == "setAngle" then angle = parseNumber(effect.value, variables, properties)
		elseif effect.type == "setColor" then color = parseColor(effect.value, variables, properties)
		elseif effect.type == "setAlpha" then alpha = parseNumber(effect.value, variables, properties)
		elseif effect.type == "setFrame" then frame = parseVec2(effect.value, variables, properties)
		elseif effect.type == "animationFrame" then frame = Vec2(math.floor((self.time * effect.speed.x) % self.frameCount.x + 1), math.floor((self.time * effect.speed.y) % self.frameCount.y + 1))
		elseif effect.type == "animationRainbow" then color = color * getRainbowColor(self.time * effect.speed)
		end
	end
	self.image:draw(pos + self.offset, self.anchor, frame, angle, color, alpha)
end

return SpriteImage