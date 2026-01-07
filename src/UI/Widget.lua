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
---@overload fun(name: string, data: table|string, parent: UIWidget?):UIWidget
local UIWidget = class:derive("UIWidget")

---Constructs a new UI widget.
---@param name string The widget name.
---@param data table|string The raw widget data from its appropriate JSON file, or path to the file with widget data.
---@param parent UIWidget? The parent widget.
function UIWidget:new(name, data, parent)
	self.name = name

	-- If the provided data is a path to a JSON UI file, fetch data from that file.
	-- TODO: Fetch data before calling `:new()` instead.
	if type(data) == "string" then
		data = assert(_Utils.loadJson(_ParsePath(data)), string.format("Could not load UI layout file: %s", data))
	end
	self.type = data.type or "none"
	-- positions, alpha etc. are:
	-- local in variables
	-- global in methods
	self.pos = Vec2(data.pos.x, data.pos.y)
	self.layer = data.layer or (parent and parent.layer)
	self.alpha = data.alpha or 1

	---@alias WidgetAnimation {type: "fade"|"move", startValue: number?, startPos: Vector2?, endValue: number?, endPos: Vector2?, time: number}
	---@type {in_: WidgetAnimation?, out: WidgetAnimation?}
	self.animations = {in_ = nil, out = nil}
	if data.animations then
		self.animations.in_ = data.animations.in_
		self.animations.out = data.animations.out
	end
	---@type {in_: SoundEvent?, out: SoundEvent?}
	self.sounds = {in_ = nil, out = nil}
	if data.sounds then
		self.sounds.in_ = data.sounds.in_ and _Res:getSoundEvent(data.sounds.in_)
		self.sounds.out = data.sounds.out and _Res:getSoundEvent(data.sounds.out)
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

	self.parent = parent
	---@type table<string, UIWidget>
	self.children = {}
	if data.children then
		for childN, child in pairs(data.children) do
			self.children[childN] = UIWidget(childN, child, self)
		end
	end

	self.inheritShow = data.inheritShow
	self.inheritHide = data.inheritHide
	self.inheritPos = data.inheritPos ~= false
	self.visible = false
	self.neverDisabled = data.neverDisabled
	self.animationTime = nil
	self.hideDelay = data.hideDelay
	self.showDelay = data.showDelay
	self.time = data.showDelay

	---@type table<string, {f: function, parameters: any[]?, oneshot: boolean?, delQueue: boolean?}[]>
	self.actions = {}
	self.active = false
	self.hotkey = data.hotkey

	self.callbacks = data.callbacks

	-- init animation alpha/position
	if self.animations.in_ then
		if self.animations.in_.type == "fade" then
			self.alpha = assert(self.animations.in_.startValue, string.format("animations.in_.startValue must exist in node %s", self:getFullName()))
		elseif self.animations.in_.type == "move" then
			self.pos = Vec2(self.animations.in_.startPos.x, self.animations.in_.startPos.y)
		end
	end
end

---Updates the UI widget's animations, timing and widget.
---@param dt number Time delta in seconds.
function UIWidget:update(dt)
	-- Update the animations.
	if self.animationTime then
		self.animationTime = self.animationTime + dt

		-- Pick one of two available animations and interpolate: either the position, or the alpha value.
		local animation = self.visible and self.animations.in_ or self.animations.out
		assert(animation, string.format("Animating a widget which does not have any animation is forbidden: %s", self:getFullName()))
		local t = math.min(self.animationTime / animation.time, 1)
		if animation.type == "fade" then
			self.alpha = animation.startValue * (1 - t) + animation.endValue * t
		elseif animation.type == "move" then
			self.pos = Vec2(animation.startPos.x, animation.startPos.y) * (1 - t) + Vec2(animation.endPos.x, animation.endPos.y) * t
		end

		-- If the animation has finished:
		if self.animationTime >= animation.time then
			self.animationTime = nil
			if self.visible then
				-- If this Widget has finished appearing.
				self:executeAction("showEnd")
				if self.widget and self.widget.type == "particle" then
					self.widget:spawn()
				end
			else
				-- If this Widget has finished disappearing.
				self:executeAction("hideEnd")
			end
		end
	end

	-- Update the scheduled show/delay time, but only if our parent is visible (or we are a root node).
	if self.time and (not self.parent or self.parent:isVisible()) then
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
	-- Reschedule the show/delay once our parent has gone invisible, so we can fire ourselves once again.
	if not self.time and self.parent and not self.parent:isVisible() then
		if self.visible then
			self.time = self.hideDelay
		else
			self.time = self.showDelay
		end
	end

	-- Update the widget, if applicable.
	if self.widget and self.widget.update then
		self.widget:update(dt)
	end

	-- Propagate updates to children.
	for childN, child in pairs(self.children) do
		child:update(dt)
	end
end

---Shows the widget or prepares the widget to be shown.
---Trying to show the widget while it's already scheduled to show will do nothing.
function UIWidget:show()
	-- Don't show us if we're scheduled to show later.
	if self.time then
		return
	end

	-- If we're not visible, do the main showing procedure.
	if not self.visible then
		self.visible = true
		if self.animations.in_ then
			-- If we have an animation defined, start the animation.
			self.animationTime = 0
			if self.animations.in_.type == "fade" then -- prevent background flickering on the first frame
				self.alpha = assert(self.animations.in_.startValue, string.format("animations.in_.startValue must exist in node %s", self:getFullName()))
			end
		else
			-- Otherwise, assume that we're just going to pop up with full opacity.
			self.animationTime = nil
			self.alpha = 1
			-- Don't forget to spawn the particle, if we're a particle widget!
			if self.widget and self.widget.type == "particle" then
				self.widget:spawn()
			end
		end
		-- Play the sound if defined.
		if self.sounds.in_ then
			self.sounds.in_:play()
		end
	end
	-- Start ticking the time to hide ourselves again.
	self.time = self.hideDelay

	-- Show all children too, if they allow propagation.
	for childN, child in pairs(self.children) do
		if child.inheritShow then
			child:show()
		end
	end
end

---Hides the widget or prepares the widget to be hidden.
---Trying to hide the widget while it's already scheduled to hide will cause it to reset the timer(?).
---Trying to hide the widget while it's scheduled to show will cancel the scheduled show operation.
function UIWidget:hide()
	-- If we're visible, do the main hiding procedure.
	if self.visible then
		self.visible = false
		if self.animations.out then
			-- If we have an animation defined, start the animation.
			self.animationTime = 0
		else
			-- Otherwise, why are we not hiding ourselves immediately?
			self.animationTime = nil
			-- Oh, and despawn the particles, too.
			if self.widget and self.widget.type == "particle" then
				self.widget:despawn()
			end
		end
		-- Play the sound if defined.
		if self.sounds.out then
			self.sounds.out:play()
		end
		-- Start ticking the timer to show ourselves again.
		self.time = self.showDelay
	else
		-- Wait, so if we hide ourselves twice, the timer gets cancelled and the widget stays hidden forever?
		self.time = nil
	end

	-- Hide all children too, if they allow propagation.
	for childN, child in pairs(self.children) do
		if child.inheritHide then
			child:hide()
		end
	end
end

---Clears the Widget by setting its and all children's alpha to 0 and removing all particles spawned by this or any descendant Widget.
function UIWidget:clean()
	self.alpha = 0
	if self.widget and self.widget.type == "particle" then
		self.widget:clean()
	end

	for childN, child in pairs(self.children) do
		child:clean()
	end
end

---Clicks this Widget and all child Widgets.
function UIWidget:click()
	if self.active and self.widget and self.widget.click then
		self.widget:click()
	end

	for childN, child in pairs(self.children) do
		child:click()
	end
end

---Unclicks this Widget and all child Widgets.
function UIWidget:unclick()
	if self.widget and self.widget.unclick then
		self.widget:unclick()
	end

	for childN, child in pairs(self.children) do
		child:unclick()
	end
end

---LOVE2D callback for when a key is pressed.
---@param key string The key that has been pressed.
function UIWidget:keypressed(key)
	if self.active and self.widget and self.widget.keypressed then
		self.widget:keypressed(key)
	end

	for childN, child in pairs(self.children) do
		child:keypressed(key)
	end
end

---LOVE2D callback for when a text character has been entered.
---@param t string The character that has been entered.
function UIWidget:textinput(t)
	if self.active and self.widget and self.widget.textinput then
		self.widget:textinput(t)
	end

	for childN, child in pairs(self.children) do
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

	for childN, child in pairs(self.children) do
		child:setActive(true)
	end
end

---Sets this Widget and all children Widgets as no longer active.
function UIWidget:resetActive()
	self.active = false

	for childN, child in pairs(self.children) do
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

	for childN, child in pairs(self.children) do
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
	for childN, child in pairs(self.children) do
		child:draw()
	end
end

---Draws the debugging information about specifically this Widget: a rectangle showing its bounding box.
function UIWidget:drawDebug()
	local p = self:getPos()
	local s = self:getSize()
	local ps = (self.widget and self.widget.align) and self:getPos() - self:getSize() * self.widget.align or p
	-- Draw size
	love.graphics.setColor(0, 1, 1, self:getAlpha())
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", ps.x, ps.y, s.x, s.y)
	love.graphics.setColor(0, 1, 1, 0.4 * self:getAlpha())
	love.graphics.rectangle("fill", ps.x, ps.y, s.x, s.y)
	-- Draw position
	love.graphics.setColor(1, 0, 1)
	love.graphics.setLineWidth(4)
	love.graphics.line(p.x - 10, p.y, p.x + 10, p.y)
	love.graphics.line(p.x, p.y - 10, p.x, p.y + 10)
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
---@return Vector2
function UIWidget:getPos()
	if self.parent and self.inheritPos then
		local parentPos = self.parent:getPos()
		if self.parent.widget and self.parent.widget.type == "text" then
			parentPos = parentPos + self.parent.widget:getSize() * (Vec2(0.5) - self.parent.widget.align)
		end
		return parentPos + self.pos
	end
	return self.pos
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

---Returns whether this Widget is currently marked as visible. Alpha is NOT taken into account, the widget can be visible even when its alpha is 0!
---@return boolean
function UIWidget:isVisible()
	return self.visible and (not self.parent or self.parent:isVisible())
end

---Returns whether this Widget is active. Only if the Widget is marked as active and is visible can this Widget be active.
---@return boolean
function UIWidget:isActive()
	if self.widget then
		return self:isVisible() and self.active and self.widget.enableForced
	end
	return false
end

---Returns whether this Widget and its children are neither being animated right now nor are they scheduled to be animated.
---@return boolean
function UIWidget:isNotAnimating()
	if self.animationTime then
		return false
	end
	for childN, child in pairs(self.children) do
		if not child:isNotAnimating() then
			return false
		end
	end
	return true
end

---Returns `true` if this Widget has at least one child Widget, `false` otherwise.
---@return boolean
function UIWidget:hasChildren()
	return not _Utils.tableIsEmpty(self.children)
end

---Executes all registered action callback; both registered in the JSON files as well as registered via the UI script.
---@param actionType string The action type to be executed.
function UIWidget:executeAction(actionType)
-- An action is a list of functions.
	-- Execute defined functions (JSON)
	if self.callbacks and self.callbacks[actionType] then
		local callback = self.callbacks[actionType]
		if type(callback) == "string" then
			_Game.uiManager:executeCallback(callback)
		else
			_Game.uiManager:executeCallback(callback.name, callback.parameters)
		end
	end
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
