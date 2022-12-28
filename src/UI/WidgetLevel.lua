local class = require "com/class"

---@class UIWidgetLevel
---@overload fun(parent, path):UIWidgetLevel
local UIWidgetLevel = class:derive("UIWidgetLevel")

local DummyLevel = require("src/DummyLevel")



function UIWidgetLevel:new(parent, path)
	self.type = "level"
	
	self.parent = parent
	
	self.level = DummyLevel(path)
end



function UIWidgetLevel:update(dt)
	if not self.parent.visible then return end
	self.level:update(dt)
end

function UIWidgetLevel:draw(variables)
	self.level:draw()
end

return UIWidgetLevel