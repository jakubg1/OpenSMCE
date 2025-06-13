local class = require "com.class"

---@class EditorMain
---@overload fun(bootScreen):EditorMain
local EditorMain = class:derive("EditorMain")

local Vec2 = require("src.Essentials.Vector2")
local Button = require("src.BootScreen.UI.Button")

local ConfigManager = require("src.ConfigManager")
local ResourceManager = require("src.ResourceManager")



---Constructs a new instance of Game Editor.
---@param name string The name of the game, equivalent to the folder name in `games` directory.
function EditorMain:new(name)
	self.name = name

	self.nativeResolution = Vec2(1280, 720)

	self.resourceManager = nil
	self.configManager = nil

	-- buttons
	self.menuBtn = Button("Quit", _FONT_BIG, Vec2(1170, 4), Vec2(100, 24), function() _LoadBootScreen() end)

	-- other UI stuff
	self.resourceListOffset = 0
	self.resourceList = {}
	self.hoveredResource = nil
	self.selectedResource = nil
	self.spriteScale = 1
	self.hoveredSpriteState = nil
	self.selectedSpriteState = 1
	self.hoveredSpriteFrame = nil
	self.selectedSpriteFrame = 1
end



---Initializes the editor and all of its components.
function EditorMain:init()
	_Log:printt("EditorMain", "Editing game: " .. self.name)

	-- Step 1. Create a resource bank
	self.resourceManager = ResourceManager()
	self.resourceManager:startLoadCounter("main")
	self.resourceManager:scanResources()
	self.resourceManager:stopLoadCounter("main")

	-- Step 2. Load the config
	self.configManager = ConfigManager()

	-- Step 3. Initialize the window
	local res = self:getNativeResolution()
	_Display:setResolution(res, false, "OpenSMCE [" .. _VERSION .. "] - Game Editor - " .. self.name)
	-- Despite the canvas is not used to draw any editor UI, the size is used to calculate the mouse position.
	_Display:setCanvas(res, "filtered")
end



function EditorMain:update(dt)
	self.resourceManager:update(dt)
	-- buttons
	self.menuBtn:update(dt)

	self.hoveredResource = nil
	for i, key in ipairs(self.resourceList) do
		local y = 50 + (i - 1) * 15 - self.resourceListOffset
		if _Utils.isPointInsideBox(_MousePos, Vec2(0, y), Vec2(300, 15)) then
			self.hoveredResource = key
			break
		end
	end

	self.hoveredSpriteState = nil
	self.hoveredSpriteFrame = nil
	if self.selectedResource then
		local sprite = self.resourceManager:getSprite(self.selectedResource)
		for i, state in ipairs(sprite.config.states) do
			local stateY = 630 + (i - 1) * 16
			local frameWidth = 20
			local stateWidth = 100 + frameWidth * state.frames.x * state.frames.y
			if _Utils.isPointInsideBox(_MousePos, Vec2(350, stateY), Vec2(stateWidth, 16)) then
				self.hoveredSpriteState = i
				for j = 1, state.frames.x * state.frames.y do
					local frameX = 450 + (j - 1) * frameWidth
					if _Utils.isPointInsideBox(_MousePos, Vec2(frameX, stateY), Vec2(frameWidth, 16)) then
						self.hoveredSpriteFrame = j
						break
					end
				end
				break
			end
		end
	end
end



function EditorMain:draw()
	-- White color
	love.graphics.setColor(1, 1, 1)

	-----------------------------
	-- HEADER
	-----------------------------
	love.graphics.setFont(_FONT_BIG)
	love.graphics.print("Game Editor", 10, 4)
	love.graphics.setFont(_FONT)
	love.graphics.print(string.format("Editing: games/%s/", self.name), 10, 24)

	-----------------------------
	-- LEFT BAR
	-----------------------------
	if self.resourceManager:getLoadProgress("main") < 1 then
		love.graphics.print("Loading...", 15, 35)
	end
	self.resourceList = self.resourceManager:getResourceList("Sprite")
	table.sort(self.resourceList, function(a, b) return a < b end)
	for i, key in ipairs(self.resourceList) do
		local y = 50 + (i - 1) * 15 - self.resourceListOffset
		-- Background
		if self.selectedResource == key then
			love.graphics.setColor(1, 1, 0)
			love.graphics.rectangle("fill", 0, y, 300, 15)
		elseif self.hoveredResource == key then
			love.graphics.setColor(1, 1, 0, 0.5)
			love.graphics.rectangle("fill", 0, y, 300, 15)
		end
		-- Label
		if self.selectedResource == key then
			love.graphics.setColor(0, 0, 0)
		else
			love.graphics.setColor(1, 1, 1)
		end
		love.graphics.print(key, 20, y)
	end

	-----------------------------
	-- SPRITE
	-----------------------------
	if self.selectedResource then
		local x = 400
		local y = 50
		local sprite = self.resourceManager:getSprite(self.selectedResource)
		local image = sprite.config.image
		local sizeX = image.size.x * self.spriteScale
		local sizeY = image.size.y * self.spriteScale
		-- Background
		love.graphics.setColor(0.5, 0.5, 0.5)
		love.graphics.rectangle("fill", x, y, sizeX, sizeY)
		love.graphics.setColor(0.75, 0.75, 0.75)
		for i = 0, math.ceil(sizeX / 16) - 1 do
			for j = 0, math.ceil(sizeY / 16) - 1 do
				if (i + j) % 2 == 0 then
					local squareX = i * 16
					local squareY = j * 16
					love.graphics.rectangle("fill", x + squareX, y + squareY, math.min(squareX + 16, sizeX) - squareX, math.min(squareY + 16, sizeY) - squareY)
				end
			end
		end
		-- Outline
		--love.graphics.setColor(0, 1, 1)
		--love.graphics.setLineWidth(self.spriteScale)
		--love.graphics.rectangle("line", x - (0.5 * self.spriteScale), y - (0.5 * self.spriteScale), sizeX + self.spriteScale, sizeY + self.spriteScale)
		-- Sprite
		love.graphics.setColor(1, 1, 1)
		image.img:setFilter("nearest", "nearest")
		image:draw(x, y, 0, self.spriteScale)
		-- Selected state outline
		local selectedState = sprite.config.states[self.selectedSpriteState]
		local selectedStatePos = selectedState.pos * self.spriteScale
		local selectedStateSize = sprite.config.frameSize * selectedState.frames * self.spriteScale
		love.graphics.setColor(0, 1, 1)
		love.graphics.setLineWidth(self.spriteScale)
		love.graphics.rectangle("line", x + selectedStatePos.x - (0.5 * self.spriteScale), y + selectedStatePos.y - (0.5 * self.spriteScale), selectedStateSize.x + self.spriteScale, selectedStateSize.y + self.spriteScale)
		-- Hovered state outline
		local hoveredStatePos
		if self.hoveredSpriteState then
			local hoveredState = sprite.config.states[self.hoveredSpriteState]
			hoveredStatePos = hoveredState.pos * self.spriteScale
			local hoveredStateSize = sprite.config.frameSize * hoveredState.frames * self.spriteScale
			if not self.hoveredSpriteFrame then
				love.graphics.setColor(0, 1, 1, 0.5)
				love.graphics.setLineWidth(self.spriteScale)
				love.graphics.rectangle("fill", x + hoveredStatePos.x, y + hoveredStatePos.y, hoveredStateSize.x, hoveredStateSize.y)
			end
		end
		-- Selected frame outline
		local selectedFramePos = sprite:getFramePos(self.selectedSpriteState, self.selectedSpriteFrame) * self.spriteScale
		local selectedFrameSize = sprite.config.frameSize * self.spriteScale
		love.graphics.setColor(1, 0, 0)
		love.graphics.setLineWidth(self.spriteScale)
		love.graphics.rectangle("line", x + selectedFramePos.x + (0.5 * self.spriteScale), y + selectedFramePos.y + (0.5 * self.spriteScale), selectedFrameSize.x - self.spriteScale, selectedFrameSize.y - self.spriteScale)
		-- Hovered frame outline
		if self.hoveredSpriteFrame then
			local hoveredFramePos = sprite:getFramePos(self.hoveredSpriteState, self.hoveredSpriteFrame) * self.spriteScale
			local hoveredFrameSize = sprite.config.frameSize * self.spriteScale
			love.graphics.setColor(1, 0, 0, 0.5)
			love.graphics.setLineWidth(self.spriteScale)
			love.graphics.rectangle("fill", x + hoveredFramePos.x, y + hoveredFramePos.y, hoveredFrameSize.x, hoveredFrameSize.y)
		end


		-- BOTTOM DETAILS
		love.graphics.setColor(1, 1, 1)
		love.graphics.print(string.format("Sprite: %s, Size: %s x %s, Scale: %s", self.selectedResource, image.size.x, image.size.y, self.spriteScale), 400, 600)
		for i, state in ipairs(sprite.config.states) do
			local stateY = 630 + (i - 1) * 16
			if self.selectedSpriteState == i then
				love.graphics.setColor(0, 1, 1)
				love.graphics.rectangle("fill", 350, stateY, 100, 16)
			elseif self.hoveredSpriteState == i then
				love.graphics.setColor(0, 1, 1, 0.5)
				love.graphics.rectangle("fill", 350, stateY, 100, 16)
			end
			if self.selectedSpriteState == i then
				love.graphics.setColor(0, 0, 0)
			else
				love.graphics.setColor(1, 1, 1)
			end
			love.graphics.print(string.format("State %s", i), 350, stateY)
			love.graphics.setColor(1, 1, 1)
			love.graphics.setLineWidth(1)
			love.graphics.rectangle("line", 349.5, stateY + 0.5, 100, 16)
			local frameWidth = 20
			for j = 1, state.frames.x * state.frames.y do
				local frameX = 450 + (j - 1) * frameWidth
				local frameText = tostring(j)
				if self.selectedSpriteState == i and self.selectedSpriteFrame == j then
					love.graphics.setColor(1, 0, 0)
					love.graphics.rectangle("fill", frameX, stateY, frameWidth, 16)
				elseif self.hoveredSpriteState == i and self.hoveredSpriteFrame == j then
					love.graphics.setColor(1, 0, 0, 0.5)
					love.graphics.rectangle("fill", frameX, stateY, frameWidth, 16)
				end
				love.graphics.setColor(1, 1, 1)
				love.graphics.print(frameText, frameX, stateY)
				love.graphics.rectangle("line", frameX - 0.5, stateY + 0.5, frameWidth, 16)
			end
		end
	end

	-----------------------------
	-- BOTTOM DETAILS
	-----------------------------

	-----------------------------
	-- BUTTON
	-----------------------------
	self.menuBtn:draw()
end



---Returns the native resolution of the Game Editor, which is always 1280 by 720.
---@return Vector2
function EditorMain:getNativeResolution()
	return self.nativeResolution
end



---Returns the effective sound volume. In the editor, it's always 1.
---@return number
function EditorMain:getEffectiveSoundVolume()
	return 1
end



---Returns the effective music volume. In the editor, it's always 1.
---@return number
function EditorMain:getEffectiveMusicVolume()
	return 1
end



function EditorMain:mousepressed(x, y, button)
	if button == 1 then
		if self.hoveredResource then
			self.selectedResource = self.hoveredResource
			--self.selectedSpriteState = math.min(self.selectedSpriteState, #self.resourceManager:getSprite(self.selectedResource).config.states)
			self.selectedSpriteState = 1
			self.selectedSpriteFrame = 1
		end
		if self.hoveredSpriteState then
			self.selectedSpriteState = self.hoveredSpriteState
			self.selectedSpriteFrame = self.hoveredSpriteFrame or 1
		end
	end
end

function EditorMain:mousereleased(x, y, button)
	-- Buttons
	self.menuBtn:mousereleased(x, y, button)
end

function EditorMain:wheelmoved(x, y)
	if _MousePos.x < 300 then
		self.resourceListOffset = self.resourceListOffset - y * 30
	else
		self.spriteScale = math.min(math.max(self.spriteScale + y, 1), 8)
	end
end

function EditorMain:keypressed(key)
	-- STUB
end

function EditorMain:keyreleased(key)
	-- STUB
end

function EditorMain:textinput(t)
	-- STUB
end



return EditorMain
