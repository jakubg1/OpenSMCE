local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")

---@class UIWidgetSprite
---@overload fun(parent, sprite):UIWidgetSprite
local UIWidgetSprite = class:derive("UIWidgetSprite")

function UIWidgetSprite:new(parent, sprite)
	self.type = "sprite"
	self.parent = parent
	local success
	success, self.sprite = pcall(function() return _Res:getSprite(sprite) end)
	if not success then
		-- TODO: Add a checkbox in the Boot Screen to toggle these errors in the visible console.
		_Log:print(string.format("WIDGET ERROR: Could not load sprite %s for widget %s", sprite, parent:getFullName()))
		self.sprite = nil
	end
	self.debugColor = {0.0, 1.0, 0.0}
end

function UIWidgetSprite:draw()
	if not self.sprite then
		return
	end
	local x, y = self.parent:getPos()
	_Renderer:setLayer(self.parent.layer)
	self.sprite:draw(x, y, nil, nil, nil, nil, nil, nil, self.parent:getAlpha())
end

function UIWidgetSprite:getSize()
	if not self.sprite then
		return Vec2()
	end
	return self.sprite.config.frameSize
end

return UIWidgetSprite
