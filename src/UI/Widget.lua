local class = require "com/class"

---@class UIWidget
---@overload fun(name, data, parent):UIWidget
local UIWidget = class:derive("UIWidget")

local UIWidgetRectangle = require("src/UI/WidgetRectangle")
local UIWidgetSprite = require("src/UI/WidgetSprite")
local UIWidgetSpriteButton = require("src/UI/WidgetSpriteButton")
local UIWidgetSpriteButtonCheckbox = require("src/UI/WidgetSpriteButtonCheckbox")
local UIWidgetSpriteButtonSlider = require("src/UI/WidgetSpriteButtonSlider")
local UIWidgetSpriteProgress = require("src/UI/WidgetSpriteProgress")
local UIWidgetText = require("src/UI/WidgetText")
local UIWidgetTextInput = require("src/UI/WidgetTextInput")
local UIWidgetParticle = require("src/UI/WidgetParticle")
local UIWidgetLevel = require("src/UI/WidgetLevel")

local Vec2 = require("src/Essentials/Vector2")



function UIWidget:new(name, data, parent)
	self.name = name

	-- positions, alpha etc. are:
	-- local in variables
	-- global in methods
	if type(data) == "string" then data = _LoadJson(_ParsePath(data)) end

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
		self.widget = UIWidgetSpriteButton(self, data.sprite)
	elseif data.type == "spriteButtonCheckbox" then
		self.widget = UIWidgetSpriteButtonCheckbox(self, data.sprite)
	elseif data.type == "spriteButtonSlider" then
		self.widget = UIWidgetSpriteButtonSlider(self, data.sprite, data.bounds)
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
	if self.animationTime then
		self.animationTime = self.animationTime + dt

		local animation = self.visible and self.animations.in_ or self.animations.out
		local t = math.min(self.animationTime / animation.time, 1)
		if animation.type == "fade" then
			self.alpha = animation.startValue * (1 - t) + animation.endValue * t
		elseif animation.type == "move" then
			self.pos = _ParseVec2(animation.startPos) * (1 - t) + _ParseVec2(animation.endPos) * t
		end

		if self.animationTime >= animation.time then
			self.animationTime = nil
			if self.visible then
				self:executeAction("showEnd")
				if self.widget and self.widget.type == "particle" then self.widget:spawn() end
			else
				self:executeAction("hideEnd")
			end
			--if not self.visible then self.alpha = 0 end
			-- instead, you need to clean up the black background manually!
		end
	end
	if self.time then
		self.time = self.time - dt
		if self.time <= 0 then
			self.time = nil
			if self.visible then self:hide() else self:show() end
		end
	end
	-- schedule if was deliberately cancelled from the timer - avoid softlock
	if not self.time and self.parent and not self.parent:isVisible() then
		if self.visible then self.time = self.hideDelay else self.time = self.showDelay end
	end
	if self.widget and self.widget.update then self.widget:update(dt) end

	for childN, child in pairs(self.children) do
		child:update(dt)
	end
end

function UIWidget:show()
	if self.time then return end
	if not self.visible then
		--print("[" .. tostring(totalTime) .. "] " .. self:getFullName() .. " shown")
		self.visible = true
		if self.animations.in_ then
			self.animationTime = 0
			if self.animations.in_.type == "fade" then -- prevent background flickering on the first frame
				self.alpha = self.animations.in_.startValue
			end
		else
			self.animationTime = nil -- sets to 0 if animation exists, nil otherwise
			self.alpha = 1
			if self.widget and self.widget.type == "particle" then self.widget:spawn() end
		end
		if self.sounds.in_ then self.sounds.in_:play() end
	end
	self.time = self.hideDelay

	for childN, child in pairs(self.children) do
		if child.inheritShow then
			child:show()
		end
	end
end

function UIWidget:hide()
	if not self.showPermanently then
		if self.visible then
			--print("[" .. tostring(totalTime) .. "] " .. self:getFullName() .. " hidden")
			self.visible = false
			if self.animations.out then
				self.animationTime = 0
			else
				self.animationTime = nil -- sets to 0 if animation exists, nil otherwise
				if self.widget and self.widget.type == "particle" then self.widget:despawn() end
			end
			if self.sounds.out then self.sounds.out:play() end
			self.time = self.showDelay
		else
			self.time = nil
		end
	end

	for childN, child in pairs(self.children) do
		if child.inheritHide then
			child:hide()
		end
	end
end

function UIWidget:clean()
	if not self.showPermanently then self.alpha = 0 end
	for childN, child in pairs(self.children) do
		child:clean()
	end
end

function UIWidget:click()
	if self.active and self.widget and self.widget.click then self.widget:click() end

	for childN, child in pairs(self.children) do
		child:click()
	end
end

function UIWidget:unclick()
	if self.widget and self.widget.unclick then self.widget:unclick() end

	for childN, child in pairs(self.children) do
		child:unclick()
	end
end

function UIWidget:keypressed(key)
	if self.active and self.widget and self.widget.keypressed then self.widget:keypressed(key) end

	for childN, child in pairs(self.children) do
		child:keypressed(key)
	end
end

function UIWidget:textinput(t)
	if self.active and self.widget and self.widget.textinput then self.widget:textinput(t) end

	for childN, child in pairs(self.children) do
		child:textinput(t)
	end
end

function UIWidget:setActive(r)
	if not r then _Game.uiManager:resetActive() end

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



-- APPROACH 1: ORIGINAL
--[[
function UIWidget:generateDrawData()
	for childN, child in pairs(self.children) do
		child:generateDrawData()
	end
	if self.widget and self.widget.type == "text" then
		self.widget.textTmp = parseString(self.widget.text)
	end
end

function UIWidget:draw(layer)
	for childN, child in pairs(self.children) do
		child:draw(layer)
	end
	dbg.uiWidgetCount = dbg.uiWidgetCount + 1
	if self:getAlpha() == 0 then return end -- why drawing excessively?
	if self.widget and self:getLayer() == layer then self.widget:draw() end
end
]]--



-- APPROACH 2: OPTIMIZED

--[[
function UIWidget:generateDrawData()
	for childN, child in pairs(self.children) do
		child:generateDrawData()
	end
	if self.widget and self.widget.type == "text" then
		self.widget.textTmp = parseString(self.widget.text)
	end
end

function UIWidget:draw(layer)
	if self:getAlpha() == 0 then return end -- why drawing excessively?
	for childN, child in pairs(self.children) do
		child:draw(layer)
	end
	dbg.uiWidgetCount = dbg.uiWidgetCount + 1
	if self.widget and self:getLayer() == layer then self.widget:draw() end
end
]]--


-- APPROACH 3: MASSIVELY OPTIMIZED
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
			self.widget.textTmp = _ParseString(self.widget.text)
		end
	end
end

function UIWidget:draw()
	_Debug.uiWidgetCount = _Debug.uiWidgetCount + 1
	self.widget:draw()
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

-- This function is phased out because it literally outputs itself but with less data.
-- function UIWidget:getTreeData()
	-- -- You may want to run this on the highest widget.
	-- local data = {name = self.name, visible = self.visible, time = self.time, children = {}}
	-- for childN, child in pairs(self.children) do
		-- table.insert(data.children, child:getTreeData())
	-- end
	-- return data
-- end

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

function UIWidget:getAlpha()
	if self.parent then return self.parent:getAlpha() * self.alpha else return self.alpha end
end

function UIWidget:getLayer()
	if self.layer then return self.layer else return self.parent:getLayer() end
end

-- function UIWidget:getVisible()
	-- local b = false
	-- for childN, child in pairs(self.children) do
		-- b = b or child:getVisible()
	-- end
	-- return b or (self.visible and not self.showPermanently)
-- end

function UIWidget:isVisible()
	if self.parent then return self.parent:isVisible() and self.visible else return self.visible end
end

function UIWidget:isActive()
	if not self.widget then return false end
	return self:isVisible() and self.active and self.widget.enableForced
end

function UIWidget:getAnimationFinished()
	local b = true
	for childN, child in pairs(self.children) do
		b = b and child:getAnimationFinished()
	end
	return b and not self.animationTime
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
	if not self.actions[actionType] then self.actions[actionType] = {} end
	table.insert(self.actions[actionType], f)
end



return UIWidget
