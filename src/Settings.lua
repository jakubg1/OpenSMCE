local class = require "com.class"

---Represents the Engine Settings. These settings are stored in `settings.json` and are game-independent.
---@class Settings
---@overload fun():Settings
local Settings = class:derive("Settings")

---Constructs a Settings object.
function Settings:new()
	self.FILE = "settings.json"

	---@alias Setting "discordRPC"|"backToBoot"|"backToBootWithX"|"maximizeOnStart"|"aimingRetical"|"consoleWindow"|"threedeeSound"|"hideIncompatibleGames"|"printDeprecationNotices"|"enableProfiler"

	-- Contains the true setting values which are respected.
	self.data = {
		discordRPC = true,
		backToBoot = false,
		backToBootWithX = false,
		maximizeOnStart = true,
		aimingRetical = false,
		consoleWindow = true,
		threedeeSound = false,
		hideIncompatibleGames = false,
		printDeprecationNotices = false,
		enableProfiler = false
	}
	-- Contains the setting values which are not yet respected and have to be confirmed with `:saveWork()` or restored with `:restoreWork()`.
	self.workData = _Utils.copyTable(self.data)
end

---Sets a setting based on its key.
---@param key Setting The setting key.
---@param value any The setting value.
function Settings:setSetting(key, value)
	self.data[key] = value
end

---Gets a setting based on its key.
---@param key Setting The setting key.
---@return any
function Settings:getSetting(key)
	return self.data[key]
end

---Sets a work setting based on its key.
---The work settings are not saved or respected and need to be confirmed with `:saveWork()` or restored with `:restoreWork()`.
---@param key Setting The setting key.
---@param value any The setting value.
function Settings:setWorkSetting(key, value)
	self.workData[key] = value
end

---Gets a work setting based on its key.
---The work settings are not saved or respected and need to be confirmed with `:saveWork()` or restored with `:restoreWork()`.
---@param key Setting The setting key.
---@return any
function Settings:getWorkSetting(key)
	return self.workData[key]
end

---Saves the settings set by `:setWorkSetting()` into the real setting values.
function Settings:saveWork()
	self.data = _Utils.copyTable(self.workData)
end

---Restores the real setting values into the work settings and discards any changes made with `:setWorkSetting()`.
function Settings:restoreWork()
	self.workData = _Utils.copyTable(self.data)
end

---Returns Settings' data, ready to be saved in JSON format.
---@return table
function Settings:serialize()
	return self.data
end

---Loads previously saved data into the Settings.
---@param t table Data previously saved with `:serialize()`.
function Settings:deserialize(t)
	self.data = t
	self.workData = _Utils.copyTable(t)
end

---Saves data to the settings file.
function Settings:save()
	_Utils.saveJson(self.FILE, self:serialize())
end

---If the settings file exits, loads data from it.
function Settings:load()
	local data = _Utils.loadJson(self.FILE)
	if data then
		self:deserialize(data)
	end
end

return Settings
