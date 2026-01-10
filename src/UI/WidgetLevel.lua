local class = require "com.class"
local DummyLevel = require("src.Game.DummyLevel")

---@class UIWidgetLevel
---@overload fun(parent, path):UIWidgetLevel
local UIWidgetLevel = class:derive("UIWidgetLevel")

function UIWidgetLevel:new(parent, path)
	self.type = "level"
	self.parent = parent
	self.level = DummyLevel(path)
end

function UIWidgetLevel:update(dt)
	if self.parent:getAlpha() == 0 then
		return
	end
	self.level:update(dt)
end

function UIWidgetLevel:draw()
	self.level:draw()
end

return UIWidgetLevel