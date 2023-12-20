local class = require "com.class"

---A wrapper class for Highscores, Options and Profile Manager. Packs it up neatly into one file called `runtime.json`.
---@class RuntimeManager
---@overload fun():RuntimeManager
local RuntimeManager = class:derive("RuntimeManager")

local ProfileManager = require("src.ProfileManager")
local Highscores = require("src.Highscores")
local Options = require("src.Options")



---Constructs a Runtime Manager.
function RuntimeManager:new()
	_Log:printt("RuntimeManager", "Initializing RuntimeManager...")

	self.profileManager = nil
	self.highscores = nil
	self.options = nil

	self:load()
end



---Loads runtime data from `runtime.json`. If the file doesn't exist or is corrupted, generates a new runtime and prints a message to the log.
function RuntimeManager:load()
	-- if runtime.json exists, then load it
	if pcall(function() _Utils.loadJson(_ParsePath("runtime.json")) end) then
		local data = _Utils.loadJson(_ParsePath("runtime.json"))

		self.profileManager = ProfileManager(data.profiles)
		self.highscores = Highscores(data.highscores)
		self.options = Options(data.options)
	else
		_Log:printt("RuntimeManager", "No data found! Possibly starting up for the first time or the save data got corrupted...")
		_Log:printt("RuntimeManager", "If you believe you had some data saved in this game, DON'T EXIT NORMALLY and do the following:")
		_Log:printt("RuntimeManager", "In order to possibly rescue your data, open the console via Ctrl + ` and write \"crash\".")
		_Log:printt("RuntimeManager", "The game will deliberately crash. Don't press \"Emergency Save\" and exit without saving.")
		_Log:printt("RuntimeManager", "To possibly recover your data, inspect the runtime.json file in the game folder")
		_Log:printt("RuntimeManager", "or send it to the development team!")
		_Log:printt("RuntimeManager", "")
		_Log:printt("RuntimeManager", "If you're launching the game for the first time, you can safely ignore the above message.")
		self.profileManager = ProfileManager(nil)
		self.highscores = Highscores(nil)
		self.options = Options(nil)
	end
end



---Saves runtime data to `runtime.json`.
function RuntimeManager:save()
	local data = {}

	data.profiles = self.profileManager:serialize()
	data.highscores = self.highscores.data
	data.options = self.options.data

	_Utils.saveJson(_ParsePath("runtime.json"), data)
end



return RuntimeManager
