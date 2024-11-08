local class = require "com.class"

---@class UITreeDebug
---@overload fun():UITreeDebug
local UITreeDebug = class:derive("UITreeDebug")

local Vec2 = require("src.Essentials.Vector2")



function UITreeDebug:new()
	self.visible = false
	self.listOffset = 0

	self.widgetDebugCount = 0
	self.mouse = Vec2()
	self.mousePressed = false
	self.scrollPressOffset = nil
	self.hoveredEntry = nil
	self.collapsedEntries = {}
	self.autoCollapseInvisible = false
end



function UITreeDebug:draw()
	self.hoveredEntry = nil
	if not self.visible then
		return
	end

    -- Scrolling logic.
    local height = love.graphics.getHeight()
    local mousePos = _PosOnScreen(_MousePos)
	local mousePressed = love.mouse.isDown(1)
    local scrollbarWidth = 15
    local scrollbarHeight = 50
    local logicalHeight = height - scrollbarHeight
    local maxWidgets = height / 15
    local maxOffset = (self.widgetDebugCount - maxWidgets) * 15 + 30

    -- if the mouse is in clicked state then move the rectangle here
    if mousePressed then
        if not self.scrollPressOffset then
            self.scrollPressOffset = self.listOffset - mousePos.y * (maxOffset / logicalHeight)
        end
        if self.mouse.x < scrollbarWidth then
            self.listOffset = mousePos.y * (maxOffset / logicalHeight) + self.scrollPressOffset
        end
    else
        self.scrollPressOffset = nil
    end

    -- Enforce the limits.
    self.listOffset = math.max(math.min(self.listOffset, maxOffset), 0)

    -- Which one we've hovered?
    local hover = nil
    if mousePos.x > scrollbarWidth and mousePos.x < 500 then
        hover = math.floor((self.listOffset + mousePos.y) / 15)
    end

    -- Draw stuff.
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 500, height)
    for i, line in ipairs(self:getUITreeText()) do
        local y = i * 15 - self.listOffset
        if i == hover then
            love.graphics.setColor(1, 0, 1, 0.3)
            love.graphics.rectangle("fill", 15, y, 485, 15)
            self.hoveredEntry = line[10]
        elseif self.autoCollapseInvisible and line[11] then
            love.graphics.setColor(0, 0, 1, 0.3)
            love.graphics.rectangle("fill", 15, y, 485, 15)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.print({line[9],line[1]}, 20, y)
        love.graphics.print(line[2], 260, y)
        love.graphics.print(line[3], 270, y)
        love.graphics.print(line[4], 280, y)
        love.graphics.print(line[5], 310, y)
        love.graphics.print(line[6], 340, y)
        love.graphics.print(line[7], 370, y)
        love.graphics.print(line[8], 410, y)
    end

    -- draw the scroll rectangle
    if self.widgetDebugCount > maxWidgets then
        local yy = self.listOffset / maxOffset * logicalHeight
		if (mousePos.x < scrollbarWidth and mousePos.y > yy and mousePos.y < yy + scrollbarHeight) or (mousePressed and self.mouse.x < scrollbarWidth) then
			love.graphics.setColor(0, 1, 0)
		else
			love.graphics.setColor(0.25, 0.75, 0.25)
		end
        love.graphics.rectangle("fill", 0, yy, scrollbarWidth, scrollbarHeight)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(scrollbarWidth, 0, scrollbarWidth, height)
    end

	-- Draw some debug stuff with the hovered widget.
	if self.hoveredEntry then
		self.hoveredEntry:drawDebug()
	end
end



function UITreeDebug:getUITreeText(node, rowTable, indent)
	if not node then
		self.widgetDebugCount = 0
	end

	local ui2 = _Game.configManager.config.useUI2
	if ui2 then
		node = node or _Game.uiManager.rootNodes["root"] or _Game.uiManager.rootNodes["splash"]
	else
		node = node or _Game.uiManager.widgets.root or _Game.uiManager.widgets.splash
	end
	rowTable = rowTable or {}
	indent = indent or 0

	if node then
		local forAutoCollapsing = not ui2 and (node:hasChildren() and not node:isVisible() and node:isNotAnimating())
		local collapsed = node:hasChildren() and self.collapsedEntries[node] or (self.autoCollapseInvisible and forAutoCollapsing)

		local name = node.name
		for i = 1, indent do name = "    " .. name end
		if collapsed then
			name = name .. " ..."
		end
		local visible = ""
		local visible2 = ""
		if not ui2 then
			visible = node.visible and "X" or ""
			visible2 = node:isVisible() and "V" or ""
		end
		local active = node:isActive() and "A" or ""
		local alpha = string.format("%.1f", node.alpha)
		local alpha2
		if ui2 then
			alpha2 = string.format("%.1f", node:getGlobalAlpha())
		else
			alpha2 = string.format("%.1f", node:getAlpha())
		end
		local time = ""
		if not ui2 then
			time = node.time and tostring(math.floor(node.time * 100) / 100) or "-"
		end
		local pos = tostring(node.pos)
		local color = node.debugColor or {1, 1, 1}

		table.insert(rowTable, {name, visible, visible2, active, alpha, alpha2, time, pos, color, node, forAutoCollapsing})
		self.widgetDebugCount = self.widgetDebugCount + 1

		if not collapsed then
			local children = {}
			for childN, child in pairs(node.children) do
				table.insert(children, child)
			end
			table.sort(children, function(a, b) return a.name < b.name end)
			for i, child in ipairs(children) do
				self:getUITreeText(child, rowTable, indent + 1)
			end
		end
	end

	return rowTable
end



function UITreeDebug:isHovered()
	return self.visible and _PosOnScreen(_MousePos).x < 500
end



function UITreeDebug:keypressed(key)
	if key == "f2" then
		if love.keyboard.isDown("lctrl", "rctrl") then
			self.autoCollapseInvisible = not self.autoCollapseInvisible
			_Debug.console:print({_COLORS.aqua, string.format("[UI Debug] Auto-collapsing hidden UI elements: %s", self.autoCollapseInvisible and "ON" or "OFF")})
		else
			self.visible = not self.visible
		end
	end
	if key == "pagedown" then self.listOffset = self.listOffset + 300 end
	if key == "pageup" then self.listOffset = self.listOffset - 300 end
end



function UITreeDebug:mousepressed(x, y, button)
	if button == 1 then
		self.mouse = Vec2(x, y)
	end
end



function UITreeDebug:mousereleased(x, y, button)
	if button == 1 then
		self.mouse = Vec2(x, y)
		if self.hoveredEntry then
			if self.collapsedEntries[self.hoveredEntry] then
				self.collapsedEntries[self.hoveredEntry] = nil
			else
				self.collapsedEntries[self.hoveredEntry] = true
			end
		end
	end
end



function UITreeDebug:wheelmoved(x, y)
	self.listOffset = self.listOffset - y * 45
end



return UITreeDebug