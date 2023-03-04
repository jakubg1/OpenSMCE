local class = require "com.class"

---@class UIWidgetSpriteButtonSlider
---@overload fun(parent, sprite, bounds):UIWidgetSpriteButtonSlider
local UIWidgetSpriteButtonSlider = class:derive("UIWidgetSpriteButtonSlider")

local Vec2 = require("src.Essentials.Vector2")
local UIWidgetSpriteButton = require("src.UI.WidgetSpriteButton")



function UIWidgetSpriteButtonSlider:new(parent, sprite, bounds)
	self.type = "spriteButton"

	self.parent = parent
	self.button = UIWidgetSpriteButton(parent, sprite)

	self.value = 0
	self.bounds = bounds
	self.catchX = 0
end

function UIWidgetSpriteButtonSlider:click()
	if not self.parent:isVisible() or not self.button.hovered or self.button.clicked then return end
	self.button:click()
	self.catchX = _MousePos.x - self.parent.pos.x
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
	self.parent.pos.x = self.bounds[1] + ((self.bounds[2] - self.bounds[1]) * value)
end



function UIWidgetSpriteButtonSlider:draw()
	if self.button.clicked then
		self.parent.pos.x = math.min(math.max(_MousePos.x - self.catchX, self.bounds[1]), self.bounds[2])
		self.value = (self.parent.pos.x - self.bounds[1]) / (self.bounds[2] - self.bounds[1])
	end
	self.button:draw()
end

return UIWidgetSpriteButtonSlider
