local class = require "com.class"

---@class Sprite
---@overload fun(data, path):Sprite
local Sprite = class:derive("Sprite")

local SpriteConfig = require("src.Configs.Sprite")
local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")



---Constructs a new Sprite.
---@param data table The parsed JSON data of the sprite.
---@param path string A path to the sprite file.
function Sprite:new(data, path)
	self.path = path
	self.config = SpriteConfig(data, path)

	self.size = self.config.image.size
	---@type [{frameCount: integer, frames: [love.Quad]}]
	self.states = {}
	for i, state in ipairs(self.config.states) do
		local s = {}
		s.frameCount = state.frames.x * state.frames.y
		s.frames = {}
		for j = 1, state.frames.x do
			for k = 1, state.frames.y do
				local p = self.config.frameSize * (Vec2(j, k) - 1) + state.pos
				s.frames[(k - 1) * state.frames.x + j] = love.graphics.newQuad(p.x, p.y, self.config.frameSize.x, self.config.frameSize.y, self.size.x, self.size.y)
			end
		end
		self.states[i] = s
	end
end



---Returns a `love.Quad` object for use in drawing functions.
---@param state integer The state ID of this sprite.
---@param frame integer Which frame of that state should be returned.
---@return love.Quad
function Sprite:getFrame(state, frame)
	local s = self.states[state]
	return s.frames[(frame - 1) % s.frameCount + 1]
end



---Returns the top left position of the given frame on this Sprite's image.
---@param state integer The state ID of this sprite.
---@param frame integer The frame of which the top left position will be returned.
---@return Vector2
function Sprite:getFramePos(state, frame)
	local s = self.config.states[state]
	return s.pos + Vec2((frame - 1) % s.frames.x, math.floor((frame - 1) / s.frames.x)) * self.config.frameSize
end



---Draws this Sprite onto the screen.
---@param pos Vector2 The sprite position.
---@param align Vector2? The sprite alignment. `(0, 0)` is the top left corner. `(1, 1)` is the bottom right corner. `(0.5, 0.5)` is in the middle.
---@param state integer? The state ID to be drawn.
---@param frame integer? The state's frame to be drawn.
---@param rot number? The sprite rotation in radians.
---@param color Color? The sprite color.
---@param alpha number? Sprite transparency. `0` is fully transparent. `1` is fully opaque.
---@param scale Vector2? The scale of this sprite.
function Sprite:draw(pos, align, state, frame, rot, color, alpha, scale)
	align = align or Vec2()
	state = state or 1
	frame = frame or 1
	rot = rot or 0
	color = color or Color()
	alpha = alpha or 1
	scale = scale or Vec2(1)

	pos = _Display:posOnScreen(pos - (align * scale * self.config.frameSize):rotate(rot))
	scale = scale * _Display:getResolutionScale()

	love.graphics.setColor(color.r, color.g, color.b, alpha)
	self.config.image:draw(self:getFrame(state, frame), pos.x, pos.y, rot, scale.x, scale.y)
end



return Sprite
