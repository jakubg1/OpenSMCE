local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")

---@class Sprite
---@overload fun(config, path):Sprite
local Sprite = class:derive("Sprite")

---Constructs a new Sprite.
---@param config SpriteConfig The Sprite Config of this Sprite.
---@param path string A path to the sprite file.
function Sprite:new(config, path)
	self.config = config
	self.path = path

	self.image = config.image.img
	self.imageSize = config.image.size
	---@type {frameCount: integer, frames: love.Quad[]}[]
	self.states = {}
	self:generateFrames(0, 0)
end

---Permanently attaches this Sprite as part of the provided Sprite Atlas.
---This function offsets all sprite Quads to match the position of this Sprite's position on the atlas.
---@param atlas SpriteAtlas The Sprite Atlas this Sprite will be a part of.
---@param offsetX integer The horizontal offset of this Sprite on the Atlas texture, in pixels.
---@param offsetY integer The vertical offset of this Sprite on the Atlas texture, in pixels.
function Sprite:attachToAtlas(atlas, offsetX, offsetY)
	self.image = atlas.canvas
	self.imageSize = Vec2(atlas.canvas:getDimensions())
	self:generateFrames(offsetX, offsetY)
end

---Generates the frame positions and sizes (`love.Quad` objects) based on this Sprite's config.
---@param offsetX integer The horizontal offset of this Sprite if it is using an Atlas texture, in pixels.
---@param offsetY integer The vertical offset of this Sprite if it is using an Atlas texture, in pixels.
function Sprite:generateFrames(offsetX, offsetY)
	self.states = {}
	for i, state in ipairs(self.config.states) do
		local s = {}
		s.frameCount = state.frames.x * state.frames.y
		s.frames = {}
		for j = 1, state.frames.x do
			for k = 1, state.frames.y do
				local p = self.config.frameSize * (Vec2(j, k) - 1) + state.pos
				local n = (k - 1) * state.frames.x + j
				s.frames[n] = love.graphics.newQuad(p.x + offsetX, p.y + offsetY, self.config.frameSize.x, self.config.frameSize.y, self.imageSize.x, self.imageSize.y)
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
	assert(s, string.format("Tried to get state %s, but the sprite %s only has %s states!", state, self.path, #self.states))
	local n = (frame - 1) % s.frameCount + 1
	local f = s.frames[n]
	assert(f, string.format("Tried to get frame %s (%s), but the sprite %s has only %s frames in state %s!", frame, n, self.path, #s.frames, state))
	return f
end

---Returns the top left position of the given frame on this Sprite's image.
---@param state integer The state ID of this sprite.
---@param frame integer The frame of which the top left position will be returned.
---@return Vector2
function Sprite:getFramePos(state, frame)
	local s = self.config.states[state]
	return s.pos + Vec2((frame - 1) % s.frames.x, math.floor((frame - 1) / s.frames.x)) * self.config.frameSize
end

---Returns the amount of states in this Sprite.
---@return integer
function Sprite:getStateCount()
	return #self.states
end

---Returns the amount of frames in the given state of this Sprite.
---@param state integer? The state for which the count of frames should be provided. `1` by default.
---@return integer
function Sprite:getFrameCount(state)
	return self.states[state or 1].frameCount
end

---Draws this Sprite onto the screen.
---@param posX number The sprite's horizontal position.
---@param posY number The sprite's vertical position.
---@param alignX number? The horizontal sprite alignment. `0` (default) is left. `1` is right. `0.5` is in the middle.
---@param alignY number? The vertical sprite alignment. `0` (default) is top. `1` is bottom. `0.5` is in the middle.
---@param state integer? The state ID to be drawn.
---@param frame integer? The state's frame to be drawn.
---@param rot number? The sprite rotation in radians.
---@param color Color? The sprite color.
---@param alpha number? Sprite transparency. `0` is fully transparent. `1` is fully opaque.
---@param scaleX number? The horizontal scale of this sprite.
---@param scaleY number? The horizontal scale of this sprite.
---@param scaleMode boolean? If `true`, the `scaleX` and `scaleY` will instead specify the sprite size in pixels, regardless of the frame size.
function Sprite:draw(posX, posY, alignX, alignY, state, frame, rot, color, alpha, scaleX, scaleY, scaleMode)
	--_Debug:deprecationNotice("Test deprecation notice/Sprites will need layers soon!", 2)

	alignX, alignY = alignX or 0, alignY or 0
	state = state or 1
	frame = frame or 1
	rot = rot or 0
	color = color or Color()
	alpha = alpha or 1
	scaleX, scaleY = scaleX or 1, scaleY or scaleX or 1
	if scaleMode then
		scaleX, scaleY = scaleX / self.config.frameSize.x, scaleY / self.config.frameSize.y
	end

	local x, y = _V.rotate(alignX * scaleX * self.config.frameSize.x, alignY * scaleY * self.config.frameSize.y, rot)
	posX, posY = posX - x, posY - y

	love.graphics.setColor(color.r, color.g, color.b, alpha)
	love.graphics.draw(self.image, self:getFrame(state, frame), posX, posY, rot, scaleX, scaleY)
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function Sprite.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a Sprite by a given path.
    ---@param path string The resource path.
    ---@return Sprite
    function ResourceManager:getSprite(path)
        return self:getResourceAsset(path, "Sprite")
    end
end

return Sprite
