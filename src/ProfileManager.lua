local class = require "com/class"
local ProfileManager = class:derive("ProfileManager")

local Profile = require("src/Profile")

function ProfileManager:new(data)
	self.order = {}
	self.profiles = {}
	self.selected = ""

	if data then
		self:deserialize(data)
	end
end

function ProfileManager:getCurrentProfile()
	return self.profiles[self.selected]
end



function ProfileManager:serialize()
	local t = {
		order = self.order,
		profiles = {},
		selected = self.selected
	}
	for profileN, profile in pairs(self.profiles) do
		t.profiles[profileN] = profile.data
	end
	return t
end

function ProfileManager:deserialize(t)
	self.order = t.order
	self.profiles = {}
	for profileN, profile in pairs(t.profiles) do
		self.profiles[profileN] = Profile(profile, profileN)
	end
	self.selected = t.selected
end



return ProfileManager
