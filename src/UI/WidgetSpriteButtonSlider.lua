local class = require "com.class"
local UIWidgetSpriteButton = require("src.UI.WidgetSpriteButton")

---@class UIWidgetSpriteButtonSlider
---@overload fun(parent, sprite, bounds, clickSound, releaseSound, hoverSound):UIWidgetSpriteButtonSlider
local UIWidgetSpriteButtonSlider = class:derive("UIWidgetSpriteButtonSlider")

function UIWidgetSpriteButtonSlider:new(parent, sprite, bounds, clickSound, releaseSound, hoverSound)
	self.type = "spriteButtonSlider"

	self.parent = parent
	self.button = UIWidgetSpriteButton(parent, sprite, clickSound, releaseSound, hoverSound)

	self.value = 0
	self.bounds = bounds
	self.catchX = 0
end

function UIWidgetSpriteButtonSlider:click()
	if not self.parent:isVisible() or not self.button.hovered or self.button.clicked then return end
	self.button:click()
	self.catchX = _MouseX - self.parent.pos.x
end

function UIWidgetSpriteButtonSlider:unclick()
	self.button:unclick()
end

-- this is pointless:
-- function UIWidgetSpriteButtonSlider:keypressed(key)
	-- self.button:keypressed(key)
-- end

function UIWidgetSpriteButtonSlider:setEnabled(enabled)
	self.button:setEnabled(enabled)
end

function UIWidgetSpriteButtonSlider:setValue(value)
	self.value = value
	self.parent.pos.x = _Utils.lerp(self.bounds[1], self.bounds[2], value)
end

function UIWidgetSpriteButtonSlider:draw()
	if self.button.clicked then
		self.parent.pos.x = _Utils.clamp(_MouseX - self.catchX, self.bounds[1], self.bounds[2])
		self.value = _Utils.map(0, 1, self.bounds[1], self.bounds[2], self.parent.pos.x)
	end
	self.button:draw()
end

function UIWidgetSpriteButtonSlider:getSize()
	return self.button.size
end

return UIWidgetSpriteButtonSlider
