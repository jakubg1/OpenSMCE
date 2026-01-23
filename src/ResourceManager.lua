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
local MusicTrack = require("src.Essentials.MusicTrack")
local FontFile = require("src.Essentials.FontFile")
local Font = require("src.Essentials.Font")
local Shader = require("src.Essentials.Shader")
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
	-- Keys are absolute paths starting from the root game directory.
	-- If a resource is queued but not loaded, its entry will not exist at all.
	---@type table<string, Resource>
	self.resources = {}
	-- A list of keys of the queued resources alongside their batches. Used to preserve the loading order.
	---@type {key: string, batches: string[]}[]
	self.queuedResources = {}

	-- Newly queued/loaded resources will be a part of these batches if specified. Otherwise, loaded resources will be loaded permanently.
	---@type string[]?
	self.currentBatches = nil

	-- Path to the source code directory where all Config Classes are stored. Used to scan for and register the resource types.
	self.RESOURCE_TYPE_LOCATION = "src/Configs"

	-- This table is filled dynamically by calling `ResourceManager:registerResourceTypes()`.
	-- `constructor` is a Config Class constructor, whereas `assetConstructor` is a singleton resource constructor.
	---@type table<string, {constructor: any?, assetConstructor: any?}>
	self.RESOURCE_TYPES = {
		Image = {assetConstructor = Image},
		Sound = {assetConstructor = Sound},
		FontFile = {assetConstructor = FontFile},
		Shader = {assetConstructor = Shader}
	}

	-- This table is filled dynamically by calling `ResourceManager:registerResourceTypes()`.
	-- It is used to determine the resource type based on the `$schema` field for JSON files.
	-- Check the `:getResourceTypeFromSchema()` function for more information.
	---@type table<string, string>
	self.SCHEMA_TO_RESOURCE_MAP = {}

	-- This table is used to determine resource types which are not JSON files with a `$schema` field.
	self.EXTENSION_TO_RESOURCE_MAP = {
		png = "Image",
		ogg = "Sound",
		mp3 = "Sound",
		wav = "Sound",
		ttf = "FontFile",
		glsl = "Shader"
	}

	-- Register the resource types and config constructors.
	self:registerResourceTypes(self.RESOURCE_TYPE_LOCATION)

	-- Register the singleton/asset constructors.
	self.SINGLETON_LIST = {
		ColorPalette = ColorPalette,
		Font = Font,
		Sprite = Sprite,
		SpriteAtlas = SpriteAtlas,
		SoundEvent = SoundEvent,
		MusicTrack = MusicTrack
	}
	self:registerResourceSingletons(self.SINGLETON_LIST)

	-- Load counters allow tracking the progress of loading a chosen set of resources.
	---@alias LoadCounter {queued: integer, loaded: integer, active: boolean, queueKeys: table<string, boolean>}
	---@type table<string, LoadCounter>
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
		local resourceClass = require(dir:gsub("/", ".") .. "." .. name)
		if resourceClass.metadata and resourceClass.inject then
			self:say("Registered resource type: " .. name)
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
---@param singletons table<string, any> Keys are resource names, values are classes corresponding to that resource's singleton class.
function ResourceManager:registerResourceSingletons(singletons)
	for name, singletonClass in pairs(singletons) do
		singletonClass.inject(ResourceManager)
		self.RESOURCE_TYPES[name].assetConstructor = singletonClass
	end
end



---Unloads all resources from this Resource Manager.
function ResourceManager:unloadAllResources()
	for key, resource in pairs(self.resources) do
		-- TODO: Stop all sounds and music elsewhere. This is not the place to do it!
		if resource.asset and resource.asset.stop then
			resource.asset:stop()
		end
		self:unloadResource(key)
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

---Retrieves a Font File by a given path.
---@param path string The resource path.
---@return FontFile
function ResourceManager:getFontFile(path)
	return self:getResourceAsset(path, "font file")
end

---Retrieves a Shader by a given path.
---@param path string The resource path.
---@return Shader
function ResourceManager:getShader(path)
	return self:getResourceAsset(path, "shader")
end



---Returns `true` if a resource at the provided path is loaded, `false` otherwise.
---@param key string The path to the resource.
---@return boolean
function ResourceManager:isResourceLoaded(key)
	return self.resources[key] ~= nil
end



---Queues a resource to be loaded soon, if not loaded yet.
---If many calls to this function are done in a quick succession, the load order will be preserved.
---@param key string The path to the resource.
function ResourceManager:queueResource(key)
	if self.resources[key] then
		self:updateResourceBatches(key, self.currentBatches)
	else
		-- Queue the resource to be loaded. Include batches if it has to be loaded with them.
		table.insert(self.queuedResources, {key = key, batches = self.currentBatches})
		-- Mark the resource as tracked by any load counters.
		self:queueLoadProgressResource(key)
	end
end



---Retrieves the resource entry by its path. If the resource is not yet loaded, it is immediately loaded.
---Returns `nil` if the resource cannot be found.
---
---Internal use only; use other `get*` functions for type support.
---@private
---@param key string The path to the resource.
---@param resType string The type of the resource.
---@return Resource
function ResourceManager:getResource(key, resType)
	assert(type(key) == "string", string.format("Invalid resource key (%s) type: %s (must be string)", key, type(key)))
	if self.resources[key] then
		-- We found a resource by path.
		self:updateResourceBatches(key, self.currentBatches)
		return self.resources[key]
	end
	-- If the resource is not found, try loading the resource.
	self:loadResource(key, self.currentBatches)
	return assert(self.resources[key], string.format("Could not find %s: \"%s\"", resType, key))
end



---Retrieves the resource asset by its path and type. If the resource is not yet loaded, it is immediately loaded.
---Internal use only; use other `get*` functions for type support.
---@private
---@param key string The path to the resource.
---@param resType string The type of the resource.
---@return any
function ResourceManager:getResourceAsset(key, resType)
	return self:getResource(key, resType).asset
end



---Retrieves the resource config by its path and type. If the resource is not yet loaded, it is immediately loaded.
---Internal use only; use other `get*` functions for type support.
---@private
---@param key string The path to the resource.
---@param resType string The type of the resource.
---@return any
function ResourceManager:getResourceConfig(key, resType)
	return self:getResource(key, resType).config
end



---Retrieves the provided resource's path which can be used to refer to this resource back again.
---Throws an error if the provided resource is an anonymous resource.
---@param resource any The resource config.
---@return string
function ResourceManager:getResourceReference(resource)
	assert(not resource._isAnonymous, string.format("Attempt to get a reference to an anonymous resource located in file: %s", resource._path))
	return resource._path
end



---Returns the resource type based on provided schema path, which is the same as the string found in the `$schema` field in any recognized resource.
---
---For example, passing `"../../../../schemas/Level.json"` will return `"Level"` if the Level resource is registered to listen on `schemas/Level.json` schemas.
---@private
---@param schemaPath string? Schema path to be parsed. If `nil` is provided, `nil` will be returned.
---@return string?
function ResourceManager:getResourceTypeFromSchema(schemaPath)
	if not schemaPath then
		return
	end
	local schemaSpl = _Utils.strSplit(schemaPath, "/schemas/")
	local schema = schemaSpl[2] or schemaSpl[1]
	return schema and self.SCHEMA_TO_RESOURCE_MAP[schema]
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
	self:dequeueLoadProgressResource(key)

	-- Treat the file differently depending on whether it's a JSON file or not, and check the type.
	local resType = nil
	local contents = nil
	local baseResource = nil
	if _Utils.strEndsWith(key, ".json") then
		contents = assert(_Utils.loadJson(_ParsePath(key)), "File not found: " .. key)
		-- Determine the resource type based on schema.
		resType = self:getResourceTypeFromSchema(contents["$schema"])
		-- Load the base resource if defined.
		if resType and contents["_extends"] then
			baseResource = self:getResourceConfig(contents["_extends"], resType)
		end
	else
		local extensionSpl = _Utils.strSplit(key, ".")
		local extension = extensionSpl[#extensionSpl]
		resType = extension and self.EXTENSION_TO_RESOURCE_MAP[extension]
	end

	-- If no valid resource type has been found, discard the resource.
	if not resType then
		self:say("LOUD WARNING: File " .. key .. " ignored")
		return
	end

	-- Get the constructor and construct the resources.
	local constructor = self.RESOURCE_TYPES[resType].constructor
	local assetConstructor = self.RESOURCE_TYPES[resType].assetConstructor
	if not constructor and not assetConstructor then
		self:say("File " .. key .. " not loaded: type " .. resType .. " not implemented")
		return
	end

	-- Prevent overwriting the resource. That's a no.
	if self.resources[key] then
		error(string.format("Tried to load a resource twice: %s", key))
	end

	self.resources[key] = {type = resType, batches = batches and _Utils.copyTable(batches)}

	if constructor then
		-- Construct the resource and check for errors.
		local success, result = xpcall(function() return constructor(contents, key, false, baseResource) end, debug.traceback)
		assert(success, string.format("Failed to load file %s: %s", key, tostring(result)))
		self.resources[key].config = result
	end

	if assetConstructor then
		-- Construct the resource and check for errors.
		local success, result = xpcall(function() return assetConstructor(self.resources[key].config or contents, key) end, debug.traceback)
		assert(success, string.format("Failed to load file %s: %s", key, tostring(result)))
		self.resources[key].asset = result
	end

	-- Print a message to the log.
	self:say(" * " .. key .. " (" .. resType .. ")" .. (batches and (" {" .. table.concat(batches, ", ") .. "}") or "") .. " OK!")
end



---Unloads the resource by its key.
---@private
---@param key string The resource key.
function ResourceManager:unloadResource(key)
	local resType = self.resources[key].type
	self.resources[key] = nil
	self:say(key .. " (" .. resType .. ") unloaded!")
end



---Returns a list of paths to all loaded resources of a given type.
---@param resType string One of `RESOURCE_TYPES`, of which all loaded resource paths will be returned.
---@return string[]
function ResourceManager:getResourceList(resType)
	local keys = {}

	-- Iterate through all known resources. If the type matches, add it to the returned list.
	for key, resource in pairs(self.resources) do
		if resource.type == resType then
			table.insert(keys, key)
		end
	end

	return keys
end

--############################################################--
---------------- R E S O U R C E   B A T C H E S ---------------
--############################################################--

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
						self:unloadResource(key)
					end
					break
				end
			end
		end
	end
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
	if resource.batches then
		_Utils.tableUnionInplace(resource.batches, batches)
	end
end

--######################################################--
---------------- L O A D   C O U N T E R S ---------------
--######################################################--

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

---Queues a new resource to be tracked by the currently active Load Counters.
---@private
---@param key string The resource key.
function ResourceManager:queueLoadProgressResource(key)
	for name, loadCounter in pairs(self.loadCounters) do
		if loadCounter.active then
			loadCounter.queued = loadCounter.queued + 1
			loadCounter.queueKeys[key] = true
		end
	end
end

---Notifies all Load Counters that a resource has been loaded and increments the progress for counters tracking that resource.
---@private
---@param key string The resource key.
function ResourceManager:dequeueLoadProgressResource(key)
	for name, loadCounter in pairs(self.loadCounters) do
		if loadCounter.queueKeys[key] then
			loadCounter.loaded = loadCounter.loaded + 1
			loadCounter.queueKeys[key] = nil
		end
	end
end

--######################################--
---------------- D E B U G ---------------
--######################################--

---Prints a message to the log, coming specifically from this class.
---@private
---@param message string The message to be sent.
function ResourceManager:say(message)
	_Log:printt("ResourceManager", message)
end

return ResourceManager
