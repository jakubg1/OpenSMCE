local class = require "com/class"
local ResourceBank = class:derive("ResourceBank")

local Image = require("src/Essentials/Image")
local Sound = require("src/Essentials/Sound")
local Music = require("src/Essentials/Music")
local Font = require("src/Essentials/Font")
local ColorPalette = require("src/Essentials/ColorPalette")

function ResourceBank:new()
	self.images = {}
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

function ResourceBank:update(dt)
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

function ResourceBank:loadImage(path, frames)
	-- we need sprites to convey images as objects as well, that shouldn't really be a problem because the number of frames is always constant for each given image
	--print("[RB] Loading image: " .. path .. "...")
	local success = pcall(function()
		self.images[path] = Image(parsePath(path), parseVec2(frames))
	end)
	if not success then error("Resource Bank failed to load an image: " .. path) end
end

function ResourceBank:getImage(path)
	if not self.images[path] then error("Resource Bank tried to get an unknown image: " .. path) end
	return self.images[path]
end

function ResourceBank:loadSound(path, loop)
	--print("[RB] Loading sound: " .. path .. "...")
	local success = pcall(function()
		self.sounds[path] = Sound(parsePath(path), loop)
	end)
	if not success then error("Resource Bank failed to load a sound: " .. path) end
end

function ResourceBank:getSound(path)
	if not self.sounds[path] then error("Resource Bank tried to get an unknown sound: " .. path) end
	return self.sounds[path]
end

function ResourceBank:loadMusic(path)
	--print("[RB] Loading music: " .. path .. "...")
	local success = pcall(function()
		self.music[path] = Music(parsePath(path))
	end)
	if not success then error("Resource Bank failed to load a music: " .. path) end
end

function ResourceBank:getMusic(path)
	if not self.music[path] then error("Resource Bank tried to get an unknown music: " .. path) end
	return self.music[path]
end

function ResourceBank:loadParticle(path)
	--print("[RB] Loading particle: " .. path .. "...")
	local success = pcall(function()
		self.particles[path] = loadJson(parsePath(path))
	end)
	if not success then error("Resource Bank failed to load a particle: " .. path) end
end

function ResourceBank:getParticle(path)
	if not self.particles[path] then error("Resource Bank tried to get an unknown particle: " .. path) end
	return self.particles[path]
end

function ResourceBank:loadFont(path)
	--print("[RB] Loading font: " .. path .. "...")
	local success = pcall(function()
		self.fonts[path] = Font(parsePath(path))
	end)
	if not success then error("Resource Bank failed to load a font: " .. path) end
end

function ResourceBank:getFont(path)
	if not self.fonts[path] then error("Resource Bank tried to get an unknown font: " .. path) end
	return self.fonts[path]
end

function ResourceBank:loadColorPalette(path)
	--print("[RB] Loading color palette: " .. path .. "...")
	local success = pcall(function()
		self.colorPalettes[path] = ColorPalette(parsePath(path))
	end)
	if not success then error("Resource Bank failed to load a color palette: " .. path) end
end

function ResourceBank:getColorPalette(path)
	if not self.colorPalettes[path] then error("Resource Bank tried to get an unknown color palette: " .. path) end
	return self.colorPalettes[path]
end



function ResourceBank:loadList(list)
	if list.images then
		for i, data in ipairs(list.images) do self:loadImage(data.path, data.frames) end
	end
	if list.sounds then
		for i, data in ipairs(list.sounds) do self:loadSound(data.path, data.loop) end
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

function ResourceBank:stepLoadList(list)
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

function ResourceBank:stepLoadNext()
	local objectType = nil
	for k, v in pairs(self.stepLoadQueue) do objectType = k; break end -- loading a first object type that it comes
	-- get data
	local data = self.stepLoadQueue[objectType][1]
	--print("[RB] Processing item " .. tostring(self.stepLoadProcessedObjs + 1) .. " from " .. tostring(self.stepLoadTotalObjs) .. "...")
	-- load
	if objectType == "images" then
		self:loadImage(data.path, data.frames)
	elseif objectType == "sounds" then
		self:loadSound(data.path, data.loop)
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



function ResourceBank:unload()
	for musicN, music in pairs(self.music) do
		music:stop()
	end
	for soundN, sound in pairs(self.sounds) do
		sound:stop()
	end
end



return ResourceBank
