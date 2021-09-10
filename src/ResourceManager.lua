local class = require "com/class"
local ResourceManager = class:derive("ResourceManager")

local Image = require("src/Essentials/Image")
local Sprite = require("src/Essentials/Sprite")
local Sound = require("src/Essentials/Sound")
local SoundEvent = require("src/Essentials/SoundEvent")
local Music = require("src/Essentials/Music")
local Font = require("src/Essentials/Font")
local ColorPalette = require("src/Essentials/ColorPalette")

function ResourceManager:new()
	self.images = {}
	self.sprites = {}
	self.sounds = {}
	self.soundEvents = {}
	self.music = {}
	-- This holds all raw data from files, excluding "config" and "runtime" files, which are critical and handled directly by the game.
	-- Widgets are excluded from doing so as well, because widgets are loaded only once and don't need to have their source data stored.
	self.particles = {}
	self.fonts = {}
	self.colorPalettes = {}

	self.resources = {
		image = {t = self.images, c = Image, e = "image"},
		sprite = {t = self.sprites, c = Sprite, e = "sprite"},
		sound = {t = self.sounds, c = Sound, e = "sound"},
		soundEvent = {t = self.soundEvents, c = SoundEvent, e = "sound event"},
		music = {t = self.music, c = Music, e = "music"},
		particle = {t = self.particles, c = loadJson, e = "particle"},
		font = {t = self.fonts, c = Font, e = "font"},
		colorPalette = {t = self.colorPalettes, c = ColorPalette, e = "color palette"},
	}


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
	self:loadResource("image", path)
end

function ResourceManager:getImage(path)
	return self:getResource("image", path)
end

function ResourceManager:loadSprite(path)
	self:loadResource("sprite", path)
end

function ResourceManager:getSprite(path)
	return self:getResource("sprite", path)
end

function ResourceManager:loadSound(path)
	self:loadResource("sound", path)
end

function ResourceManager:getSound(path)
	return self:getResource("sound", path)
end

function ResourceManager:loadSoundEvent(path)
	self:loadResource("soundEvent", path)
end

function ResourceManager:getSoundEvent(path)
	return self:getResource("soundEvent", path)
end

function ResourceManager:loadMusic(path)
	self:loadResource("music", path)
end

function ResourceManager:getMusic(path)
	return self:getResource("music", path)
end

function ResourceManager:loadParticle(path)
	self:loadResource("particle", path)
end

function ResourceManager:getParticle(path)
	return self:getResource("particle", path)
end

function ResourceManager:loadFont(path)
	self:loadResource("font", path)
end

function ResourceManager:getFont(path)
	return self:getResource("font", path)
end

function ResourceManager:loadColorPalette(path)
	self:loadResource("colorPalette", path)
end

function ResourceManager:getColorPalette(path)
	return self:getResource("colorPalette", path)
end



function ResourceManager:loadResource(type, path)
	local data = self.resources[type]

	--print(string.format("[RB] Loading %s: %s...", data.e, path))
	local success, err = pcall(function()
		data.t[path] = data.c(parsePath(path))
	end)
	if not success then
		print(string.format("[ResourceManager] FAILED to load %s: %s", data.e, path))
		print("-> " .. err)
	end
end

function ResourceManager:getResource(type, path)
	local data = self.resources[type]

	if not data.t[path] then
		error(string.format("[ResourceManager] Attempt to get an unknown %s: %s", data.e, path))
	end
	return data.t[path]
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
	if list.sound_events then
		for i, path in ipairs(list.sound_events) do self:loadSoundEvent(path) end
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
	local order = {"images", "sprites", "sounds", "sound_events", "music", "particles", "fonts", "colorPalettes"}
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
	elseif objectType == "sound_events" then
		self:loadSoundEvent(data)
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
