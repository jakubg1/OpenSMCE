local class = require "com/class"
local Sprite = class:derive("Sprite")

local Vec2 = require("src/Essentials/Vector2")
local Color = require("src/Essentials/Color")
local Image = require("src/Essentials/Image")

function Sprite:new(path)
	print("Loading sprite from " .. path .. "...")
	self.path = path
	local data = loadJson(path)

	if data.internal then
		self.img = Image(parsePath(data.path))
	else
		self.img = game.resourceManager:getImage(data.path)
	end
	self.size = self.img.size
	self.frameSize = self.size / data.frames
	self.frameCount = data.frames
	self.frames = {}
	for i = 1, data.frames.x do
		self.frames[i] = {}
		for j = 1, data.frames.y do
			self.frames[i][j] = love.graphics.newQuad(self.frameSize.x * (i - 1), self.frameSize.y * (j - 1), self.frameSize.x, self.frameSize.y, self.size.x, self.size.y)
		end
	end
end

function Sprite:getFrame(frame)
	--print(self.frames[(frame.x - 1) % self.frameCount.x + 1][(frame.y - 1) % self.frameCount.y + 1])
	--for k1, v1 in pairs(self.frames) do
	--	for k2, v2 in pairs(v1) do print(k1, k2, v2) end
	--end
	return self.frames[(frame.x - 1) % self.frameCount.x + 1][(frame.y - 1) % self.frameCount.y + 1]
end

function Sprite:draw(pos, align, frame, rot, color, alpha, scale)
	align = align or Vec2()
	frame = frame or Vec2(1)
	rot = rot or 0
	color = color or Color()
	alpha = alpha or 1
	scale = scale or Vec2(1)
	pos = posOnScreen(pos - (align * scale * self.frameSize):rotate(rot))
	if color.r then -- temporary chunk
		love.graphics.setColor(color.r, color.g, color.b, alpha)
	else
		love.graphics.setColor(unpack(color), alpha)
	end
	self.img:draw(self:getFrame(frame), pos.x, pos.y, rot, scale.x * getResolutionScale(), scale.y * getResolutionScale())
end

return Sprite
