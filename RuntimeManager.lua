local class = require "class"
local RuntimeManager = class:derive("RuntimeManager")

local Profile = require("Profile")
local Highscores = require("Highscores")
local Options = require("Options")

function RuntimeManager:new()
	print("Initializing RuntimeManager...")
	
	self.profile = nil
	self.highscores = nil
	self.options = nil
	
	self:load()
end

function RuntimeManager:load()
	local data = loadJson(parsePath("runtime.json"))
	
	-- TODO: add a ProfileManager
	self.profile = Profile(data.profiles, "TEST")
	self.highscores = Highscores(data.highscores)
	self.options = Options(data.options)
end

function RuntimeManager:save()
	local data = {}
	
	data.profiles = {}
	data.profiles.TEST = self.profile.data
	data.highscores = self.highscores.data
	data.options = self.options.data
	
	saveJson(parsePath("runtime.json"), data)
end



return RuntimeManager