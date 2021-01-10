local class = require "com/class"
local UIWidget = class:derive("UIWidget")

local UIWidgetRectangle = require("src/UI/WidgetRectangle")
local UIWidgetImage = require("src/UI/WidgetImage")
local UIWidgetImageButton = require("src/UI/WidgetImageButton")
local UIWidgetImageButtonCheckbox = require("src/UI/WidgetImageButtonCheckbox")
local UIWidgetImageButtonSlider = require("src/UI/WidgetImageButtonSlider")
local UIWidgetImageProgress = require("src/UI/WidgetImageProgress")
local UIWidgetText = require("src/UI/WidgetText")
local UIWidgetParticle = require("src/UI/WidgetParticle")
local UIWidgetLevel = require("src/UI/WidgetLevel")

local Vec2 = require("src/Essentials/Vector2")

function UIWidget:new(name, data, parent)
	self.name = name
	
	-- positions, alpha etc. are:
	-- local in variables
	-- global in methods
	if type(data) == "string" then data = loadJson(parsePath(data)) end
	
	self.pos = parseVec2(data.pos)
	self.layer = data.layer
	self.alpha = data.alpha
	-- TODO remove the lines after "or" (when the development enters into "fit a converter" (last) phase)
	
	self.animations = {in_ = nil, out = nil}
	if data.animations then
		self.animations.in_ = data.animations.in_
		self.animations.out = data.animations.out
	end
	self.sounds = {in_ = nil, out = nil}
	if data.sounds then
		if data.sounds.in_ then self.sounds.in_ = game.resourceBank:getSound(data.sounds.in_) end
		if data.sounds.out then self.sounds.out = game.resourceBank:getSound(data.sounds.out) end
	end
	
	self.widget = nil
	if data.type == "rectangle" then
		self.widget = UIWidgetRectangle(self, data.size, data.color)
	elseif data.type == "image" then
		self.widget = UIWidgetImage(self, data.image)
	elseif data.type == "imageButton" then
		self.widget = UIWidgetImageButton(self, data.image)
	elseif data.type == "imageButtonCheckbox" then
		self.widget = UIWidgetImageButtonCheckbox(self, data.image)
	elseif data.type == "imageButtonSlider" then
		self.widget = UIWidgetImageButtonSlider(self, data.image, data.bounds)
	elseif data.type == "imageProgress" then
		self.widget = UIWidgetImageProgress(self, data.image, data.value, data.smooth)
	elseif data.type == "text" then
		self.widget = UIWidgetText(self, data.text, data.font, data.align)
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
	self.animationTime = nil
	self.hideDelay = data.hideDelay
	self.showDelay = data.showDelay
	self.time = data.showDelay
	
	self.actions = data.actions or {}
	self.active = false
	self.hotkey = data.hotkey
	
	
	-- init animation alpha/position
	if self.animations.in_ then
		if self.animations.in_.type == "fade" then
			self.alpha = self.animations.in_.startValue
		elseif self.animations.in_.type == "move" then
			self.pos = parseVec2(self.animations.in_.startPos)
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
			self.pos = parseVec2(animation.startPos) * (1 - t) + parseVec2(animation.endPos) * t
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
	if self.time and (not self.parent or self.parent:getVisible()) then
		self.time = self.time - dt
		if self.time <= 0 then
			self.time = nil
			if self.visible then self:hide() else self:show() end
		end
	end
	-- schedule if was deliberately cancelled from the timer - avoid softlock
	if not self.time and self.parent and not self.parent:getVisible() then
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

function UIWidget:setActive(r)
	if not r then game:resetActive() end
	
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
	if self.widget and self.widget.type == "imageButton" then
		self.widget:setEnabled(enabled)
	end
end



function UIWidget:draw(layer, variables)
	for childN, child in pairs(self.children) do
		child:draw(layer, variables)
	end
	if self.widget and self.widget.type == "text" then self.widget.textTmp = parseString(self.widget.text, variables) end
	if self:getAlpha() == 0 then return end -- why drawing excessively?
	if self.widget and self:getLayer() == layer then self.widget:draw(variables) end
end

function UIWidget:getFullName()
	if self.parent then
		return self.parent:getFullName() .. "." .. self.name
	else
		return self.name
	end
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

function UIWidget:getVisible()
	if self.parent then return self.parent:getVisible() and self.visible else return self.visible end
end

function UIWidget:getAnimationFinished()
	local b = true
	for childN, child in pairs(self.children) do
		b = b and child:getAnimationFinished()
	end
	return b and not self.animationTime
end



function UIWidget:executeAction(actionType)
	game:executeEvents(self.actions[actionType])
	-- an action is a list of events
end

function UIWidget:addAction(actionType, event)
	if not self.actions[actionType] then self.actions[actionType] = {} end
	table.insert(self.actions[actionType], event)
end



return UIWidget