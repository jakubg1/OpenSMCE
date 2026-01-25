local class = require "com.class"
local ProfileManager = require("src.Game.ProfileManager")
local Highscores = require("src.Game.Highscores")
local Options = require("src.Game.Options")

---A wrapper class for Highscores, Options and Profile Manager. Packs it up neatly into one file called `runtime.json`.
---@class RuntimeManager
---@overload fun():RuntimeManager
local RuntimeManager = class:derive("RuntimeManager")

---Constructs a Runtime Manager.
function RuntimeManager:new()
	_Log:printt("RuntimeManager", "Initializing RuntimeManager...")

	self.profileManager = ProfileManager()
	self.highscores = Highscores()
	self.options = Options()

	self:load()
end

---Loads runtime data from `runtime.json`. If the file doesn't exist or is corrupted, generates a new runtime and prints a message to the log.
function RuntimeManager:load()
	-- if runtime.json exists, then load it
	local data = _Utils.loadJson(_ParsePath("runtime.json"))
	if data and data.profiles then
		self.profileManager:deserialize(data.profiles)
	end
	if data and data.highscores then
		self.highscores:deserialize(data.highscores)
	end
	if data and data.options then
		self.options:deserialize(data.options)
	end
end

---Saves runtime data to `runtime.json`.
function RuntimeManager:save()
	local data = {}

	data.profiles = self.profileManager:serialize()
	data.highscores = self.highscores:serialize()
	data.options = self.options:serialize()

	_Utils.saveJson(_ParsePath("runtime.json"), data)
end

return RuntimeManager
