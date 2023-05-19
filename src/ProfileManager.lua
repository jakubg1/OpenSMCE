local class = require "com.class"

---Manages all Profiles. Handles creating and removing them, and also saving and loading profile data.
---@class ProfileManager
---@overload fun(data):ProfileManager
local ProfileManager = class:derive("ProfileManager")

local Profile = require("src.Profile")



---Constructs a Profile Manager.
---@param data table Deserialization data.
function ProfileManager:new(data)
	self.order = {}
	self.profiles = {}
	self.selected = ""

	if data then
		self:deserialize(data)
	end
end



---Returns the currently selected Profile.
---@return Profile
function ProfileManager:getCurrentProfile()
	return self.profiles[self.selected]
end



---Selects a profile with a given name.
---@param name string The profile name to be selected.
function ProfileManager:setCurrentProfile(name)
	self.selected = name
end



---Creates a new profile with a given name, selects it and returns `true`. If a profile with a given name already exists, this function returns `false` instead.
---@param name string The profile name.
---@return boolean
function ProfileManager:createProfile(name)
	-- duplication check
	if self.profiles[name] then
		return false
	end
	self.profiles[name] = Profile(nil, name)
	table.insert(self.order, name)
	self.selected = name
	return true
end



---Removes a profile with a given name. If this was the currently selected profile, the ProfileManager will select the first profile from a list.
---@param name string The profile name.
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



---Serializes the ProfileManager's data to be saved.
---@return table
function ProfileManager:serialize()
	local t = {
		order = self.order,
		profiles = {},
		selected = self.selected
	}
	for profileN, profile in pairs(self.profiles) do
		t.profiles[profileN] = profile:serialize()
	end
	return t
end



---Restores the ProfileManager's state to the one saved by the serialization function.
---@param t table The data to be deserialized.
function ProfileManager:deserialize(t)
	self.order = t.order
	self.profiles = {}
	for profileN, profile in pairs(t.profiles) do
		self.profiles[profileN] = Profile(profile, profileN)
	end
	self.selected = t.selected
end



return ProfileManager
