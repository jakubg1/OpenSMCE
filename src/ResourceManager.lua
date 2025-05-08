local class = require "com.class"

---Manages all the Game's resources, alongside the ConfigManager. I'm not sure if this split is necessary and how it works.
---@class ResourceManager
---@overload fun():ResourceManager
local ResourceManager = class:derive("ResourceManager")

local Image = require("src.Essentials.Image")
local Sprite = require("src.Essentials.Sprite")
local SpriteAtlas = require("src.Essentials.SpriteAtlas")
local Sound = require("src.Essentials.Sound")
local SoundEvent = require("src.Essentials.SoundEvent")
local Music = require("src.Essentials.Music")
local Font = require("src.Essentials.Font")
local ColorPalette = require("src.Essentials.ColorPalette")



---Constructs a Resource Manager.
function ResourceManager:new()
	-- Resources are stored as the following objects:
	-- `{type = "sprite", config = <SpriteConfig instance>, asset = <Sprite instance>, batches = {"map2"}}`
	-- - `type` is one of the `RESOURCE_TYPES` below.
	-- - `config` holds the resource config. Optional.
	-- - `asset` holds the resource itself. Optional, only if the resources are singletons and are not creatable from elsewhere (like Sprites, Sprite Atlases, Music etc.).
	-- - `batches` is a list of resource batches this resource was loaded as, once all of them are unloaded, this entry is deleted; can be `nil` to omit that feature for global resources
	---@alias Resource {type: string, config: any?, asset: any?, batches: string[]?}
	--
	-- Keys are absolute paths starting from the root game directory. Use `:resolvePath()` to obtain a key to this table from stuff like `":flame.json"`.
	-- If a resource is queued but not loaded, its entry will not exist at all.
	---@type Resource[]
	self.resources = {}
	-- A list of keys of the queued resources alongside their batches. Used to preserve the loading order.
	---@type {key: string, batches: string[]}[]
	self.queuedResources = {}

	-- Values below are used only for newly queued/loaded resources.
	self.currentNamespace = nil
	self.currentBatches = nil

	self.RESOURCE_TYPE_LOCATION = "src/Configs"

	self.RESOURCE_TYPES = {
		image = {assetConstructor = Image},
		sound = {assetConstructor = Sound},
		fontFile = {},

		soundEvent = {assetConstructor = SoundEvent},
		music = {assetConstructor = Music},
		particle = {assetConstructor = _Utils.loadJson},
		font = {assetConstructor = Font},
		colorPalette = {assetConstructor = ColorPalette},
		colorGenerator = {},
		level = {}
	}

	-- TODO: Auto-generate these two below.
	-- Maybe consider registering the resource types dynamically?
	-- Alongside this, update the table in Resource Management section in the wiki!
	self.SCHEMA_TO_RESOURCE_MAP = {
		["sound_event.json"] = "soundEvent",
		["music_track.json"] = "music",
		["particle.json"] = "particle",
		["font.json"] = "font",
		["color_palette.json"] = "colorPalette",
		["config/color_generator.json"] = "colorGenerator",
		["config/level.json"] = "level"
	}
	self.EXTENSION_TO_RESOURCE_MAP = {
		png = "image",
		ogg = "sound",
		mp3 = "sound",
		wav = "sound",
		ttf = "fontFile"
	}

	-- Register the resource types and config constructors.
	self:registerResourceTypes(self.RESOURCE_TYPE_LOCATION)

	-- Register the singleton/asset constructors.
	self.SINGLETON_LIST = {
		Sprite = Sprite,
		SpriteAtlas = SpriteAtlas
	}
	self:registerResourceSingletons(self.SINGLETON_LIST)

	-- Load counters allow tracking the progress of loading a chosen set of resources.
	self.loadCounters = {}
end



---Updates the Resource Manager. This includes updating sound and music, and also loads a next group of files during the step load process.
---@param dt number Delta time in seconds.
function ResourceManager:update(dt)
	-- Update volumes globally.
	-- TODO: This is not the place to do it!
	for key, resource in pairs(self.resources) do
		if resource.asset and resource.asset.update then
			resource.asset:update(dt)
		end
	end

	-- Load as many resources as we can within the span of a few frames
	local stepLoadStart = love.timer.getTime()
	local stepLoadEnd = 0
	while #self.queuedResources > 0 and stepLoadEnd < 0.05 do
		-- Load the next resource from the queue.
		local data = self.queuedResources[1]
		self:loadResource(data.key, data.batches)
		-- Update the timer. This will allow the loop to exit.
		stepLoadEnd = stepLoadEnd + (love.timer.getTime() - stepLoadStart)
	end
end



---Goes through all `.lua` files in the provided source code directory and for each eligible one:
--- - Registers a resource type by adding an entry to `self.RESOURCE_TYPES` with a Config Class constructor.
--- - Registers a schema association, which is used to determine what kind of any resource file is.
---   - This association is based on the metadata included in the config class file.
--- - Injects a `:get*Config()` function to the ResourceManager class using the Config Class' `.inject()` function.
---@param dir string The base directory to look for resource types.
function ResourceManager:registerResourceTypes(dir)
	local names = _Utils.getDirListing(dir, "file", ".lua")
	for i, name in ipairs(names) do
		name = _Utils.pathStripExtension(name)
		local resourceClass = require(dir .. "/" .. name)
		if resourceClass.metadata and resourceClass.inject then
			print("Valid resource class: " .. name)
			self.SCHEMA_TO_RESOURCE_MAP[resourceClass.metadata.schemaPath] = name
			resourceClass.inject(ResourceManager)
			self.RESOURCE_TYPES[name] = {constructor = resourceClass}
		end
	end
end



---For each provided resource type in the list:
--- - Registers a singleton constructor and stores it in the `self.RESOURCE_TYPES[].assetConstructor` field.
--- - Injects a `:get*()` function to the ResourceManager using the singleton class' `.inject()` function.
---Provided resource types must be already registered with `:registerResourceTypes()`.
---@param singletons {string: any} Keys are resource names, values are classes corresponding to that resource's singleton class.
function ResourceManager:registerResourceSingletons(singletons)
	for name, singletonClass in pairs(singletons) do
		singletonClass.inject(ResourceManager)
		self.RESOURCE_TYPES[name].assetConstructor = singletonClass
	end
end



---Retrieves an Image by a given path.
---@param path string The resource path.
---@return Image
function ResourceManager:getImage(path)
	return self:getResourceAsset(path, "image")
end

---Retrieves a Sound by a given path.
---@param path string The resource path.
---@return Sound
function ResourceManager:getSound(path)
	return self:getResourceAsset(path, "sound")
end

---Retrieves a Sound Event by a given path.
---@param path string The resource path.
---@return SoundEvent
function ResourceManager:getSoundEvent(path)
	return self:getResourceAsset(path, "sound event")
end

---Retrieves a piece of Music by a given path.
---@param path string The resource path.
---@return Music
function ResourceManager:getMusic(path)
	return self:getResourceAsset(path, "music track")
end

---Retrieves a Particle by a given path.
---@param path string The resource path.
---@return table
function ResourceManager:getParticle(path)
	return self:getResourceAsset(path, "particle")
end

---Retrieves a Font by a given path.
---@param path string The resource path.
---@return Font
function ResourceManager:getFont(path)
	return self:getResourceAsset(path, "font")
end

---Retrieves a Color Palette by a given path.
---@param path string The resource path.
---@return ColorPalette
function ResourceManager:getColorPalette(path)
	return self:getResourceAsset(path, "color palette")
end



---Destructor function.
---TODO: Stop all sounds and music elsewhere. This is not the place to do it!
function ResourceManager:unload()
	for key, resource in pairs(self.resources) do
		if resource.asset and resource.asset.stop then
			resource.asset:stop()
		end
	end
end



---Resolves and returns the entire resource path starting from the root game folder, based on the resource type.
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
function ResourceManager:resolveResourcePath(path, namespace)
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



---Queues a resource to be loaded soon, if not loaded yet.
---If many calls to this function are done in a quick succession, the load order will be preserved.
---@param path string The path to the resource.
function ResourceManager:queueResource(path)
	local key = self:resolveResourcePath(path, self.currentNamespace)

	if self.resources[key] then
		self:updateResourceBatches(key, self.currentBatches)
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



---Returns `true` if any resource at the provided path exists, `false` otherwise.
---This function attempts to load the resource, so it will be loaded if the resource exists but was not loaded yet.
---@param path string The path to the resource.
---@return boolean
function ResourceManager:doesResourceExist(path)
	local key = self:resolveResourcePath(path, self.currentNamespace)
	if self.resources[key] then
		return true
	end
	pcall(function() self:loadResource(key, self.currentBatches) end)
	return self.resources[key] ~= nil
end



---Retrieves the resource entry by its path and namespace. If the resource is not yet loaded, it is immediately loaded.
---Internal use only; use other `get*` functions for type support.
---@private
---@param path string The path to the resource.
---@param type string? If specified, this will be the resource type in an error message if this resource is not found.
---@return Resource
function ResourceManager:getResource(path, type)
	local key = self:resolveResourcePath(path, self.currentNamespace)
	if self.resources[key] then
		self:updateResourceBatches(key, self.currentBatches)
	else
		self:loadResource(key, self.currentBatches)
	end
	if not self.resources[key] then
		error(string.format("[ResourceManager] Attempt to get a nonexistent %s: %s", type or "resource", path))
	end
	return self.resources[key]
end



---Retrieves the resource asset by its path and namespace. If the resource is not yet loaded, it is immediately loaded.
---Internal use only; use other `get*` functions for type support.
---@private
---@param path string The path to the resource.
---@param type string? If specified, this will be the resource type in an error message if this resource is not found.
---@return any
function ResourceManager:getResourceAsset(path, type)
	return self:getResource(path, type).asset
end



---Retrieves the resource config by its path and namespace. If the resource is not yet loaded, it is immediately loaded.
---Internal use only; use other `get*` functions for type support.
---@private
---@param path string The path to the resource.
---@param type string? If specified, this will be the resource type in an error message if this resource is not found.
---@return any
function ResourceManager:getResourceConfig(path, type)
	return self:getResource(path, type).config
end



---Loads the resource (config and/or asset): opens the file, deduces its type, and if applicable, constructs a resource and registers it in the resource table.
---If the resource cannot be loaded or has been already loaded, this function throws an error.
---@private
---@param key string The key to the resource: a full path starting from the root game folder.
---@param batches string[]? If present, this will be the list of resource batches this resource is going to be a part of. Otherwise, this resource will stay loaded permanently.
function ResourceManager:loadResource(key, batches)
	-- Remove the resource from the queue if this resource was queued.
	for i, k in ipairs(self.queuedResources) do
		if k.key == key then
			table.remove(self.queuedResources, i)
			break
		end
	end

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

	-- Get the constructor and construct the resources.
	local constructor = self.RESOURCE_TYPES[type].constructor
	local assetConstructor = self.RESOURCE_TYPES[type].assetConstructor
	if not constructor and not assetConstructor then
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

	-- Prevent overwriting the resource. That's a no.
	if self.resources[key] then
		error(string.format("Tried to load a resource twice: %s", key))
	end

	self.resources[key] = {type = type, batches = newBatches}

	if constructor then
		-- Construct the resource and check for errors.
		local success, result = xpcall(function() return constructor(contents, key) end, debug.traceback)
		assert(success, string.format("Failed to load file %s: %s", key, result))
		self.resources[key].config = result
	end

	if assetConstructor then
		-- TODO: Condensate the parameter set to the one used by Config Classes.
		if assetConstructor ~= _Utils.loadJson then
			-- Construct the resource and check for errors.
			local success, result = xpcall(function() return assetConstructor(self.resources[key].config or contents, key) end, debug.traceback)
			assert(success, string.format("Failed to load file %s: %s", key, result))
			self.resources[key].asset = result
		else
			self.resources[key].asset = assetConstructor(_ParsePath(key))
		end
	end
	_Log:printt("ResourceManager2", key .. " (" .. type .. ")" .. (newBatches and (" {" .. table.concat(newBatches, ", ") .. "}") or "") .. " OK!")
end



---Updates the assigned resource batches for a given resource by adding a list of batches.
---@private
---@param key string The resource to be updated.
---@param batches string[]? A list of batches to be added. If not specified, the resource will be marked as permanently loaded.
function ResourceManager:updateResourceBatches(key, batches)
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
---When called, all subsequent resources loaded by `:getResource*()` and `:queueResource()` will use this namespace as default
---when the path specified starts with a colon, e.g. `":flame1.json"`.
---If `nil` is specified (or called without arguments), the current namespace is reset, and any attempt to load a resource with a path
---starting with a colon will crash the game.
---@param namespace string? The default namespace for subsequently queued and loaded resources.
function ResourceManager:setNamespace(namespace)
	self.currentNamespace = namespace
end



---Sets the current batches for the Resource Manager.
--- - If a table of strings is passed as an argument, these strings will be batch names under which all the subsequently loaded
---   and queued resources (by `:getResource*()` and `:queueResource()`) will be loaded as a part of. Unloading *all* of these
---   batches by calling `:unloadResourceBatch()` will cause the resource to be unloaded from memory.
--- - If `nil` is specified (or the function is called without arguments), all subsequently loaded resources will be loaded permanently.
---@param batches string[]? A table of strings, each of which is a resource batch identifier.
function ResourceManager:setBatches(batches)
	self.currentBatches = batches
end



---Unloads a resource batch by removing it from all loaded resources, if applicable.
---For any Resource, if it had only that batch assigned, the resource is removed from memory.
---@param name string The resource batch name to be unloaded.
function ResourceManager:unloadResourceBatch(name)
	for key, resource in pairs(self.resources) do
		if resource.batches then
			for i, batch in ipairs(resource.batches) do
				if batch == name then
					table.remove(resource.batches, i)
					if #resource.batches == 0 then
						local type = self.resources[key].type
						self.resources[key] = nil
						_Log:printt("ResourceManager2", key .. " (" .. type .. ") unloaded!")
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
			self:queueResource(file)
		end
	end
end



---Returns a list of paths to all loaded resources of a given type.
---@param type string One of `RESOURCE_TYPES`, of which all loaded resource paths will be returned.
---@return string[]
function ResourceManager:getResourceList(type)
	local pathList = {}

	-- Iterate through all known resources. If the type matches, add it to the returned list.
	for key, resource in pairs(self.resources) do
		if resource.type == type then
			table.insert(pathList, key)
		end
	end

	return pathList
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
