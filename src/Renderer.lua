local Class = require("com.class")

---The Renderer class is a wrapper to some `love.graphics.*` functions, adding a few functionalities on top of it, like layer support.
---@class Renderer : Class
---@overload fun(): Renderer
local Renderer = Class:derive("Renderer")

---Creates a new Renderer.
function Renderer:new()
    self.r, self.g, self.b = 1, 1, 1 -- The working color
    self.alpha = 1 -- The working opacity
    self.font = love.graphics.getFont() -- The working font
    self.sx, self.sy, self.sw, self.sh = nil, nil, nil, nil -- The working scissor
    self.layer = "MAIN" -- The working layer
    ---@type table<string, integer>
    self.layers = {MAIN = 1} -- A list of layers, keyed by their names. The higher the number, the later the layer is drawn.

    ---@alias RendererQueueItem {i: integer, r: number, g: number, b: number, alpha: number, scissorX: number?, scissorY: number?, scissorW: number?, scissorH: number?, layer: string, type: string, [any]: any}
    ---A list of commands to be performed, in the order of placing. When `:flush()` is called, this list is sorted by layer and emptied.
    ---@type RendererQueueItem[]
    self.queue = {}
    self.queueSortFn = function(a, b)
        local la, lb = self.layers[a.layer] or 0, self.layers[b.layer] or 0
        return la == lb and a.i < b.i or la < lb
    end -- A function to determine the final drawing order, passed to `table.sort`.
    self.lastQueueLength = 0 -- How many queue items have been processed on the last flush.
end

---Sets a list of layers which should be available for this Renderer.
---By default, only a single layer called `MAIN` is available.
---@param layers string[] 
function Renderer:setLayers(layers)
    self.layers = {}
    for i, layer in ipairs(layers) do
        self.layers[layer] = i
    end
end

---Sets a color the following `:draw*()` calls will tint the drawn elements with, using a Color instance.
---@param color Color The color to be set.
---@param alpha number? The opacity. `1` by default.
function Renderer:setColor(color, alpha)
    self.r, self.g, self.b = color.r, color.g, color.b
    self.alpha = alpha or 1
end

---Sets a color the following `:draw*()` calls will tint the drawn elements with, using raw numbers. Aliases `love.graphics.setColor()`.
---@param r number The red component value.
---@param g number The green component value.
---@param b number The blue component value.
---@param alpha number? The opacity. `1` by default.
function Renderer:setColorRGB(r, g, b, alpha)
    self.r, self.g, self.b = r, g, b
    self.alpha = alpha or 1
end

---Returns the current font used for `:draw*()` calls. Aliases `love.graphics.getFont()`.
---@return love.Font
function Renderer:getFont()
    return self.font
end

---Sets a font the following `:draw*()` calls will use. Aliases `love.graphics.setFont()`.
---@param font love.Font Font to be set.
function Renderer:setFont(font)
    self.font = font
end

---Sets a scissor for the following `:draw*()` calls. Aliases `love.graphics.setScissor()`.
---@param x number? X position of the top left corner of the scissor.
---@param y number? Y position of the top left corner of the scissor.
---@param w number? Width of the scissor.
---@param h number? Height of the scissor.
function Renderer:setScissor(x, y, w, h)
    self.sx, self.sy = x, y
    self.sw, self.sh = w, h
end

---Sets a layer the following `:draw*()` calls will draw to.
---@param layer string Layer name.
function Renderer:setLayer(layer)
    self.layer = layer
end

---Returns a generic table with fields that each queue item has to have.
---@private
---@return RendererQueueItem
function Renderer:getBaseQueueItem()
    return {
        i = #self.queue,
        r = self.r, g = self.g, b = self.b,
        alpha = self.alpha,
        font = self.font,
        scissorX = self.sx, scissorY = self.sy,
        scissorW = self.sw, scissorH = self.sh,
        layer = self.layer,
        type = ""
    }
end

---Draws a rectangle. Aliases `love.graphics.rectangle()`.
---@param mode "fill"|"line" Rectangle drawing mode.
---@param x number X position of the top left corner of the rectangle.
---@param y number Y position of the top left corner of the rectangle.
---@param w number Width of the rectangle.
---@param h number Height of the rectangle.
function Renderer:drawRectangle(mode, x, y, w, h)
    local item = self:getBaseQueueItem()
    item.type = "rectangle"
    item.mode = mode
    item.x, item.y = x, y
    item.w, item.h = w, h
    table.insert(self.queue, item)
end

---Draws an image. Aliases `love.graphics.draw()`.
---@param image love.Image|love.Canvas The image to be drawn.
---@param quad love.Quad The quad of an image to be drawn.
---@param x number X position of the image.
---@param y number Y position of the image.
---@param rot number? Rotation in radians.
---@param sx number? Horizontal scale.
---@param sy number? Vertical scale.
---@param ox number? Horizontal anchor offset in pixels.
---@param oy number? Vertical anchor offset in pixels.
function Renderer:drawImage(image, quad, x, y, rot, sx, sy, ox, oy)
    local item = self:getBaseQueueItem()
    item.type = "image"
    item.image = image
    item.quad = quad
    item.x, item.y = x, y
    item.rot = rot
    item.sx, item.sy = sx, sy
    item.ox, item.oy = ox, oy
    table.insert(self.queue, item)
end

---Draws text. Aliases `love.graphics.print()`.
---@param text string Text to be drawn.
---@param x number X position of the text.
---@param y number Y position of the text.
---@param rot number? Rotation in radians.
---@param sx number? Horizontal scale.
---@param sy number? Vertical scale.
function Renderer:drawText(text, x, y, rot, sx, sy)
    local item = self:getBaseQueueItem()
    item.type = "text"
    item.text = text
    item.x, item.y = x, y
    item.rot = rot
    item.sx, item.sy = sx, sy
end

---Draws all queued draw instructions on the screen and clears the queue.
function Renderer:flush()
    table.sort(self.queue, self.queueSortFn)
    for i, item in ipairs(self.queue) do
        love.graphics.setColor(item.r, item.g, item.b, item.alpha)
        love.graphics.setFont(item.font)
        love.graphics.setScissor(item.scissorX, item.scissorY, item.scissorW, item.scissorH)
        if item.type == "image" then
            love.graphics.draw(item.image, item.quad, item.x, item.y, item.rot, item.sx, item.sy, item.ox, item.oy)
        elseif item.type == "rectangle" then
            love.graphics.rectangle(item.mode, item.x, item.y, item.w, item.h)
        elseif item.type == "text" then
            love.graphics.print(item.text, item.x, item.y, item.rot, item.sx, item.sy)
        else
            error(string.format("Illegal render work item type: %s", item.type))
        end
    end
    self.lastQueueLength = #self.queue
    _Utils.emptyTable(self.queue)
    -- Clean up just a bit.
    love.graphics.setScissor()
end

---Returns how many entries in the queue were on the last frame.
---@return integer
function Renderer:getLastQueueLength()
    return self.lastQueueLength
end

return Renderer