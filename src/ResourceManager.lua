local class = require "com/class"
local ResourceManager = class:derive("ResourceManager")

local Image = require("src/Essentials/Image")
local Sprite = require("src/Essentials/Sprite")
local Sound = require("src/Essentials/Sound")
local Music = require("src/Essentials/Music")
local Font = require("src/Essentials/Font")
local ColorPalette = require("src/Essentials/ColorPalette")

function ResourceManager:new()
	self.images = {}
	self.sprites = {}
	self.sounds = {}
	self.music = {}
	-- This holds all raw data from files, excluding "config" and "runtime" files, which are critical and handled directly by the game.
	-- Widgets are excluded from doing so as well, because widgets are loaded only once and don't need to have their source data stored.
	self.particles = {}
	self.fonts = {}
	self.colorPalettes = {}


	-- Step load variables
	self.stepLoading = false
	self.stepLoadQueue = {}
	self.stepLoadTotalObjs = 0
	self.stepLoadTotalObjsFrac = 0
	self.stepLoadProcessedObjs = 0
	self.STEP_LOAD_FACTOR = 3 -- objects processed per frame; lower values can slow down the loading process significantly, while higher values can lag the progress bar
end

function ResourceManager:update(dt)
	for i, sound in pairs(self.sounds) do
		sound:update(dt)
	end
	for i, music in pairs(self.music) do
		music:update(dt)
	end

	if self.stepLoading then
		self.stepLoadTotalObjsFrac = self.stepLoadTotalObjsFrac + self.STEP_LOAD_FACTOR
		while self.stepLoadTotalObjsFrac >= 1 do
			self:stepLoadNext()
			self.stepLoadTotalObjsFrac = self.stepLoadTotalObjsFrac - 1

			-- exit if no more assets to load
			if not self.stepLoading then break end
		end
	end
end

function ResourceManager:loadImage(path)
	--print("[RB] Loading image: " .. path .. "...")
	local success, err = pcall(function()
		self.images[path] = Image(parsePath(path))
	end)
	if not success then
		print("[ResourceManager] FAILED to load an image: " .. path)
		print("-> " .. err)
	end
end

function ResourceManager:getImage(path)
	if not self.images[path] then error("Resource Bank tried to get an unknown image: " .. path) end
	return self.images[path]
end

function ResourceManager:loadSprite(path)
	--print("[RB] Loading sprite: " .. path .. "...")
	local success, err = pcall(function()
		self.sprites[path] = Sprite(parsePath(path))
	end)
	if not success then
		print("[ResourceManager] FAILED to load a sprite: " .. path)
		print("-> " .. err)
	end
end

function ResourceManager:getSprite(path)
	if not self.sprites[path] then error("Resource Bank tried to get an unknown sprite: " .. path) end
	return self.sprites[path]
end

function ResourceManager:loadSound(path)
	--print("[RB] Loading sound: " .. path .. "...")
	local success, err = pcall(function()
		self.sounds[path] = Sound(parsePath(path))
	end)
	if not success then
		print("[ResourceManager] FAILED to load a sound: " .. path)
		print("-> " .. err)
	end
end

function ResourceManager:getSound(path)
	if not self.sounds[path] then error("Resource Bank tried to get an unknown sound: " .. path) end
	return self.sounds[path]
end

function ResourceManager:loadMusic(path)
	--print("[RB] Loading music: " .. path .. "...")
	local success, err = pcall(function()
		self.music[path] = Music(parsePath(path))
	end)
	if not success then
		print("[ResourceManager] FAILED to load a music: " .. path)
		print("-> " .. err)
	end
end

function ResourceManager:getMusic(path)
	if not self.music[path] then error("Resource Bank tried to get an unknown music: " .. path) end
	return self.music[path]
end

function ResourceManager:loadParticle(path)
	--print("[RB] Loading particle: " .. path .. "...")
	local success, err = pcall(function()
		self.particles[path] = loadJson(parsePath(path))
	end)
	if not success then
		print("[ResourceManager] FAILED to load a particle: " .. path)
		print("-> " .. err)
	end
end

function ResourceManager:getParticle(path)
	if not self.particles[path] then error("Resource Bank tried to get an unknown particle: " .. path) end
	return self.particles[path]
end

function ResourceManager:loadFont(path)
	--print("[RB] Loading font: " .. path .. "...")
	local success, err = pcall(function()
		self.fonts[path] = Font(parsePath(path))
	end)
	if not success then
		print("[ResourceManager] FAILED to load a font: " .. path)
		print("-> " .. err)
	end
end

function ResourceManager:getFont(path)
	if not self.fonts[path] then error("Resource Bank tried to get an unknown font: " .. path) end
	return self.fonts[path]
end

function ResourceManager:loadColorPalette(path)
	--print("[RB] Loading color palette: " .. path .. "...")
	local success, err = pcall(function()
		self.colorPalettes[path] = ColorPalette(parsePath(path))
	end)
	if not success then
		print("[ResourceManager] FAILED to load a color palette: " .. path)
		print("-> " .. err)
	end
end

function ResourceManager:getColorPalette(path)
	if not self.colorPalettes[path] then error("Resource Bank tried to get an unknown color palette: " .. path) end
	return self.colorPalettes[path]
end



function ResourceManager:loadList(list)
	if list.images then
		for i, path in ipairs(list.images) do self:loadImage(path) end
	end
	if list.sprites then
		for i, path in ipairs(list.sprites) do self:loadSprite(path) end
	end
	if list.sounds then
		for i, path in ipairs(list.sounds) do self:loadSound(path) end
	end
	if list.music then
		for i, path in ipairs(list.music) do self:loadMusic(path) end
	end
	if list.particles then
		for i, path in ipairs(list.particles) do self:loadParticle(path) end
	end
	if list.fonts then
		for i, path in ipairs(list.fonts) do self:loadFont(path) end
	end
	if list.colorPalettes then
		for i, path in ipairs(list.colorPalettes) do self:loadColorPalette(path) end
	end
end

function ResourceManager:stepLoadList(list)
	for objectType, objects in pairs(list) do
		-- set up a queue for a particular type if it doesn't exist there
		if not self.stepLoadQueue[objectType] then self.stepLoadQueue[objectType] = {} end
		for j, object in ipairs(objects) do
			-- load an object descriptor(?)
			table.insert(self.stepLoadQueue[objectType], object)
			self.stepLoadTotalObjs = self.stepLoadTotalObjs + 1
		end
	end
	self.stepLoading = true
end

function ResourceManager:stepLoadNext()
	local objectType = nil
	local order = {"images", "sprites", "sounds", "music", "particles", "fonts", "colorPalettes"}
	-- loading a first object type from order
	for i, v in ipairs(order) do
		if self.stepLoadQueue[v] then
			objectType = v
			break
		end
	end
	-- get data
	local data = self.stepLoadQueue[objectType][1]
	--print("[RB] Processing item " .. tostring(self.stepLoadProcessedObjs + 1) .. " from " .. tostring(self.stepLoadTotalObjs) .. "...")
	-- load
	if objectType == "images" then
		self:loadImage(data)
	elseif objectType == "sprites" then
		self:loadSprite(data)
	elseif objectType == "sounds" then
		self:loadSound(data)
	elseif objectType == "music" then
		self:loadMusic(data)
	elseif objectType == "particles" then
		self:loadParticle(data)
	elseif objectType == "fonts" then
		self:loadFont(data)
	elseif objectType == "colorPalettes" then
		self:loadColorPalette(data)
	end
	-- remove from the list
	table.remove(self.stepLoadQueue[objectType], 1)
	-- if the type is depleted, remove it
	if #self.stepLoadQueue[objectType] == 0 then self.stepLoadQueue[objectType] = nil end
	self.stepLoadProcessedObjs = self.stepLoadProcessedObjs + 1
	-- end if all resources loaded
	if self.stepLoadProcessedObjs == self.stepLoadTotalObjs then self.stepLoading = false end
end



function ResourceManager:unload()
	for musicN, music in pairs(self.music) do
		music:stop()
	end
	for soundN, sound in pairs(self.sounds) do
		sound:stop()
	end
end



return ResourceManager
