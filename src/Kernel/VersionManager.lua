-- This system needs to be axed soon. @jakubg1

local class = require "com.class"

---@class VersionManager
---@overload fun(path):VersionManager
local VersionManager = class:derive("VersionManager")



function VersionManager:new(path)
  -- versions sorted from most recent to oldest
	self.versions = {
    "v0.47.2",
    "v0.47.1",
		"v0.40.0",
    "v0.30.0",
    "v0.22.1"
  }

	self.versionData = {
    ["v0.47.2"] = {inconvertible = false},
    ["v0.47.1"] = {inconvertible = false},
		["v0.40.0"] = {inconvertible = false, supported = true},
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



function VersionManager:getVersionID(version)
  -- greater number = older version
  -- 0 when not found
  for i, v in ipairs(self.versions) do
    if v == version then
      return i
    end
  end
  return 0
end

function VersionManager:getVersionStatus(version)
  -- -1: unknown version (on input)
  -- 0: old version
  -- 1: up to date version
  -- 2: unknown version (on output) / future version
	-- 3: old version but you can't convert to it
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
