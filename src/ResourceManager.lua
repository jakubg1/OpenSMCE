local class = require "com.class"

---Manages all the Game's resources, alongside the ConfigManager. I'm not sure if this split is necessary and how it works.
---@class ResourceManager
---@overload fun():ResourceManager
local ResourceManager = class:derive("ResourceManager")

local Image = require("src.Essentials.Image")
local Sprite = require("src.Essentials.Sprite")
local Sound = require("src.Essentials.Sound")
local SoundEvent = require("src.Essentials.SoundEvent")
local Music = require("src.Essentials.Music")
local Font = require("src.Essentials.Font")
local ColorPalette = require("src.Essentials.ColorPalette")

local UI2AnimationConfig = require("src.Configs.UI2Animation")
local UI2NodeConfig = require("src.Configs.UI2Node")
local UI2SequenceConfig = require("src.Configs.UI2Sequence")



---Constructs a Resource Manager.
function ResourceManager:new()
	self.images = {}
	self.sprites = {}
	self.sounds = {}
	self.soundEvents = {}
	self.music = {}
	-- This holds all raw data from files, excluding "config" and "runtime" files, which are critical and handled directly by the game.
	-- Widgets are excluded from doing so as well, because widgets are loaded only once and don't need to have their source data stored. (this applies only to UI1!)
	self.particles = {}
	self.fonts = {}
	self.colorPalettes = {}

	self.ui2AnimationConfigs = {}
	self.ui2NodeConfigs = {}
	self.ui2SequenceConfigs = {}

	self.resources = {
		image = {t = self.images, c = Image, e = "image"},
		sprite = {t = self.sprites, c = Sprite, e = "sprite"},
		sound = {t = self.sounds, c = Sound, e = "sound"},
		soundEvent = {t = self.soundEvents, c = SoundEvent, e = "sound event"},
		music = {t = self.music, c = Music, e = "music"},
		particle = {t = self.particles, c = _Utils.loadJson, e = "particle"},
		font = {t = self.fonts, c = Font, e = "font"},
		colorPalette = {t = self.colorPalettes, c = ColorPalette, e = "color palette"},

		ui2AnimationConfig = {t = self.ui2AnimationConfigs, c = UI2AnimationConfig, e = "UI2 Animation Config", p = true},
		ui2NodeConfig = {t = self.ui2NodeConfigs, c = UI2NodeConfig, e = "UI2 Node Config", p = true},
		ui2SequenceConfig = {t = self.ui2SequenceConfigs, c = UI2SequenceConfig, e = "UI2 Sequence Config", p = true},
	}

	self.STEP_LOAD_ORDER = {
		"images",
		"sprites",
		"sounds",
		"sound_events",
		"music",
		"particles",
		"fonts",
		"colorPalettes",
		"ui2NodeConfigs",
		"ui2AnimationConfigs",
		"ui2SequenceConfigs"
	}


	-- Step load variables
	self.stepLoading = false
	self.stepLoadQueue = {}
	self.stepLoadTotalObjs = 0
	self.stepLoadProcessedObjs = 0
end



---Updates the Resource Manager. This includes updating sound and music, and also loads a next group of files during the step load process.
---@param dt number Delta time in seconds.
function ResourceManager:update(dt)
	for i, soundEvent in pairs(self.soundEvents) do
		soundEvent:update(dt)
	end
	for i, music in pairs(self.music) do
		music:update(dt)
	end

	if self.stepLoading then
		-- Load as many assets as we can within the span of a few frames
		local stepLoadStart = love.timer.getTime()
		local stepLoadEnd = 0

		while stepLoadEnd < 0.05 do
			self:stepLoadNext()

			stepLoadEnd = stepLoadEnd + (love.timer.getTime() - stepLoadStart)

			-- exit if no more assets to load
			if not self.stepLoading then
				break
			end
		end
	end
end



---Loads an Image from a given path.
---@param path string The resource path.
function ResourceManager:loadImage(path)
	self:loadResource("image", path)
end

---Retrieves an Image by a given path.
---@param path string The resource path.
---@return Image
function ResourceManager:getImage(path)
	return self:getResource("image", path)
end



---Loads a Sprite from a given path.
---@param path string The resource path.
function ResourceManager:loadSprite(path)
	self:loadResource("sprite", path)
end

---Retrieves a Sprite by a given path.
---@param path string The resource path.
---@return Sprite
function ResourceManager:getSprite(path)
	return self:getResource("sprite", path)
end



---Loads a Sound from a given path.
---@param path string The resource path.
function ResourceManager:loadSound(path)
	self:loadResource("sound", path)
end

---Retrieves a Sound by a given path.
---@param path string The resource path.
---@return Sound
function ResourceManager:getSound(path)
	return self:getResource("sound", path)
end



---Loads a Sound Event from a given path.
---@param path string The resource path.
function ResourceManager:loadSoundEvent(path)
	self:loadResource("soundEvent", path)
end

---Retrieves a Sound Event by a given path.
---@param path string The resource path.
---@return SoundEvent
function ResourceManager:getSoundEvent(path)
	return self:getResource("soundEvent", path)
end



---Loads a piece of Music from a given path.
---@param path string The resource path.
function ResourceManager:loadMusic(path)
	self:loadResource("music", path)
end

---Retrieves a piece of Music by a given path.
---@param path string The resource path.
---@return Music
function ResourceManager:getMusic(path)
	return self:getResource("music", path)
end



---Loads Particle from a given path.
---@param path string The resource path.
function ResourceManager:loadParticle(path)
	self:loadResource("particle", path)
end

---Retrieves a Particle by a given path.
---@param path string The resource path.
---@return table
function ResourceManager:getParticle(path)
	return self:getResource("particle", path)
end



---Loads a Font from a given path.
---@param path string The resource path.
function ResourceManager:loadFont(path)
	self:loadResource("font", path)
end

---Retrieves a Font by a given path.
---@param path string The resource path.
---@return Font
function ResourceManager:getFont(path)
	return self:getResource("font", path)
end



---Loads a Color Palette from a given path.
---@param path string The resource path.
function ResourceManager:loadColorPalette(path)
	self:loadResource("colorPalette", path)
end

---Retrieves a Color Palette by a given path.
---@param path string The resource path.
---@return ColorPalette
function ResourceManager:getColorPalette(path)
	return self:getResource("colorPalette", path)
end



---Loads a UI Animation Config from a given path.
---@param path string The resource path.
function ResourceManager:loadUIAnimationConfig(path)
	self:loadResource("ui2AnimationConfig", path)
end

---Retrieves a UI Animation Config by a given path.
---@param path string The resource path.
---@return ColorPalette
function ResourceManager:getUIAnimationConfig(path)
	return self:getResource("ui2AnimationConfig", path)
end



---Loads a UI Node Config from a given path.
---@param path string The resource path.
function ResourceManager:loadUINodeConfig(path)
	self:loadResource("ui2NodeConfig", path)
end

---Retrieves a UI Node Config by a given path.
---@param path string The resource path.
---@return ColorPalette
function ResourceManager:getUINodeConfig(path)
	return self:getResource("ui2NodeConfig", path)
end



---Loads a UI Sequence Config from a given path.
---@param path string The resource path.
function ResourceManager:loadUISequenceConfig(path)
	self:loadResource("ui2SequenceConfig", path)
end

---Retrieves a UI Sequence Config by a given path.
---@param path string The resource path.
---@return ColorPalette
function ResourceManager:getUISequenceConfig(path)
	return self:getResource("ui2SequenceConfig", path)
end



---General function for resource loading. Don't use from outside this class.
---@param type string The resource type. Used to place it in the correct list.
---@param path string A path to the resource.
function ResourceManager:loadResource(type, path)
	local data = self.resources[type]

	--print(string.format("[RB] Loading %s: %s...", data.e, path))
	local success, err = pcall(function()
		if data.p then
			-- TODO: Another set of parameters for config classes. To be sorted out not-so-soon!
			data.t[path] = data.c(_Utils.loadJson(_ParsePath(path)), _ParsePath(path))
		else
			data.t[path] = data.c(_ParsePath(path))
		end
	end)
	if not success then
		_Log:printt("ResourceManager", string.format("FAILED to load %s: %s", data.e, path))
		_Log:printt("ResourceManager", "-> " .. err)
	end
end

---General function for resource getting. Don't use from outside this class.
---@param type string The resource type. Used to retrieve it from the correct list.
---@param path string A path to the resource.
---@return any
function ResourceManager:getResource(type, path)
	local data = self.resources[type]

	if not data.t[path] then
		error(string.format("[ResourceManager] Attempt to get an unknown %s: %s", data.e, path))
	end
	return data.t[path]
end



---Immediately loads all resources from a given list.
---
---The list can contain the following fields: `images`, `sprites`, `sounds`, `sound_events`, `music`, `particles`, `fonts`, `colorPalettes`, `ui2AnimationConfigs`, `ui2NodeConfigs`, `ui2SequenceConfigs` all of which are optional.
---For any of these fields that exists, there's a list of paths which will be loaded.
---@param list table A table described as above.
function ResourceManager:loadList(list)
	for i, path in ipairs(list.images or {}) do self:loadImage(path) end
	for i, path in ipairs(list.sprites or {}) do self:loadSprite(path) end
	for i, path in ipairs(list.sounds or {}) do self:loadSound(path) end
	for i, path in ipairs(list.sound_events or {}) do self:loadSoundEvent(path) end
	for i, path in ipairs(list.music or {}) do self:loadMusic(path) end
	for i, path in ipairs(list.particles or {}) do self:loadParticle(path) end
	for i, path in ipairs(list.fonts or {}) do self:loadFont(path) end
	for i, path in ipairs(list.colorPalettes or {}) do self:loadColorPalette(path) end
	for i, path in ipairs(list.ui2AnimationConfigs or {}) do self:loadUIAnimationConfig(path) end
	for i, path in ipairs(list.ui2NodeConfigs or {}) do self:loadUINodeConfig(path) end
	for i, path in ipairs(list.ui2SequenceConfigs or {}) do self:loadUISequenceConfig(path) end
end



---Queues all resoruces from a given list to be loaded. This means they won't be available immediately, but the game won't lag as hard during the loading process.
---@param list table A table described in `:loadList()`.
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



---Loads a next resource in the queued resource loading process.
function ResourceManager:stepLoadNext()
	local objectType = nil
	-- loading a first object type from order
	for i, v in ipairs(self.STEP_LOAD_ORDER) do
		if self.stepLoadQueue[v] then
			if #self.stepLoadQueue[v] > 0 then
				objectType = v
				break
			else
				-- Remove an already empty list.
				self.stepLoadQueue[v] = nil
			end
		end
	end

	-- get data
	local path = self.stepLoadQueue[objectType][1]
	--print("[RB] Processing item " .. tostring(self.stepLoadProcessedObjs + 1) .. " from " .. tostring(self.stepLoadTotalObjs) .. "...")
	-- load
	if objectType == "images" then
		self:loadImage(path)
	elseif objectType == "sprites" then
		self:loadSprite(path)
	elseif objectType == "sounds" then
		self:loadSound(path)
	elseif objectType == "sound_events" then
		self:loadSoundEvent(path)
	elseif objectType == "music" then
		self:loadMusic(path)
	elseif objectType == "particles" then
		self:loadParticle(path)
	elseif objectType == "fonts" then
		self:loadFont(path)
	elseif objectType == "colorPalettes" then
		self:loadColorPalette(path)
	elseif objectType == "ui2AnimationConfigs" then
		self:loadUIAnimationConfig(path)
	elseif objectType == "ui2NodeConfigs" then
		self:loadUINodeConfig(path)
	elseif objectType == "ui2SequenceConfigs" then
		self:loadUISequenceConfig(path)
	end
	-- remove from the list
	table.remove(self.stepLoadQueue[objectType], 1)
	-- if the type is depleted, remove it
	if #self.stepLoadQueue[objectType] == 0 then self.stepLoadQueue[objectType] = nil end
	self.stepLoadProcessedObjs = self.stepLoadProcessedObjs + 1
	-- end if all resources loaded
	if self.stepLoadProcessedObjs == self.stepLoadTotalObjs then self.stepLoading = false end
end



---Destructor function.
function ResourceManager:unload()
	for musicN, music in pairs(self.music) do
		music:stop()
	end
	for soundEventN, soundEvent in pairs(self.soundEvents) do
		soundEvent:stop()
	end
end



return ResourceManager
