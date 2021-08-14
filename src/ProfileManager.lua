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

function ProfileManager:setCurrentProfile(name)
	self.selected = name
end

function ProfileManager:deleteProfile(name)
	self.profiles[name] = nil
	for i, n in ipairs(self.order) do
		if name == n then
			table.remove(self.order, i)
			break
		end
	end
	-- if we've just deleted the selected profile, select the first one from the list
	if self.selected == name then
		self.selected = self.order[1]
	end
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
