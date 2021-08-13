local class = require "com/class"
local RuntimeManager = class:derive("RuntimeManager")

local ProfileManager = require("src/ProfileManager")
local Highscores = require("src/Highscores")
local Options = require("src/Options")

function RuntimeManager:new()
	print("Initializing RuntimeManager...")

	self.profileManager = nil
	self.highscores = nil
	self.options = nil

	self:load()
end

function RuntimeManager:load()
	-- if runtime.json exists, then load it
	if pcall(function() loadJson(parsePath("runtime.json")) end) then
		local data = loadJson(parsePath("runtime.json"))

		self.profileManager = ProfileManager(data.profiles)
		self.highscores = Highscores(data.highscores)
		self.options = Options(data.options)
	else
		print("[RuntimeManager] No data found! Possibly starting up for the first time or the save data got corrupted...")
		print("[RuntimeManager] If you believe you had some data saved in this game, DON'T EXIT NORMALLY and do the following:")
		print("[RuntimeManager] In order to possibly rescue your data, open the console via Ctrl + Shift + ` and write \"crash\".")
		print("[RuntimeManager] The game will deliberately crash. Don't press \"Emergency Save\" and exit without saving.")
		print("[RuntimeManager] To possibly recover your data, inspect the runtime.json file in the game folder")
		print("[RuntimeManager] or send it to the development team!")
		print("[RuntimeManager]")
		print("[RuntimeManager] If you're launching the game for the first time, you can safely ignore above message.")
		self.profileManager = ProfileManager(nil)
		self.highscores = Highscores(nil)
		self.options = Options(nil)
	end
end

function RuntimeManager:save()
	local data = {}

	data.profiles = self.profileManager.data
	data.highscores = self.highscores.data
	data.options = self.options.data

	saveJson(parsePath("runtime.json"), data)
end



return RuntimeManager
