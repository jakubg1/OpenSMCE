--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class LevelSequenceConfig
---@overload fun(data, path):LevelSequenceConfig
local LevelSequenceConfig = class:derive("LevelSequenceConfig")



---Constructs an instance of LevelSequenceConfig.
---@param data table Raw data from a file.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function LevelSequenceConfig:new(data, path)
    local u = _ConfigUtils
    self._path = path

    self.sequence = {}
    for i = 1, #data.sequence do
        self.sequence[i] = {}
        self.sequence[i].type = u.parseString(data.sequence[i].type, path, "sequence[" .. tostring(i) .. "].type")
        if self.sequence[i].type == "wait" then
            self.sequence[i].delay = u.parseNumber(data.sequence[i].delay, path, "sequence[" .. tostring(i) .. "].delay")
        elseif self.sequence[i].type == "waitForCollectibles" then
            -- No fields
        elseif self.sequence[i].type == "uiCallback" then
            self.sequence[i].callback = u.parseString(data.sequence[i].callback, path, "sequence[" .. tostring(i) .. "].callback")
            self.sequence[i].waitUntilFinished = u.parseBooleanOpt(data.sequence[i].waitUntilFinished, path, "sequence[" .. tostring(i) .. "].waitUntilFinished")
            self.sequence[i].retriggerWhenLoaded = u.parseBooleanOpt(data.sequence[i].retriggerWhenLoaded, path, "sequence[" .. tostring(i) .. "].retriggerWhenLoaded") ~= false
        elseif self.sequence[i].type == "pathEntity" then
            self.sequence[i].pathEntity = u.parsePathEntityConfig(data.sequence[i].pathEntity, path, "sequence[" .. tostring(i) .. "].pathEntity")
            self.sequence[i].separatePaths = u.parseBoolean(data.sequence[i].separatePaths, path, "sequence[" .. tostring(i) .. "].separatePaths")
            self.sequence[i].launchDelay = u.parseNumber(data.sequence[i].launchDelay, path, "sequence[" .. tostring(i) .. "].launchDelay")
            self.sequence[i].waitUntilFinished = u.parseBooleanOpt(data.sequence[i].waitUntilFinished, path, "sequence[" .. tostring(i) .. "].waitUntilFinished")
            self.sequence[i].skippable = u.parseBoolean(data.sequence[i].skippable, path, "sequence[" .. tostring(i) .. "].skippable")
        elseif self.sequence[i].type == "gameplay" then
            self.sequence[i].warmupTime = u.parseNumber(data.sequence[i].warmupTime, path, "sequence[" .. tostring(i) .. "].warmupTime")
            self.sequence[i].previewFirstShooterColor = u.parseBooleanOpt(data.sequence[i].previewFirstShooterColor, path, "sequence[" .. tostring(i) .. "].previewFirstShooterColor")
            self.sequence[i].onFail = u.parseIntegerOpt(data.sequence[i].onFail, path, "sequence[" .. tostring(i) .. "].onFail")
            self.sequence[i].onWin = u.parseIntegerOpt(data.sequence[i].onWin, path, "sequence[" .. tostring(i) .. "].onWin")
            self.sequence[i].onObjectivesReached = u.parseIntegerOpt(data.sequence[i].onObjectivesReached, path, "sequence[" .. tostring(i) .. "].onObjectivesReached")
        elseif self.sequence[i].type == "fail" then
            self.sequence[i].waitUntilFinished = u.parseBooleanOpt(data.sequence[i].waitUntilFinished, path, "sequence[" .. tostring(i) .. "].waitUntilFinished")
            self.sequence[i].skippable = u.parseBoolean(data.sequence[i].skippable, path, "sequence[" .. tostring(i) .. "].skippable")
        elseif self.sequence[i].type == "clearBoard" then
            -- No fields
        elseif self.sequence[i].type == "collectibleEffect" then
            self.sequence[i].effects = {}
            for j = 1, #data.sequence[i].effects do
                self.sequence[i].effects[j] = u.parseCollectibleEffectConfig(data.sequence[i].effects[j], path, "sequence[" .. tostring(i) .. "].effects[" .. tostring(j) .. "]")
            end
        elseif self.sequence[i].type == "end" then
            self.sequence[i].status = u.parseString(data.sequence[i].status, path, "sequence[" .. tostring(i) .. "].status")
        else
            error(string.format("Unknown LevelSequenceConfig type: %s (expected \"wait\", \"waitForCollectibles\", \"uiCallback\", \"pathEntity\", \"gameplay\", \"fail\", \"clearBoard\", \"collectibleEffect\", \"end\")", self.sequence[i].type))
        end
        self.sequence[i].muteMusic = u.parseBooleanOpt(data.sequence[i].muteMusic, path, "sequence[" .. tostring(i) .. "].muteMusic")
    end
end



return LevelSequenceConfig