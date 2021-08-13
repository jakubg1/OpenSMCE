local class = require "com/class"
local ProfileManager = class:derive("ProfileManager")

local Profile = require("src/Profile")

function ProfileManager:new(data)
	self.data = data
	for profileN, profile in pairs(self.data.profiles) do
		self.data.profiles[profileN] = Profile(profile, profileN)
	end

	if not data then
		self:reset()
	end
end

function ProfileManager:reset()
	self.data = {
		order = {},
		profiles = {},
		selected = ""
	}
end

function ProfileManager:getCurrentProfile()
	return self.data.profiles[self.data.selected]
end



return ProfileManager
