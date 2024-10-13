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

local ScoreEventConfig = require("src.Configs.ScoreEvent")
local PathEntityConfig = require("src.Configs.PathEntity")
local SphereSelectorConfig = require("src.Configs.SphereSelector")
local DifficultyConfig = require("src.Configs.Difficulty")
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

	-- Values below are used only for newly queued/loaded resources.
	self.currentNamespace = nil
	self.currentBatches = nil

	self.RESOURCE_TYPES = {
		image = {extension = "png", constructor = Image, paramSet = 2},
		sprite = {extension = "json", constructor = Sprite, paramSet = 2},
		sound = {extension = "ogg", constructor = Sound, paramSet = 2},
		soundEvent = {extension = "json", constructor = SoundEvent, paramSet = 2},
		music = {extension = "json", constructor = Music, paramSet = 2},
		particle = {extension = "json", constructor = _Utils.loadJson},
		font = {extension = "json", constructor = Font, paramSet = 2},
		fontFile = {extension = "ttf"},
		colorPalette = {extension = "json", constructor = ColorPalette, paramSet = 2},
		sphere = {extension = "json"},
		sphereEffect = {extension = "json"},
		collectible = {extension = "json"},
		collectibleGenerator = {extension = "json"},
		colorGenerator = {extension = "json"},
		shooter = {extension = "json"},
		scoreEvent = {extension = "json", constructor = ScoreEventConfig, paramSet = 2},
		pathEntity = {extension = "json", constructor = PathEntityConfig, paramSet = 2},
		sphereSelector = {extension = "json", constructor = SphereSelectorConfig, paramSet = 2},
		difficulty = {extension = "json", constructor = DifficultyConfig, paramSet = 2},
		map = {extension = "/"},
		level = {extension = "json"},
		ui2AnimationConfig = {extension = "json", constructor = UI2AnimationConfig, paramSet = 2},
		ui2NodeConfig = {extension = "json", constructor = UI2NodeConfig, paramSet = 2},
		ui2SequenceConfig = {extension = "json", constructor = UI2SequenceConfig, paramSet = 2}
	}
	-- TODO: Auto-generate these two below.
	-- Maybe consider registering the resource types dynamically?
	-- Alongside this, update the table in Resource Management section in the wiki!
	self.SCHEMA_TO_RESOURCE_MAP = {
		["sprite.json"] = "sprite",
		["sound_event.json"] = "soundEvent",
		["music_track.json"] = "music",
		["particle.json"] = "particle",
		["font.json"] = "font",
		["color_palette.json"] = "colorPalette",
		["config/sphere.json"] = "sphere",
		["config/sphere_effect.json"] = "sphereEffect",
		["config/collectible.json"] = "collectible",
		["config/collectible_generator.json"] = "collectibleGenerator",
		["config/color_generator.json"] = "colorGenerator",
		["config/shooter.json"] = "shooter",
		["score_event.json"] = "scoreEvent",
		["path_entity.json"] = "pathEntity",
		["sphere_selector.json"] = "sphereSelector",
		["difficulty.json"] = "difficulty",
		["config/level.json"] = "level",
		["ui2/animation.json"] = "ui2AnimationConfig",
		["ui2/node.json"] = "ui2NodeConfig",
		["ui2/sequence.json"] = "ui2SequenceConfig"
	}
	self.EXTENSION_TO_RESOURCE_MAP = {
		png = "image",
		ogg = "sound",
		mp3 = "sound",
		wav = "sound",
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
	return self:getAsset(path, "image")
end

---Retrieves a Sprite by a given path.
---@param path string The resource path.
---@return Sprite
function ResourceManager:getSprite(path)
	return self:getAsset(path, "sprite")
end

---Retrieves a Sound by a given path.
---@param path string The resource path.
---@return Sound
function ResourceManager:getSound(path)
	return self:getAsset(path, "sound")
end

---Retrieves a Sound Event by a given path.
---@param path string The resource path.
---@return SoundEvent
function ResourceManager:getSoundEvent(path)
	return self:getAsset(path, "sound event")
end

---Retrieves a piece of Music by a given path.
---@param path string The resource path.
---@return Music
function ResourceManager:getMusic(path)
	return self:getAsset(path, "music track")
end

---Retrieves a Particle by a given path.
---@param path string The resource path.
---@return table
function ResourceManager:getParticle(path)
	return self:getAsset(path, "particle")
end

---Retrieves a Font by a given path.
---@param path string The resource path.
---@return Font
function ResourceManager:getFont(path)
	return self:getAsset(path, "font")
end

---Retrieves a Color Palette by a given path.
---@param path string The resource path.
---@return ColorPalette
function ResourceManager:getColorPalette(path)
	return self:getAsset(path, "color palette")
end

---Retrieves a Score Event Config by a given path.
---@param path string The resource path.
---@return ScoreEventConfig
function ResourceManager:getScoreEventConfig(path)
	return self:getAsset(path, "score event")
end

---Retrieves a Path Entity Config by a given path.
---@param path string The resource path.
---@return PathEntityConfig
function ResourceManager:getPathEntityConfig(path)
	return self:getAsset(path, "path entity")
end

---Retrieves a Sphere Selector Config by a given path.
---@param path string The resource path.
---@return SphereSelectorConfig
function ResourceManager:getSphereSelectorConfig(path)
	return self:getAsset(path, "sphere selector")
end

---Retrieves a Difficulty Config by a given path.
---@param path string The resource path.
---@return DifficultyConfig
function ResourceManager:getDifficultyConfig(path)
	return self:getAsset(path, "difficulty")
end

---Retrieves a UI Animation Config by a given path.
---@param path string The resource path.
---@return UI2AnimationConfig
function ResourceManager:getUIAnimationConfig(path)
	return self:getAsset(path, "UI2 animation")
end

---Retrieves a UI Node Config by a given path.
---@param path string The resource path.
---@return UI2NodeConfig
function ResourceManager:getUINodeConfig(path)
	return self:getAsset(path, "UI2 node")
end

---Retrieves a UI Sequence Config by a given path.
---@param path string The resource path.
---@return UI2SequenceConfig
function ResourceManager:getUISequenceConfig(path)
	return self:getAsset(path, "UI2 sequence")
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
function ResourceManager:queueAsset(path)
	local key = self:resolveAssetPath(path, self.currentNamespace)

	if self.resources[key] then
		self:updateAssetBatches(key, self.currentBatches)
	else
		-- Queue the resource to be loaded. Include batches if it has to be loaded with them.
		table.insert(self.queuedResources, {key = key, batches = self.currentBatches})
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
---@param type string? If specified, this will be the resource type in an error message if this resource is not found.
---@return any
function ResourceManager:getAsset(path, type)
	local key = self:resolveAssetPath(path, self.currentNamespace)

	if self.resources[key] then
		self:updateAssetBatches(key, self.currentBatches)
	else
		-- Remove the asset from the queue if already queued - we're doing it for the queue.
		for i, k in ipairs(self.queuedResources) do
			if k == key then
				table.remove(self.queuedResources, i)
				break
			end
		end
		self:loadAsset(key, self.currentBatches)
	end
	if not self.resources[key] then
		error(string.format("[ResourceManager] Attempt to get a nonexistent %s: %s", type or "resource", path))
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
	local constructor = self.RESOURCE_TYPES[type].constructor
	if not constructor then
		_Log:printt("ResourceManager2", "File " .. key .. " not loaded: type " .. type .. " not implemented")
		return
	end

	-- Copy the batch array so that no resource uses the same exact instance of a batch list.
	local newBatches = nil
	if batches then
		newBatches = {}
		for i, batch in ipairs(batches) do
			table.insert(newBatches, batch)
		end
	end
	-- TODO: Condensate the parameter set to the one used by Config Classes.
	if self.RESOURCE_TYPES[type].paramSet == 2 then
		self.resources[key] = {asset = constructor(contents, key), type = type, batches = newBatches}
	else
		self.resources[key] = {asset = constructor(_ParsePath(key)), type = type, batches = newBatches}
	end
	_Log:printt("ResourceManager2", key .. (newBatches and (" {" .. table.concat(newBatches, ", ") .. "}") or "") .. " OK!")
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



---Sets the current namespace for the Resource Manager.
---When called, all subsequent resources loaded by `:getAsset*()` and `:queueAsset()` will use this namespace as default
---when the path specified starts with a colon, e.g. `":flame1.json"`.
---If `nil` is specified (or called without arguments), the current namespace is reset, and any attempt to load a resource with a path
---starting with a colon will crash the game.
---@param namespace string? The default namespace for subsequently queued and loaded resources.
function ResourceManager:setNamespace(namespace)
	self.currentNamespace = namespace
end



---Sets the current batches for the Resource Manager.
--- - If a table of strings is passed as an argument, these strings will be batch names under which all the subsequently loaded
---   and queued resources (by `:getAsset*()` and `:queueAsset()`) will be loaded as a part of. Unloading *all* of these
---   batches by calling `:unloadAssetBatch()` will cause the resource to be unloaded from memory.
--- - If `nil` is specified (or the function is called without arguments), all subsequently loaded resources will be loaded permanently.
---@param batches table? A table of strings, each of which is a resource batch identifier.
function ResourceManager:setBatches(batches)
	self.currentBatches = batches
end



---Unloads an asset batch by removing it from all loaded resources, if applicable.
---For any Resource, if it had only that batch assigned, the resource is removed from memory.
---@param name string The asset batch name to be unloaded.
function ResourceManager:unloadAssetBatch(name)
	for key, resource in pairs(self.resources) do
		if resource.batches then
			for i, batch in ipairs(resource.batches) do
				if batch == name then
					table.remove(resource.batches, i)
					if #resource.batches == 0 then
						self.resources[key] = nil
						_Log:printt("ResourceManager2", key .. " unloaded!")
					end
					break
				end
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
