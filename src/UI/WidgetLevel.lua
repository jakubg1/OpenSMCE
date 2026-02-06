local class = require "com.class"
local DummyLevel = require("src.Game.DummyLevel")

---@class UIWidgetLevel
---@overload fun(parent, path):UIWidgetLevel
local UIWidgetLevel = class:derive("UIWidgetLevel")

function UIWidgetLevel:new(parent, path)
	self.type = "level"
	self.parent = parent
	self.level = DummyLevel(path)

	self.visible = true
end

function UIWidgetLevel:update(dt)
	local visible = self.parent:getAlpha() > 0
	if self.visible and not visible then
		-- We just disappeared!
		self.level:deactivateParticles()
	elseif not self.visible and visible then
		-- We just appeared!
		self.level:activateParticles()
	end
	self.visible = visible

	-- Update the level only if it is visible.
	if visible then
		self.level:update(dt)
	end
end

function UIWidgetLevel:draw()
	self.level:draw()
end

return UIWidgetLevel