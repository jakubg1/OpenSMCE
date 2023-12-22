local class = require "com.class"

---@class Sprite
---@overload fun(path):Sprite
local Sprite = class:derive("Sprite")

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")
local Image = require("src.Essentials.Image")



---Constructs a new Sprite.
---@param path string A path to the sprite file.
function Sprite:new(path)
	self.path = path
	local data = _Utils.loadJson(path)

	if data.internal then
		self.img = Image(_ParsePath(data.path))
	else
		self.img = _Game.resourceManager:getImage(data.path)
	end
	self.size = self.img.size
	self.frameSize = data.frameSize
	self.states = {}
	for i, state in ipairs(data.states) do
		local s = {}
		s.frameCount = state.frames
		s.frames = {}
		for j = 1, state.frames.x do
			s.frames[j] = {}
			for k = 1, state.frames.y do
				local p = self.frameSize * (Vec2(j, k) - 1) + state.pos
				s.frames[j][k] = love.graphics.newQuad(p.x, p.y, self.frameSize.x, self.frameSize.y, self.size.x, self.size.y)
			end
		end
		self.states[i] = s
	end
end



---Returns a quad object for use in drawing functions.
---@param state integer The state ID of this sprite.
---@param frame Vector2 The sprite to be obtained.
---@return love.Quad
function Sprite:getFrame(state, frame)
	--print(self.frames[(frame.x - 1) % self.frameCount.x + 1][(frame.y - 1) % self.frameCount.y + 1])
	--for k1, v1 in pairs(self.frames) do
	--	for k2, v2 in pairs(v1) do print(k1, k2, v2) end
	--end
	local s = self.states[state]
	return s.frames[(frame.x - 1) % s.frameCount.x + 1][(frame.y - 1) % s.frameCount.y + 1]
end



---Draws this Sprite onto the screen.
---@param pos Vector2 The sprite position.
---@param align Vector2? The sprite alignment. `(0, 0)` is the top left corner. `(1, 1)` is the bottom right corner. `(0.5, 0.5)` is in the middle.
---@param state integer? The state ID to be drawn.
---@param frame Vector2? The sprite to be drawn.
---@param rot number? The sprite rotation in radians.
---@param color Color? The sprite color.
---@param alpha number? Sprite transparency. `0` is fully transparent. `1` is fully opaque.
---@param scale Vector2? The scale of this sprite.
function Sprite:draw(pos, align, state, frame, rot, color, alpha, scale)
	align = align or Vec2()
	state = state or 1
	frame = frame or Vec2(1)
	rot = rot or 0
	color = color or Color()
	alpha = alpha or 1
	scale = scale or Vec2(1)
	pos = _PosOnScreen(pos - (align * scale * self.frameSize):rotate(rot))
	if color.r then -- temporary chunk
		love.graphics.setColor(color.r, color.g, color.b, alpha)
	else
		love.graphics.setColor(unpack(color), alpha)
	end
	self.img:draw(self:getFrame(state, frame), pos.x, pos.y, rot, scale.x * _GetResolutionScale(), scale.y * _GetResolutionScale())
end



return Sprite
