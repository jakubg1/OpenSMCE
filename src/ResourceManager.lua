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
	-- Resources are stored as the following objects:
	-- `{type = "image", asset = <love2d image>, batches = {"map2"}}`
	-- - `type` is one of the `RESOURCE_TYPES` below. It's `nil` when the resource is queued, but that's not a guarantee.
	-- - `asset` holds the resource itself, if it's `nil` then the resource is just queued for loading and it's not loaded yet
	-- - `batches` is a list of resource batches this resource was loaded as, once all of them are unloaded, this entry is deleted; can be `nil` to omit that feature for global resources
	--
	-- Keys are absolute paths starting from the root game directory. Use `ResourceManager:resolvePath()` to obtain a key to this table from stuff like `:flame.json`.
	self.resources = {}
	-- Just names of the queued resources, used to preserve the loading order.
	self.queuedResources = {}

	self.RESOURCE_TYPES = {
		image = {directory = "images", extension = "png", constructor = Image},
		sprite = {directory = "sprites", extension = "json", constructor = Sprite},
		audio = {directory = "audio", extension = "ogg", constructor = Sound}, -- Figure out how to make a distinction between static and streamed files, and support more extensions
		soundEvent = {directory = "sound_events", extension = "json", constructor = SoundEvent},
		music = {directory = "music", extension = "json", constructor = Music}, -- Merge sounds and music into audio files (audio) and make music configurable
		particle = {directory = "particles", extension = "json", constructor = _Utils.loadJson},
		font = {directory = "fonts", extension = "json", constructor = Font},
		fontFile = {directory = "font_files", extension = "ttf"},
		colorPalette = {directory = "color_palettes", extension = "json", constructor = ColorPalette},
		sphere = {directory = "config/spheres", extension = "json"},
		sphereEffect = {directory = "config/sphere_effects", extension = "json"},
		collectible = {directory = "config/collectibles", extension = "json"},
		collectibleGenerator = {directory = "config/collectible_generators", extension = "json"},
		colorGenerator = {directory = "config/color_generators", extension = "json"},
		shooter = {directory = "config/shooters", extension = "json"},
		map = {directory = "maps", extension = "/"},
		level = {directory = "config/levels", extension = "json"},
		ui2AnimationConfig = {directory = "ui2/animations", extension = "json", constructor = UI2AnimationConfig, paramSet = 2},
		ui2NodeConfig = {directory = "ui2/layouts", extension = "json", constructor = UI2NodeConfig, paramSet = 2},
		ui2SequenceConfig = {directory = "ui2/sequences", extension = "json", constructor = UI2SequenceConfig, paramSet = 2}
	}
	-- TODO: Auto-generate these two below.
	self.SCHEMA_TO_RESOURCE_MAP = {
		["sprite.json"] = "sprite",
		["sound_event.json"] = "soundEvent",
		-- TODO: music
		["particle.json"] = "particle",
		["font.json"] = "font",
		["color_palette.json"] = "colorPalette",
		["config/sphere.json"] = "sphere",
		["config/sphere_effect.json"] = "sphereEffect",
		["config/collectible.json"] = "collectible",
		["config/collectible_generator.json"] = "collectibleGenerator",
		["config/color_generator.json"] = "colorGenerator",
		["config/shooter.json"] = "shooter",
		["config/level.json"] = "level",
		["ui2/animation.json"] = "ui2AnimationConfig",
		["ui2/node.json"] = "ui2NodeConfig",
		["ui2/sequence.json"] = "ui2SequenceConfig"
	}
	self.EXTENSION_TO_RESOURCE_MAP = {
		png = "image",
		ogg = "audio",
		ttf = "fontFile"
	}

	-- Load counters allow tracking the progress of loading a chosen set of resources.
	self.loadCounters = {}
end



---Updates the Resource Manager. This includes updating sound and music, and also loads a next group of files during the step load process.
---@param dt number Delta time in seconds.
function ResourceManager:update(dt)
	-- Update volumes globally.
	-- TODO: This is not the place to do it!
	for key, resource in pairs(self.resources) do
		if resource.asset.update then
			resource.asset:update(dt)
		end
	end

	-- Load as many assets as we can within the span of a few frames
	local stepLoadStart = love.timer.getTime()
	local stepLoadEnd = 0
	while #self.queuedResources > 0 and stepLoadEnd < 0.05 do
		-- Load the next resource from the queue.
		local data = self.queuedResources[1]
		self:loadAsset(data.key, data.batches)
		table.remove(self.queuedResources, 1)
		-- Update the timer. This will allow the loop to exit.
		stepLoadEnd = stepLoadEnd + (love.timer.getTime() - stepLoadStart)
	end
end



---Retrieves an Image by a given path.
---@param path string The resource path.
---@return Image
function ResourceManager:getImage(path)
	return self:getAsset(path)
end

---Retrieves a Sprite by a given path.
---@param path string The resource path.
---@return Sprite
function ResourceManager:getSprite(path)
	return self:getAsset(path)
end

---Retrieves a Sound by a given path.
---@param path string The resource path.
---@return Sound
function ResourceManager:getSound(path)
	return self:getAsset(path)
end

---Retrieves a Sound Event by a given path.
---@param path string The resource path.
---@return SoundEvent
function ResourceManager:getSoundEvent(path)
	return self:getAsset(path)
end

---Retrieves a piece of Music by a given path.
---@param path string The resource path.
---@return Music
function ResourceManager:getMusic(path)
	return self:getAsset(path)
end

---Retrieves a Particle by a given path.
---@param path string The resource path.
---@return table
function ResourceManager:getParticle(path)
	return self:getAsset(path)
end

---Retrieves a Font by a given path.
---@param path string The resource path.
---@return Font
function ResourceManager:getFont(path)
	return self:getAsset(path)
end

---Retrieves a Color Palette by a given path.
---@param path string The resource path.
---@return ColorPalette
function ResourceManager:getColorPalette(path)
	return self:getAsset(path)
end

---Retrieves a UI Animation Config by a given path.
---@param path string The resource path.
---@return UI2AnimationConfig
function ResourceManager:getUIAnimationConfig(path)
	return self:getAsset(path)
end

---Retrieves a UI Node Config by a given path.
---@param path string The resource path.
---@return UI2NodeConfig
function ResourceManager:getUINodeConfig(path)
	return self:getAsset(path)
end

---Retrieves a UI Sequence Config by a given path.
---@param path string The resource path.
---@return UI2SequenceConfig
function ResourceManager:getUISequenceConfig(path)
	return self:getAsset(path)
end



---Destructor function.
---TODO: Stop all sounds and music elsewhere. This is not the place to do it!
function ResourceManager:unload()
	for key, resource in pairs(self.resources) do
		if resource.asset.stop then
			resource.asset:stop()
		end
	end
end



---Resolves and returns the entire asset path starting from the root game folder, based on the asset type.
---This is the key under which that resource would be stored.
--- - For example, providing `sprites/balls/2.json` as path will return `sprites/balls/2.json`.
--- - The colon `:` references a namespace - currently, a map folder, but this behavior may be extended in the future.
---   - For example, providing `Map1:flame.json` as path will return `maps/Map1/flame.json`.
--- - Starting the path with a colon (without referencing a namespace) will use the `namespace` parameter as the namespace name.
---   - For example, providing `:flame.json` as path and `Map3` as namespace will return `maps/Map3/flame.json`.
---   - This is used to shorten paths referenced from within the current namespace.
---@param path string The path to be resolved.
---@param namespace string? The default map namespace to be prepended when referenced.
---@return string
function ResourceManager:resolveAssetPath(path, namespace)
	local splitPath = _Utils.strSplit(path, ":")
	if #splitPath == 1 then
		return path
	else
		if splitPath[1] == "" then
			splitPath[1] = namespace
		end
		return string.format("maps/%s/%s", splitPath[1], splitPath[2])
	end
end



---Queues a resource to be loaded soon, if not loaded yet. If many calls to this function are done in a quick succession, the load order will be preserved.
---@param path string The path to the resource.
---@param namespace string? The default namespace. See `ResourceManager:resolveAssetPath()` for more information.
---@param batches table? Table of strings. The batches this resource should be loaded with.
--- - If not specified, this resource will stay permanently loaded, even if the resource has been already loaded as a part of a batch.
--- - If specified:
---   - If this resource hasn't been already loaded, this resource will have only these batches assigned.
---   - If this resource has been already loaded, these batches will be added to the batches previously specified, assuming it has not been permanently loaded.
--- - Remember that unloading all batches assigned to any resource will unload that resource from memory.
function ResourceManager:queueAsset(path, namespace, batches)
	local key = self:resolveAssetPath(path, namespace)

	if self.resources[key] then
		self:updateAssetBatches(key, batches)
	else
		-- Queue the resource to be loaded. Include batches if it has to be loaded with them.
		table.insert(self.queuedResources, {key = key, batches = batches})
		-- Mark the resource as tracked by any load counters.
		for name, loadCounter in pairs(self.loadCounters) do
			if loadCounter.active then
				loadCounter.queued = loadCounter.queued + 1
				loadCounter.queueKeys[key] = true
			end
		end
	end
end



---Retrieves an asset by its path and namespace. If the resource is not yet loaded, it is immediately loaded.
---Internal use only; use other `get*` functions for type support.
---@param path string The path to the resource.
---@param namespace string? If specified, this will be used to resolve the default namespace. See `ResourceManager:resolveAssetPath()` for more information.
---@param batches table? If specified, the resource will be obtained as a part of a specific batch. Unless that batch is unloaded, this resource is guaranteed to stay loaded.
---@return any
function ResourceManager:getAsset(path, namespace, batches)
	local key = self:resolveAssetPath(path, namespace)

	if self.resources[key] then
		self:updateAssetBatches(key, batches)
	else
		-- Remove the asset from the queue if already queued - we're doing it for the queue.
		for i, k in ipairs(self.queuedResources) do
			if k == key then
				table.remove(self.queuedResources, i)
				break
			end
		end
		self:loadAsset(key, batches)
	end
	if not self.resources[key] then
		error(string.format("[ResourceManager] Resource not found: %s", path))
	end
	return self.resources[key].asset
end



---Loads the asset: opens the file, deduces its type, and if applicable, constructs a resource and registers it in the resource table.
---Internal use only; don't call from outside of the class!
---@param key string The key to the resource: a full path starting from the root game folder.
---@param batches table? If present, this will be the list of resource batches this resource is going to be a part of. Otherwise, this resource will stay loaded permanently.
function ResourceManager:loadAsset(key, batches)
	-- Mark the resource as loaded by load counters. We are doing it here so everything counts.
	for name, loadCounter in pairs(self.loadCounters) do
		if loadCounter.queueKeys[key] then
			loadCounter.loaded = loadCounter.loaded + 1
			loadCounter.queueKeys[key] = nil
		end
	end

	-- Treat the file differently depending on whether it's a JSON file or not, and check the type.
	local type = nil
	local contents = nil
	if _Utils.strEndsWith(key, ".json") then
		contents = _Utils.loadJson(_ParsePath(key))
		local schema = contents["$schema"]
		if schema then
			schema = _Utils.strSplit(schema, "/schemas/")
			schema = schema[2] or schema[1]
		end
		type = schema and self.SCHEMA_TO_RESOURCE_MAP[schema]
	else
		local extension = _Utils.strSplit(key, ".")
		extension = extension[#extension]
		type = extension and self.EXTENSION_TO_RESOURCE_MAP[extension]
	end

	-- If no valid resource type has been found, discard the resource.
	if not type then
		_Log:printt("ResourceManager2", "LOUD WARNING: File " .. key .. " ignored")
		return
	end

	-- Get the constructor and construct the asset.
	if _Utils.strStartsWith(key, "music/") then
		type = "music"
	end
	local constructor = self.RESOURCE_TYPES[type].constructor
	if not constructor then
		_Log:printt("ResourceManager2", "File " .. key .. " not loaded: type " .. type .. " not implemented")
		return
	end
	-- TODO: Condensate the parameter set to the one used by Config Classes.
	if self.RESOURCE_TYPES[type].paramSet == 2 then
		self.resources[key] = {asset = constructor(contents, key), type = type, batches = batches}
	else
		self.resources[key] = {asset = constructor(_ParsePath(key)), type = type, batches = batches}
	end
	_Log:printt("ResourceManager2", key .. " OK!")
end



---Updates the assigned asset batches for a given resource by adding a list of batches.
---Internal use only; don't call from outside of the class!
---@param key string The resource to be updated.
---@param batches table? A list of batches to be added. If not specified, the resource will be marked as permanently loaded.
function ResourceManager:updateAssetBatches(key, batches)
	local resource = self.resources[key]

	-- If either the resource is already permanently loaded, or we call it to be permanently loaded, let it be permanently loaded.
	if not batches then
		resource.batches = nil
		return
	end
	-- Otherwise, we merge two batch lists together.
	if batches and resource.batches then
		for i, batch in ipairs(batches) do
			if not _Utils.isValueInTable(resource.batches, batch) then
				table.insert(resource.batches, batch)
			end
		end
	end
end



---Scans the game folder for all resources and queues them for loading.
---Resources in folders: `maps`, `config` as well as all files located directly in the root game directory will be omitted.
function ResourceManager:scanResources()
	-- Get all files in the game directory.
	local files = _Utils.getDirListing(_ParsePath("/"), "file", nil, true)
	-- Sift through the files, save the files we're interested with in the table.
	for i, file in ipairs(files) do
		if not _Utils.strStartsWith(file, "maps/") and not _Utils.strStartsWith(file, "config/") and #_Utils.strSplit(file, "/") > 1 then
			self:queueAsset(file)
		end
	end
end



---Starts a load counter with a particular name. Load counters can be used to implement progress bars.
---From now on, any queued resources will be counted towards the total and the progress will increase as they are loaded.
---After all resources of interest are queued, call `ResourceManager:stopLoadCounter()`.
---
---If there was a load counter with this name already created, it is overwritten.
---@param name string The name of a load counter to be created. Multiple load counters can be active at once.
function ResourceManager:startLoadCounter(name)
	self.loadCounters[name] = {queued = 0, loaded = 0, active = true, queueKeys = {}}
end

---Stops the load counter from counting any more queued resources.
---As the queued resources are loaded, the load counter's progress will increase.
---@param name string The name of a load counter to be deactivated.
function ResourceManager:stopLoadCounter(name)
	self.loadCounters[name].active = false
end

---Returns a fraction from 0 to 1, both inclusive, as a progress of loading the resources for this load counter.
---If the load counter doesn't exist yet, 0 is returned.
---@param name string The name of a load counter to be checked.
---@return number
function ResourceManager:getLoadProgress(name)
	if not self.loadCounters[name] then
		return 0
	end
	return self.loadCounters[name].loaded / self.loadCounters[name].queued
end



return ResourceManager
