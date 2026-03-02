local class = require "com.class"

---A class which you can register various objects to (like ProfileManager, Highscores or Options).
---They can be then saved and loaded neatly from one file called `runtime.json`.
---@class RuntimeManager
---@overload fun():RuntimeManager
local RuntimeManager = class:derive("RuntimeManager")

---Constructs a Runtime Manager.
function RuntimeManager:new()
	_Log:printt("RuntimeManager", "Initializing RuntimeManager...")
	self.path = _ParsePath("runtime.json")

	---@alias RuntimeManagerModule {serialize: function, deserialize: function, [any]: any}
	---@type RuntimeManagerModule[]
	self.modules = {}
end

---Registers a module, which is an instance of any class.
---The class must have `:serialize()` and `:deserialize()` functions.
---@param name string Module name. This will be the name under which the provided module will be stored.
---@param m RuntimeManagerModule The object to be registered.
function RuntimeManager:registerModule(name, m)
	assert(m.serialize, "Attempted to register a module without a `:serialize()` function!")
	assert(m.deserialize, "Attempted to register a module without a `:deserialize()` function!")
	self.modules[name] = m
end

---Loads serialized data for each found module from `runtime.json`.
--- - If there is data for an unregistered module, throws an error.
--- - If there is no data for a registered module, does not do anything with it.
--- - If the file doesn't exist altogether, this function will not do anything.
function RuntimeManager:load()
	-- if runtime.json exists, then load it
	local data = _Utils.loadJson(self.path)
	if data then
		_CriticalLoad = true
		for name, moduleData in pairs(data) do
			assert(self.modules[name], string.format("File `%s` contains an unregistered module: `%s`", self.path, name))
			self.modules[name]:deserialize(moduleData)
		end
		_CriticalLoad = false
	end
end

---Saves data from all registered modules to `runtime.json`.
function RuntimeManager:save()
	local data = {}
	for name, m in pairs(self.modules) do
		data[name] = m:serialize()
	end
	_Utils.saveJson(self.path, data)
end

return RuntimeManager
