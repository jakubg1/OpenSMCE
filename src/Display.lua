local class = require "com.class"

---@class Display
---@overload fun():Display
local Display = class:derive("Display")

---Constructs a Display Manager.
function Display:new()
    self.w, self.h = 800, 600
    self.renderResolutionW, self.renderResolutionH = 800, 600
    self.renderCanvas = nil
    self.renderLayers = {}
    self.renderMode = "filtered"
    ---@type love.Shader[]
    self.shaderStack = {}

    self.funniFlashlight = false
end

---Sets the window settings: resolution, whether it can be changed, and its title.
---@param w integer The new window width.
---@param h integer The new window height.
---@param resizable boolean Whether the window can be resized.
---@param title string The window title.
---@param maximized boolean? If set, the window will be maximized.
function Display:setResolution(w, h, resizable, title, maximized)
	love.window.setMode(w, h, {resizable = resizable})
	if maximized then
		love.window.maximize()
	end
	love.window.setTitle(title)
	self.w, self.h = w, h
end

---Sets whether the window should be fullscreen.
---@param fullscreen boolean Whether the window should be fullscreen.
function Display:setFullscreen(fullscreen)
    if fullscreen == love.window.getFullscreen() then return end
    if fullscreen then
        local _, _, flags = love.window.getMode()
        self.w, self.h = love.window.getDesktopDimensions(flags.display)
    else
        self.w, self.h = self.renderResolutionW, self.renderResolutionH
    end
    love.window.setMode(self.w, self.h, {fullscreen = fullscreen, resizable = true})
end

---Generates a new Canvas which can be drawn on.
---@param w integer The new canvas width (native width).
---@param h integer The new canvas height (native height).
---@param mode "filtered"|"pixel"|"pixelPerfect" The canvas mode. If `"pixel"`, the canvas image will not be interpolated.
function Display:setCanvas(w, h, mode)
    self.renderResolutionW, self.renderResolutionH = w, h
    self.renderMode = mode
	self.renderCanvas = love.graphics.newCanvas(w, h)
    self.renderLayers.MAIN =  love.graphics.newCanvas(w, h)
	self.renderCanvas:setFilter("nearest", "nearest")
	if mode == "pixel" or mode == "pixelPerfect" then
		self.renderLayers.MAIN:setFilter("nearest", "nearest")
	end
end

---Returns the X offset of actual screen contents.
---The game is scaled so the vertical axis is always fully covered. This means that on the X axis, the contents need to be positioned
---in such a way that the contents are exactly in the center.
---@return number
function Display:getDisplayOffsetX()
	return (self.w - self.renderResolutionW * self:getCanvasScale()) / 2
end

---Returns the Y offset of actual screen contents.
---This will only be non-zero in the `"pixelPerfect"` canvas mode.
---@return number
function Display:getDisplayOffsetY()
	return (self.h - self.renderResolutionH * self:getCanvasScale()) / 2
end

---Returns the scale of screen contents, depending on the current window size.
---
---If the display mode is `"pixelPerfect"`, the result is brought down to the nearest integer.
---@return number
function Display:getCanvasScale()
    local scale = self.h / self.renderResolutionH
    if self.renderMode == "pixelPerfect" then
        return math.max(math.floor(scale), 1)
    end
	return scale
end

---Returns the logical position of the given onscreen point.
---@param x number The X coordinate of which the logical position will be returned.
---@param y number The Y coordinate of which the logical position will be returned.
---@return number, number
function Display:posFromScreen(x, y)
    x = (x - self:getDisplayOffsetX()) / self:getCanvasScale()
    y = (y - self:getDisplayOffsetY()) / self:getCanvasScale()
	return x, y
end

---Starts drawing on this Display's canvas, clearing it beforehand.
function Display:canvasStart()
	love.graphics.setCanvas({self.renderLayers.MAIN, stencil = true})
	love.graphics.clear()
end

---Finishes drawing on this Display's canvas and draws it onto the screen.
function Display:canvasStop()
	love.graphics.setCanvas()
    if self.funniFlashlight then
        love.graphics.stencil(function()
            love.graphics.setColor(1, 1, 1)
            local x = _MouseX * self:getCanvasScale() + self:getDisplayOffsetX()
            local y = _MouseY * self:getCanvasScale() + self:getDisplayOffsetY()
            love.graphics.circle("fill", x, y, 100 * self:getCanvasScale())
        end, "replace", 1)
        -- mark only these pixels as the pixels which can be affected
        love.graphics.setStencilTest("equal", 1)
    end
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(self.renderCanvas, self:getDisplayOffsetX(), self:getDisplayOffsetY(), 0, self:getCanvasScale())
    love.graphics.draw(self.renderLayers.MAIN, self:getDisplayOffsetX(), self:getDisplayOffsetY(), 0, self:getCanvasScale())
    if self.funniFlashlight then
        love.graphics.setStencilTest()
    end
end

---Pushes a new shader on the stack. The topmost shader will be used for drawing.
---@param shader Shader The shader to be pushed onto the stack.
function Display:pushShader(shader)
    table.insert(self.shaderStack, shader:getShader())
    love.graphics.setShader(self.shaderStack[#self.shaderStack])
end

---Pops the most recently inserted shader from the stack. If there are no shaders left, throws an error.
function Display:popShader()
    assert(#self.shaderStack > 0, "Attempted to pop from an empty shader stack :(")
    table.remove(self.shaderStack)
    love.graphics.setShader(self.shaderStack[#self.shaderStack])
end

---LOVE2D callback handler when the screen is resized.
---@param w integer Window width, in pixels.
---@param h integer Window height, in pixels.
function Display:resize(w, h)
    self.w, self.h = w, h
end

return Display