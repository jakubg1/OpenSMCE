--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class LevelSetConfig
---@overload fun(data, path):LevelSetConfig
local LevelSetConfig = class:derive("LevelSetConfig")



---Constructs an instance of LevelSetConfig.
---@param data table Raw data from a file.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function LevelSetConfig:new(data, path)
    local u = _ConfigUtils
    self._path = path

    self.levelOrder = {}
    for i = 1, #data.levelOrder do
        self.levelOrder[i] = {}
        self.levelOrder[i].type = u.parseString(data.levelOrder[i].type, path, "levelOrder[" .. tostring(i) .. "].type")
        if self.levelOrder[i].type == "level" then
            self.levelOrder[i].level = u.parseInteger(data.levelOrder[i].level, path, "levelOrder[" .. tostring(i) .. "].level")
            self.levelOrder[i].name = u.parseString(data.levelOrder[i].name, path, "levelOrder[" .. tostring(i) .. "].name")
        elseif self.levelOrder[i].type == "randomizer" then
            self.levelOrder[i].pool = {}
            for j = 1, #data.levelOrder[i].pool do
                self.levelOrder[i].pool[j] = u.parseInteger(data.levelOrder[i].pool[j], path, "levelOrder[" .. tostring(i) .. "].pool[" .. tostring(j) .. "]")
            end
            self.levelOrder[i].names = {}
            for j = 1, #data.levelOrder[i].names do
                self.levelOrder[i].names[j] = u.parseString(data.levelOrder[i].names[j], path, "levelOrder[" .. tostring(i) .. "].names[" .. tostring(j) .. "]")
            end
            self.levelOrder[i].count = u.parseInteger(data.levelOrder[i].count, path, "levelOrder[" .. tostring(i) .. "].count")
            self.levelOrder[i].mode = u.parseString(data.levelOrder[i].mode, path, "levelOrder[" .. tostring(i) .. "].mode")
        else
            error(string.format("Unknown LevelSetConfig type: %s (expected \"level\", \"randomizer\")", self.levelOrder[i].type))
        end

        if data.levelOrder[i].checkpoint then
            self.levelOrder[i].checkpoint = {}
            self.levelOrder[i].checkpoint.id = u.parseInteger(data.levelOrder[i].checkpoint.id, path, "levelOrder[" .. tostring(i) .. "].checkpoint.id")
            self.levelOrder[i].checkpoint.unlockedOnStart = u.parseBooleanOpt(data.levelOrder[i].checkpoint.unlockedOnStart, path, "levelOrder[" .. tostring(i) .. "].checkpoint.unlockedOnStart")
        end

        self.levelOrder[i].unlockCheckpointsOnBeat = {}
        if data.levelOrder[i].unlockCheckpointsOnBeat then
            for j = 1, #data.levelOrder[i].unlockCheckpointsOnBeat do
                self.levelOrder[i].unlockCheckpointsOnBeat[j] = u.parseInteger(data.levelOrder[i].unlockCheckpointsOnBeat[j], path, "levelOrder[" .. tostring(i) .. "].unlockCheckpointsOnBeat[" .. tostring(j) .. "]")
            end
        end
    end
end



return LevelSetConfig