local class = require "com.class"

---@class Display
---@overload fun():Display
local Display = class:derive("Display")

local Vec2 = require("src.Essentials.Vector2")

---Constructs a Display Manager.
function Display:new()
    self.size = Vec2(800, 600)
    self.renderResolution = Vec2(800, 600)
    self.renderCanvas = nil

    self.funniFlashlight = false
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
        self.size = self.renderResolution
    end
    love.window.setMode(self.size.x, self.size.y, {fullscreen = fullscreen, resizable = true})
end

---Generates a new Canvas which can be drawn on.
---@param resolution Vector2 The new canvas resolution (native resolution).
---@param mode "filtered"|"pixel" The canvas mode. If `"pixel"`, the canvas image will not be interpolated.
function Display:setCanvas(resolution, mode)
    self.renderResolution = resolution
	self.renderCanvas = love.graphics.newCanvas(resolution.x, resolution.y)
	if mode == "pixel" then
		self.renderCanvas:setFilter("nearest", "nearest")
	end
end

---Returns the X offset of actual screen contents.
---The game is scaled so the vertical axis is always fully covered. This means that on the X axis, the contents need to be positioned
---in such a way that the contents are exactly in the center.
---@return number
function Display:getDisplayOffsetX()
	return (self.size.x - self.renderResolution.x * self:getCanvasScale()) / 2
end

---Returns the scale of screen contents, depending on the current window size.
---@return number
function Display:getCanvasScale()
	return self.size.y / self.renderResolution.y
end

---Returns the logical position of the given onscreen point.
---@param pos Vector2 The onscreen point of which the logical position will be returned.
---@return Vector2
function Display:posFromScreen(pos)
	return (pos - Vec2(self:getDisplayOffsetX(), 0)) / self:getCanvasScale()
end

---Starts drawing on this Display's canvas, clearing it beforehand.
function Display:canvasStart()
	love.graphics.setCanvas({self.renderCanvas, stencil = true})
	love.graphics.clear()
end

---Finishes drawing on this Display's canvas and draws it onto the screen.
function Display:canvasStop()
	love.graphics.setCanvas()
    if self.funniFlashlight then
        love.graphics.stencil(function()
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", _MousePos.x * self:getCanvasScale() + self:getDisplayOffsetX(), _MousePos.y * self:getCanvasScale(), 100 * self:getCanvasScale())
        end, "replace", 1)
        -- mark only these pixels as the pixels which can be affected
        love.graphics.setStencilTest("equal", 1)
    end
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(self.renderCanvas, self:getDisplayOffsetX(), 0, 0, self:getCanvasScale())
    if self.funniFlashlight then
        love.graphics.setStencilTest()
    end
end

return Display