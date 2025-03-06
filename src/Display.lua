local class = require "com.class"

---@class Display
---@overload fun():Display
local Display = class:derive("Display")

local Vec2 = require("src.Essentials.Vector2")

---Constructs a Display Manager.
function Display:new()
    self.size = Vec2(800, 600)
end

---Sets the window settings: resolution, whether it can be changed, and its title.
---@param resolution Vector2 The new window resolution.
---@param resizable boolean Whether the window can be resized.
---@param title string The window title.
---@param maximized boolean? If set, the window will be maximized.
function Display:setResolution(resolution, resizable, title, maximized)
	love.window.setMode(resolution.x, resolution.y, {resizable = resizable})
	if maximized then
		love.window.maximize()
	end
	love.window.setTitle(title)
	self.size = resolution
end

---Sets whether the window should be fullscreen.
---@param fullscreen boolean Whether the window should be fullscreen.
function Display:setFullscreen(fullscreen)
    if fullscreen == love.window.getFullscreen() then return end
    if fullscreen then
        local _, _, flags = love.window.getMode()
        self.size = Vec2(love.window.getDesktopDimensions(flags.display))
    else
        self.size = _Game:getNativeResolution()
    end
    love.window.setMode(self.size.x, self.size.y, {fullscreen = fullscreen, resizable = true})
end

---Returns the X offset of actual screen contents.
---The game is scaled so the vertical axis is always fully covered. This means that on the X axis, the contents need to be positioned
---in such a way that the contents are exactly in the center.
---@param force boolean? Whether the returned value should be scaled with the window even if the canvas rendering is enabled.
---@return number
function Display:getDisplayOffsetX(force)
	return (self.size.x - _Game:getNativeResolution().x * self:getResolutionScale(force)) / 2
end

---Returns the scale of screen contents, depending on the current window size.
---@param force boolean? Whether the returned value should be scaled with the window even if the canvas rendering is enabled.
---@return number
function Display:getResolutionScale(force)
	if _Game.renderCanvas and not force then
		-- If all stuff is rendered on a canvas, the canvas itself will be scaled.
		return 1
	else
		return self.size.y / _Game:getNativeResolution().y
	end
end

---Returns the onscreen (or on-canvas if canvas rendering is enabled) position of the given logical point.
---@param pos Vector2 The logical point of which the onscreen position will be returned.
---@return Vector2
function Display:posOnScreen(pos)
	if _Game.renderCanvas then
		-- If all stuff is rendered on a canvas, the canvas itself will be scaled and positioned.
		return pos
	else
		return pos * self:getResolutionScale() + Vec2(self:getDisplayOffsetX(), 0)
	end
end

---Returns the logical position of the given onscreen point.
---@param pos Vector2 The onscreen point of which the logical position will be returned.
---@return Vector2
function Display:posFromScreen(pos)
	return (pos - Vec2(self:getDisplayOffsetX(true), 0)) / self:getResolutionScale(true)
end

return Display