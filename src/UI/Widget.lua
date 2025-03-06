local class = require "com.class"

---@class UIWidget
---@overload fun(name, data, parent):UIWidget
local UIWidget = class:derive("UIWidget")

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

local Vec2 = require("src.Essentials.Vector2")



function UIWidget:new(name, data, parent)
	self.name = name

	-- positions, alpha etc. are:
	-- local in variables
	-- global in methods
	if type(data) == "string" then data = _Utils.loadJson(_ParsePath(data)) end
	self.type = data.type or "none"
	self.pos = _ParseVec2(data.pos)
	self.layer = data.layer
	self.alpha = data.alpha

	self.animations = {in_ = nil, out = nil}
	if data.animations then
		self.animations.in_ = data.animations.in_
		self.animations.out = data.animations.out
	end
	self.sounds = {in_ = nil, out = nil}
	if data.sounds then
		if data.sounds.in_ then self.sounds.in_ = _Game.resourceManager:getSoundEvent(data.sounds.in_) end
		if data.sounds.out then self.sounds.out = _Game.resourceManager:getSoundEvent(data.sounds.out) end
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
	else
		self.debugColor = {0.7, 0.7, 0.7}
	end

	if self.widget then
		self.debugColor = self.widget.debugColor
	end

	self.parent = parent
	self.children = {}
	if data.children then
		for childN, child in pairs(data.children) do
			self.children[childN] = UIWidget(childN, child, self)
		end
	end

	self.inheritShow = data.inheritShow
	self.inheritHide = data.inheritHide
	self.inheritPos = data.inheritPos
	if self.inheritPos == nil then self.inheritPos = true end
	self.visible = false
	self.neverDisabled = data.neverDisabled
	self.animationTime = nil
	self.hideDelay = data.hideDelay
	self.showDelay = data.showDelay
	self.time = data.showDelay

	self.actions = {}
	self.active = false
	self.hotkey = data.hotkey

	self.callbacks = data.callbacks



	-- init animation alpha/position
	if self.animations.in_ then
		if self.animations.in_.type == "fade" then
			self.alpha = self.animations.in_.startValue
		elseif self.animations.in_.type == "move" then
			self.pos = _ParseVec2(self.animations.in_.startPos)
		end
	end
end

function UIWidget:update(dt)
	-- Update the animations.
	if self.animationTime then
		self.animationTime = self.animationTime + dt

		-- Pick one of two available animations and interpolate: either the position, or the alpha value.
		local animation = self.visible and self.animations.in_ or self.animations.out
		local t = math.min(self.animationTime / animation.time, 1)
		if animation.type == "fade" then
			self.alpha = animation.startValue * (1 - t) + animation.endValue * t
		elseif animation.type == "move" then
			self.pos = _ParseVec2(animation.startPos) * (1 - t) + _ParseVec2(animation.endPos) * t
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
				self.alpha = self.animations.in_.startValue
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

function UIWidget:resetHideDelay()
	self.time = self.hideDelay
end

function UIWidget:clean()
	self.alpha = 0
	if self.widget and self.widget.type == "particle" then
		self.widget:clean()
	end

	for childN, child in pairs(self.children) do
		child:clean()
	end
end

function UIWidget:click()
	if self.active and self.widget and self.widget.click then
		self.widget:click()
	end

	for childN, child in pairs(self.children) do
		child:click()
	end
end

function UIWidget:unclick()
	if self.widget and self.widget.unclick then
		self.widget:unclick()
	end

	for childN, child in pairs(self.children) do
		child:unclick()
	end
end

function UIWidget:keypressed(key)
	if self.active and self.widget and self.widget.keypressed then
		self.widget:keypressed(key)
	end

	for childN, child in pairs(self.children) do
		child:keypressed(key)
	end
end

function UIWidget:textinput(t)
	if self.active and self.widget and self.widget.textinput then
		self.widget:textinput(t)
	end

	for childN, child in pairs(self.children) do
		child:textinput(t)
	end
end

function UIWidget:setActive(keepAlreadyActive)
	if not keepAlreadyActive then
		_Game.uiManager:resetActive()
	end

	self.active = true

	for childN, child in pairs(self.children) do
		child:setActive(true)
	end
end

function UIWidget:resetActive()
	self.active = false

	for childN, child in pairs(self.children) do
		child:resetActive()
	end
end

function UIWidget:buttonSetEnabled(enabled)
	if self.widget and self.widget.type == "spriteButton" then
		self.widget:setEnabled(enabled)
	end
end

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



function UIWidget:generateDrawData(layers, startN)
	for childN, child in pairs(self.children) do
		child:generateDrawData(layers, startN)
	end
	if self.widget then
		if self:getAlpha() > 0 then
			local names = self:getNames()
			names[1] = startN
			table.insert(layers[self:getLayer()], names)
		end
		if self.widget.type == "text" then
			self.widget.textTmp = self.widget.text
		end
	end
end

function UIWidget:draw()
	_Debug.uiWidgetCount = _Debug.uiWidgetCount + 1
	self.widget:draw()
end

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





function UIWidget:getFullName()
	if self.parent then
		return self.parent:getFullName() .. "." .. self.name
	else
		return self.name
	end
end

function UIWidget:getNames(t)
	t = t or {}
	table.insert(t, 1, self.name)
	return self.parent and self.parent:getNames(t) or t
end

function UIWidget:getPos()
	if self.parent and self.inheritPos then
		local parentPos = self.parent:getPos()
		if self.parent.widget and self.parent.widget.type == "text" then
			parentPos = parentPos + self.parent.widget:getSize() * (Vec2(0.5) - self.parent.widget.align)
		end
		return parentPos + self.pos
	else
		return self.pos
	end
end

function UIWidget:getSize()
	if self.widget and self.widget.getSize then
		return self.widget:getSize()
	end
	return Vec2()
end

function UIWidget:getAlpha()
	return self.parent and self.parent:getAlpha() * self.alpha or self.alpha
end

function UIWidget:getLayer()
	return self.layer or self.parent:getLayer()
end

function UIWidget:isVisible()
	return self.visible and (not self.parent or self.parent:isVisible())
end

function UIWidget:isActive()
	if self.widget then
		return self:isVisible() and self.active and self.widget.enableForced
	end
	return false
end

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

function UIWidget:hasChildren()
	for childN, child in pairs(self.children) do
		return true
	end
	return false
end



function UIWidget:executeAction(actionType)
-- An action is a list of functions.
	-- Execute defined functions (JSON)
	if self.callbacks and self.callbacks[actionType] then
		_Game.uiManager:executeCallback(self.callbacks[actionType])
	end
	-- Execute scheduled functions (UI script)
	if self.actions[actionType] then
		for i, f in ipairs(self.actions[actionType]) do
			f(_Game.uiManager.scriptFunctions)
		end
		self.actions[actionType] = nil
	end
end

function UIWidget:scheduleFunction(actionType, f)
	if not self.actions[actionType] then
		self.actions[actionType] = {}
	end
	table.insert(self.actions[actionType], f)
end



return UIWidget
