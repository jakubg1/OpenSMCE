-- This system needs to be axed soon. @jakubg1

local class = require "com.class"

---@class VersionManager
---@overload fun():VersionManager
local VersionManager = class:derive("VersionManager")

function VersionManager:new()
	-- versions sorted from most recent to oldest
	self.versions = {
		"v0.52.1",
		"v0.52.0",
		"v0.51.0",
		"v0.50.0",
		"v0.49.0",
		"v0.48.0",
		"v0.47.2",
		"v0.47.1",
		"v0.40.0",
		"v0.30.0",
		"v0.22.1"
	}

	self.versionData = {
		["v0.52.1"] = {inconvertible = false},
		["v0.52.0"] = {inconvertible = false, supported = true},
		["v0.51.0"] = {inconvertible = true},
		["v0.50.0"] = {inconvertible = true},
		["v0.49.0"] = {inconvertible = true},
		["v0.48.0"] = {inconvertible = true},
		["v0.47.2"] = {inconvertible = true},
		["v0.47.1"] = {inconvertible = true},
		["v0.40.0"] = {inconvertible = true, supported = true},
		["v0.30.0"] = {inconvertible = true},
		["v0.22.1"] = {inconvertible = false}
	}

	-- new version if any
	self.newestVersion = nil
	self.newestVersionAvailable = false

	-- Check the current newest version.
	_Log:printt("VersionManager", "Checking the newest version...")
	_GetNewestVersionThreaded(self.updateNewestVersion, self)
end

---Updates the newest version values based on the provided version tag.
---@param version string Version tag, such as `v0.47.0`.
function VersionManager:updateNewestVersion(version)
	if not version then
		-- Failsafe for love.js, as `_GetNewestVersionThreaded()` seems to struggle with delivering any result (threads not supported?)
		return
	end
	self.newestVersion = version
	_Log:printt("VersionManager", string.format("Newest version: %s", self.newestVersion))
	if self.newestVersion then
		self.newestVersionAvailable = self:isVersionNewerThanCurrent(self.newestVersion)
	end
end

---Returns whether the provided version tag is newer than the current engine version. Works correctly with `v0.47.0` upwards.
---@param version string The engine version to be checked against.
---@return boolean
function VersionManager:isVersionNewerThanCurrent(version)
	return not self.versionData[version]
end

---Returns the index of the specified version. The current version has always the ID of `1`.
---The bigger the index, the older the version.
---If the specified version is not found, returns `nil`.
---@param version string The version name to be checked.
---@return integer?
function VersionManager:getVersionID(version)
	return _Utils.iTableGetValueIndex(self.versions, version)
end

---Returns the specified game version's status in relation to the current engine version.
---
---Returns:
--- - `-1` if `nil` is specified.
--- - `0` if the game needs to be converted in order to be able to be played. (Deprecated)
--- - `1` if the game is up to date and can be run without problems.
--- - `2` if the specified version is unknown (bad or future version).
--- - `3` if the game is made for an older version and cannot be converted or played.
---@param version string? The game version to be checked.
---@return integer
function VersionManager:getVersionStatus(version)
	if not version then
		return -1
	end

	for i, v in ipairs(self.versions) do
		if v == version then
			if i == 1 then
				return 1
			else
				if self.versionData[v].inconvertible then
					return 3
				elseif self.versionData[v].supported then
					return 1
				else
					return 0
				end
			end
		end
	end

	return 2
end

return VersionManager
