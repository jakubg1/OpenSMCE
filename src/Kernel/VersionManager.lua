local class = require "com/class"
local VersionManager = class:derive("VersionManager")

function VersionManager:new(path)
  -- versions sorted from most recent to oldest
	self.versions = {
    "v0.30.0",
    "v0.22.1"
  }
end



function VersionManager:getVersionStatus(version)
  -- -1: unknown version (on input)
  -- 0: old version
  -- 1: up to date version
  -- 2: unknown version (on output) / future version
  if not version then
    return -1
  end

  for i, v in ipairs(self.versions) do
    if v == version then
      if i == 1 then
        return 1
      else
        return 0
      end
    end
  end

  return 2
end



return VersionManager
