local class = require "com/class"
local VersionManager = class:derive("VersionManager")

function VersionManager:new(path)
  -- versions sorted from most recent to oldest
	self.versions = {
		"v0.40.0",
    "v0.30.0",
    "v0.22.1"
  }

	self.versionData = {
		["v0.40.0"] = {inconvertible = false},
    ["v0.30.0"] = {inconvertible = true},
    ["v0.22.1"] = {inconvertible = false}
  }
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
				else
        	return 0
				end
      end
    end
  end

  return 2
end

-- Converts all the way up to the current version
function VersionManager:convertGame(name, version)
  -- Backup copy is really important!
  local contents = loadFile(string.format("games/%s/config.json", name))
  saveFile(string.format("games/%s/config_orig_%s.json", name, version), contents)

  local versionID = self:getVersionID(version)
  while versionID > 1 do
    self:convertGameStep(name, self.versions[versionID])
    versionID = versionID - 1
  end
end

-- Converts one version up
function VersionManager:convertGameStep(name, version)
  local nextVersion = self.versions[self:getVersionID(version) - 1]
  local nextVersionFile = strJoin(strSplit(nextVersion, "."), "_")
  print(string.format("[VersionManager] Conversion: %s from %s to %s", name, version, nextVersion))
  local mod = require(string.format("src/Kernel/Version/%s", nextVersionFile))
  mod.main(string.format("games/%s/", name))
end



return VersionManager
