local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")
local UIWidgetRectangle = require("src.UI.WidgetRectangle")
local UIWidgetSprite = require("src.UI.WidgetSprite")
local UIWidgetSpriteButton = require("src.UI.WidgetSpriteButton")
local UIWidgetSpriteButtonCheckbox = require("src.UI.WidgetSpriteButtonCheckbox")
local UIWidgetSpriteButtonSlider = require("src.UI.WidgetSpriteButtonSlider")
local UIWidgetSpriteProgress = require("src.UI.WidgetSpriteProgress")
local UIWidgetText = require("src.UI.WidgetText")
local UIWidgetTextInput = require("src.UI.WidgetTextInput")
local UIWidgetParticle = require("src.UI.WidgetParticle")
local UIWidgetLevel = require("src.UI.WidgetLevel")

---@class UIWidget
---@overload fun(data: table|string, parent: UIWidget?):UIWidget
local UIWidget = class:derive("UIWidget")

---Constructs a new UI widget.
---@param data table|string The raw widget data from its appropriate JSON file, or path to the file with widget data.
---@param parent UIWidget? The parent widget.
function UIWidget:new(data, parent)
	-- If the provided data is a path to a JSON UI file, fetch data from that file.
	-- TODO: Fetch data before calling `:new()` instead.
	if type(data) == "string" then
		data = assert(_Utils.loadJson(_ParsePath(data)), string.format("Could not load UI layout file: %s", data))
	end

	self.name = assert(data.name, string.format("Unnamed widget found at %s", parent and parent:getFullName() or "<root>"))
	self.type = data.type or "none"
	-- positions, alpha etc. are:
	-- local in variables
	-- global in methods
	self.homeX, self.homeY = data.pos and data.pos.x or 0, data.pos and data.pos.y or 0
	self.x, self.y = self.homeX, self.homeY
	self.layer = data.layer or (parent and parent.layer)
	self.alpha = data.alpha or 1

	---@type {in: SoundEvent?, out: SoundEvent?}
	self.sounds = {}
	if data.sounds then
		self.sounds["in"] = data.sounds["in"] and _Res:getSoundEvent(data.sounds["in"])
		self.sounds["out"] = data.sounds["out"] and _Res:getSoundEvent(data.sounds["out"])
	end

	---@alias WidgetAnimation {target: string, type: "fade"|"move", startValue: number?, startPos: Vector2?, endValue: number?, endPos: Vector2?, time: number, transition: {type: "linear"|"bezier", point1: number?, point2: number?}?}[]
	---@type {in: WidgetAnimation?, out: WidgetAnimation?}
	self.animations = {}
	if data.animations then
		self.animations["in"] = data.animations["in"]
		self.animations["out"] = data.animations["out"]
	end
	self.animation = nil
	self.animationTime = nil
	self.animationStartX, self.animationStartY = nil, nil

	self.parent = parent
	---@type UIWidget[]
	self.children = {}
	if data.children then
		for i, child in ipairs(data.children) do
			table.insert(self.children, UIWidget(child, self))
		end
	end

	self.widget = nil
	if data.type == "rectangle" then
		self.widget = UIWidgetRectangle(self, data.size, data.color)
	elseif data.type == "sprite" then
		self.widget = UIWidgetSprite(self, data.sprite)
	elseif data.type == "spriteButton" then
		self.widget = UIWidgetSpriteButton(self, data.sprite, data.clickSound, data.releaseSound, data.hoverSound, data.orbMasterHoverEffect)
	elseif data.type == "spriteButtonCheckbox" then
		self.widget = UIWidgetSpriteButtonCheckbox(self, data.sprite, data.clickSound, data.releaseSound, data.hoverSound)
	elseif data.type == "spriteButtonSlider" then
		self.widget = UIWidgetSpriteButtonSlider(self, data.sprite, data.bounds, data.clickSound, data.releaseSound, data.hoverSound)
	elseif data.type == "spriteProgress" then
		self.widget = UIWidgetSpriteProgress(self, data.sprite, data.value, data.smooth)
	elseif data.type == "text" then
		self.widget = UIWidgetText(self, data.text, data.font, data.align)
	elseif data.type == "textInput" then
		self.widget = UIWidgetTextInput(self, data.font, data.align, data.cursorSprite, data.maxLength)
	elseif data.type == "particle" then
		self.widget = UIWidgetParticle(self, data.path)
	elseif data.type == "level" then
		self.widget = UIWidgetLevel(self, data.path)
	end

	self.debugColor = self.widget and self.widget.debugColor or {0.7, 0.7, 0.7}

	self.inheritPos = data.inheritPos ~= false
	self.visible = false
	self.neverDisabled = data.neverDisabled
	self.time = nil

	---@type table<string, {f: function, parameters: any[]?, oneshot: boolean?, delQueue: boolean?}[]>
	self.actions = {}
	self.active = false
	self.hotkey = data.hotkey

	-- Init alpha to 0 if an animation is defined.
	if self.animations["in"] then
		self.alpha = 0
	end
end

---Updates the UI widget's animations, timing and widget.
---@param dt number Time delta in seconds.
function UIWidget:update(dt)
	-- Update the animations.
	if self.animationTime then
		self.animationTime = self.animationTime + dt
		self:updateAnimations()
	end

	-- Update the scheduled show/delay time.
	if self.time then
		self.time = self.time - dt
		if self.time <= 0 then
			self.time = nil
			-- If we're visible, hide us, otherwise - show us.
			if self.visible then
				self:executeAction("hideStart")
				self:hide()
			else
				self:executeAction("showStart")
				self:show()
			end
		end
	end

	-- Update the widget, if applicable.
	if self.widget and self.widget.update then
		self.widget:update(dt)
	end

	-- Propagate updates to children.
	for i, child in ipairs(self.children) do
		child:update(dt)
	end
end

---Updates the current and child Widget state based on currently ongoing Animations in this specific Widget, and checks if all the animations have finished.
function UIWidget:updateAnimations()
	if not self.animation then
		return
	end
	local animation = assert(self.animations[self.animation], string.format("Animation not found: %s", self.animation))
	local maxTime = 0
	for i, subanim in ipairs(animation) do
		-- Get the widget we will be animating.
		local widget = self:assertGetChild(subanim.target)
		-- Check the animation progress.
		local t = _Utils.mapc(0, 1, 0, subanim.time, self.animationTime)
		if subanim.transition and subanim.transition.type == "bezier" then
			t = _Utils.bzLerp(t, subanim.transition.point1, subanim.transition.point2)
		end
		maxTime = math.max(maxTime, subanim.time)
		-- Animate the appropriate property.
		if subanim.type == "fade" then
			widget.alpha = _Utils.lerp(subanim.startValue, subanim.endValue, t)
		elseif subanim.type == "move" then
			widget.x = _Utils.lerp(subanim.startPos and subanim.startPos.x or widget.animationStartX, subanim.endPos.x, t)
			widget.y = _Utils.lerp(subanim.startPos and subanim.startPos.y or widget.animationStartY, subanim.endPos.y, t)
		end
	end
	-- Check if all subanimations have finished.
	if self.animationTime >= maxTime then
		-- Finish the animation.
		if self.animation == "in" then
			self:executeAction("showEnd")
		elseif self.animation == "out" then
			self:executeAction("hideEnd")
			-- Reset alpha and position when the animation finishes.
			self.alpha = 0
			for i, subanim in ipairs(animation) do
				local widget = self:assertGetChild(subanim.target)
				widget.x = widget.homeX
				widget.y = widget.homeY
			end
		end
		self.animation = nil
		self.animationTime = nil
	end
end

---Starts the animation with the given name.
---@param name string The animation to start.
function UIWidget:startAnimation(name)
	self.animation = name
	self.animationTime = 0
	for i, subanim in ipairs(self.animations[name]) do
		local widget = self:assertGetChild(subanim.target)
		if name == "in" then
			widget.alpha = 1
		end
		widget.animationStartX = widget.x
		widget.animationStartY = widget.y
	end
	self:updateAnimations()
end

---Shows the widget or starts its showing animation.
function UIWidget:show()
	self.visible = true
	self.alpha = 1
	if self.animations["in"] then
		self:startAnimation("in")
	else
		-- Spawn the particles.
		if self.widget and self.widget.type == "particle" then
			self.widget:spawn()
		end
	end
	-- Play the sound if defined.
	if self.sounds["in"] then
		self.sounds["in"]:play()
	end
end

---Hides the widget or starts the hiding animation.
function UIWidget:hide()
	self.visible = false
	if self.animations["out"] then
		self:startAnimation("out")
	else
		self.alpha = 0
		-- Despawn the particles.
		if self.widget and self.widget.type == "particle" then
			self.widget:despawn()
		end
	end
	-- Play the sound if defined.
	if self.sounds["out"] then
		self.sounds["out"]:play()
	end
end

---Shows the Widget after the specified amount of time.
---If the Widget is already visible, it is hidden first.
---@param delay number Time after which this Widget will be shown, in seconds.
function UIWidget:showAfter(delay)
	self:hide()
	self.alpha = 0
	self.time = delay
end

---Hides the Widget after the specified amount of time.
---Does nothing if the Widget is already invisible.
---@param delay number Time after which this Widget will be hidden, in seconds.
function UIWidget:hideAfter(delay)
	if not self.visible then
		return
	end
	self.time = delay
end

---Spawns all particles on this and all children Widgets.
function UIWidget:showParticles()
	if self.widget and self.widget.type == "particle" then
		self.widget:spawn()
	end

	for i, child in ipairs(self.children) do
		child:showParticles()
	end
end

---Clears all particles on this and all children Widgets.
function UIWidget:hideParticles()
	if self.widget and self.widget.type == "particle" then
		self.widget:despawn()
	end

	for i, child in ipairs(self.children) do
		child:hideParticles()
	end
end

---Clicks this Widget and all child Widgets.
function UIWidget:click()
	if self.active and self.widget and self.widget.click then
		self.widget:click()
	end

	for i, child in ipairs(self.children) do
		child:click()
	end
end

---Unclicks this Widget and all child Widgets.
function UIWidget:unclick()
	if self.widget and self.widget.unclick then
		self.widget:unclick()
	end

	for i, child in ipairs(self.children) do
		child:unclick()
	end
end

---LOVE2D callback for when a key is pressed.
---@param key string The key that has been pressed.
function UIWidget:keypressed(key)
	if self.active and self.widget and self.widget.keypressed then
		self.widget:keypressed(key)
	end

	for i, child in ipairs(self.children) do
		child:keypressed(key)
	end
end

---LOVE2D callback for when a text character has been entered.
---@param t string The character that has been entered.
function UIWidget:textinput(t)
	if self.active and self.widget and self.widget.textinput then
		self.widget:textinput(t)
	end

	for i, child in ipairs(self.children) do
		child:textinput(t)
	end
end

---Sets this Widget and all children Widgets as active.
---Only active Widgets can be hovered, clicked and react to keyboard input.
---@param keepAlreadyActive boolean? If `true`, the already active Widgets will not be deactivated.
function UIWidget:setActive(keepAlreadyActive)
	if not keepAlreadyActive then
		_Game.uiManager:resetActive()
	end

	self.active = true

	for i, child in ipairs(self.children) do
		child:setActive(true)
	end
end

---Sets this Widget and all children Widgets as no longer active.
function UIWidget:resetActive()
	self.active = false

	for i, child in ipairs(self.children) do
		child:resetActive()
	end
end

---Sets whether this specific Widget's button is enabled. If not enabled, the button will be grayed out.
---@param enabled boolean Whether this button should be enabled.
function UIWidget:buttonSetEnabled(enabled)
	if self.widget and self.widget.type == "spriteButton" then
		self.widget:setEnabled(enabled)
	end
end

---Returns whether this specific Widget's button is enabled.
---@return boolean
function UIWidget:isButtonEnabled(enabled)
	if self.widget and self.widget.type == "spriteButton" then
		return self.widget:getEnabled()
	end
	return false
end

---Returns `true` if this Widget's or any child Widget's button is hovered.
---@return boolean
function UIWidget:isButtonHovered()
	if self.active and self.widget then
		if self.widget.type == "spriteButton" and self.widget.hovered then
			return true
		elseif (self.widget.type == "spriteButtonCheckbox" or self.widget.type == "spriteButtonSlider") and self.widget.button.hovered then
			return true
		end
	end

	for i, child in ipairs(self.children) do
		if child:isButtonHovered() then
			return true
		end
	end
	return false
end

---Draws this Widget and all its children.
function UIWidget:draw()
	_Debug.uiWidgetCount = _Debug.uiWidgetCount + 1
	if self.widget and self:getAlpha() > 0 then
		self.widget:draw()
	end
	-- Children are drawn bottom-first (children on top of the list render on top)
	for i = #self.children, 1, -1 do
		self.children[i]:draw()
	end
end

---Draws the debugging information about specifically this Widget: a rectangle showing its bounding box.
function UIWidget:drawDebug()
	local x, y = self:getPos()
	local s = self:getSize() * _Display:getCanvasScale()
	x, y = _Display:posOnScreen(x, y)
	local ps = (self.widget and self.widget.align) and Vec2(x, y) - s * self.widget.align or Vec2(x, y)
	-- Draw size
	love.graphics.setColor(0, 1, 1, self:getAlpha())
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", ps.x, ps.y, s.x, s.y)
	love.graphics.setColor(0, 1, 1, 0.4 * self:getAlpha())
	love.graphics.rectangle("fill", ps.x, ps.y, s.x, s.y)
	-- Draw position
	love.graphics.setColor(1, 0, 1)
	love.graphics.setLineWidth(4)
	love.graphics.line(x - 10, y, x + 10, y)
	love.graphics.line(x, y - 10, x, y + 10)
end

---Prints some information about this Widget to the console.
function UIWidget:printDebug()
	_Debug:print({_COLORS.aqua, "Widget: ", _COLORS.yellow, self.name, _COLORS.aqua, " (", self.debugColor, self.type, _COLORS.aqua, ")"})
	_Debug:print({_COLORS.aqua, "Path: ", _COLORS.yellow, self:getFullName()})
	_Debug:print({_COLORS.aqua, "Scheduled callbacks (if any):"})
	for action, callbacks in pairs(self.actions) do
		_Debug:print({_COLORS.aqua, "  - " .. action .. ": " .. #callbacks .. " found"})
	end
end

---Returns `true` if this Widget should be collapsed on the UI Tree Debug list when the auto-collapsing mode is enabled there.
---@return boolean
function UIWidget:debugShouldBeCollapsed()
	-- Old algorithm
	--return self:hasChildren() and not self:isVisible() and self:isNotAnimating()
	-- New algorithm, only cares about actual visibility and a bit more smart (children checking)
	if self.widget and self:getAlpha() > 0 then
		return false
	end
	for i, child in ipairs(self.children) do
		if not child:debugShouldBeCollapsed() then
			return false
		end
	end
	return true
end

---Returns the full name of this Widget, which is its path separated by dots.
---@return string
function UIWidget:getFullName()
	if self.parent then
		return self.parent:getFullName() .. "." .. self.name
	end
	return self.name
end

---Returns the full path to this Widget, which is a list of widget names starting from the root one.
---@param t string[]? Used internally for recursion.
---@return string[]
function UIWidget:getNames(t)
	t = t or {}
	table.insert(t, 1, self.name)
	return self.parent and self.parent:getNames(t) or t
end

---Returns the global screen position of this Widget.
---@return number, number
function UIWidget:getPos()
	if self.parent and self.inheritPos then
		local parentX, parentY = self.parent:getPos()
		if self.parent.widget and self.parent.widget.type == "text" then
			local parentSize = self.parent.widget:getSize()
			parentX = parentX + parentSize.x * (0.5 - self.parent.widget.align.x)
			parentY = parentY + parentSize.y * (0.5 - self.parent.widget.align.y)
		end
		return parentX + self.x, parentY + self.y
	end
	return self.x, self.y
end

---Returns the global screen size of this Widget.
---@return Vector2
function UIWidget:getSize()
	-- Return the widget size, or 0x0 if this is a widgetless widget.
	if self.widget and self.widget.getSize then
		return self.widget:getSize()
	end
	return Vec2()
end

---Returns the opacity of this Widget.
---@return number
function UIWidget:getAlpha()
	return self.parent and self.parent:getAlpha() * self.alpha or self.alpha
end

---Returns the current layer this Widget is on.
---@return string
function UIWidget:getLayer()
	return self.layer or self.parent:getLayer()
end

---Returns the first child Widget with the provided name.
---If this Widget has no children with that name, returns `nil`.
---@param name string The child's name to look for.
---@return UIWidget?
function UIWidget:getChildN(name)
	for i, child in ipairs(self.children) do
		if child.name == name then
			return child
		end
	end
end

---Returns a child of this Widget by path. If there is no Widget at the given path, returns `nil`.
---@param path string Path to the widget separated by slashes.
---@return UIWidget?
function UIWidget:getChild(path)
	---@type UIWidget?
	local widget = self
	for i, name in ipairs(_Utils.strSplit(path, "/")) do
		if not widget then
			return
		end
		widget = widget:getChildN(name)
	end
	return widget
end

---Returns a child of this Widget by path. If there is no Widget at the given path, throws an error.
---@param path string Path to the widget separated by slashes.
---@return UIWidget
function UIWidget:assertGetChild(path)
	return assert(self:getChild(path), string.format("Widget %s could not find child at %s", self:getFullName(), path))
end

---Returns whether this Widget is currently marked as visible. Alpha is NOT taken into account, the widget can be visible even when its alpha is 0!
---@return boolean
function UIWidget:isVisible()
	return self.visible
end

---Returns whether this Widget is active. Only if the Widget is marked as active and is visible can this Widget be active.
---@return boolean
function UIWidget:isActive()
	return self.active
end

---Returns whether this Widget and its children are neither being animated right now nor are they scheduled to be animated.
---@return boolean
function UIWidget:isNotAnimating()
	if self.animationTime then
		return false
	end
	for i, child in ipairs(self.children) do
		if not child:isNotAnimating() then
			return false
		end
	end
	return true
end

---Returns `true` if this Widget has at least one child Widget, `false` otherwise.
---@return boolean
function UIWidget:hasChildren()
	return #self.children > 0
end

---Executes all registered actions for the given callback.
---@param actionType string The action type to be executed.
function UIWidget:executeAction(actionType)
	-- An action is a list of functions.
	-- Execute scheduled functions (UI script)
	if self.actions[actionType] then
		for i, action in ipairs(self.actions[actionType]) do
			action.f(_Game.uiManager.scriptFunctions, action.parameters)
			action.delQueue = action.oneshot
		end
		-- Clear all oneshot functions.
		_Utils.removeDeadObjects(self.actions[actionType])
	end
end

---Schedules a function to be executed when a particular action happens.
---Once the action is executed, the scheduled function will be removed, i.e. actions are registered as oneshots.
---@param actionType string The action type to listen for.
---@param f function The function to be executed when that particular action type is executed.
---@param parameters any[]? An optional list of parameters which will be passed on to the function.
function UIWidget:scheduleFunction(actionType, f, parameters)
	self.actions[actionType] = self.actions[actionType] or {}
	table.insert(self.actions[actionType], {f = f, parameters = parameters, oneshot = true})
end

---Schedules a function to be executed when a particular action happens.
---Unlike `scheduleFunction()`, the callback will stay after it's executed.
---@param actionType string The action type to listen for.
---@param f function The function to be executed when that particular action type is executed.
---@param parameters any[]? An optional list of parameters which will be passed on to the function.
function UIWidget:setCallback(actionType, f, parameters)
	self.actions[actionType] = self.actions[actionType] or {}
	table.insert(self.actions[actionType], {f = f, parameters = parameters})
end

return UIWidget
