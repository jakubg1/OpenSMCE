local class = require "com.class"

---@class DifficultyConfig
---@overload fun(data, path):DifficultyConfig
local DifficultyConfig = class:derive("DifficultyConfig")



---Constructs a new Difficulty Config.
---@param data table Raw difficulty data.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function DifficultyConfig:new(data, path)
    local u = _ConfigUtils

    self.speedMultiplier = u.parseNumber(data.speedMultiplier, path, "speedMultiplier")
    self.scoreMultiplier = u.parseNumber(data.scoreMultiplier, path, "scoreMultiplier")

    self.lifeConfig = {}
    self.lifeConfig.type = u.parseString(data.lifeConfig.type, path, "lifeConfig.type")
    if self.lifeConfig.type == "score" then
        self.lifeConfig.startingLives = u.parseInteger(data.lifeConfig.startingLives, path, "lifeConfig.startingLives")
        self.lifeConfig.scorePerLife = u.parseInteger(data.lifeConfig.scorePerLife, path, "lifeConfig.scorePerLife")
        self.lifeConfig.countUnmultipliedScore = u.parseBooleanOpt(data.lifeConfig.countUnmultipliedScore, path, "lifeConfig.countUnmultipliedScore") or false
        self.lifeConfig.rollbackScoreAfterFailure = u.parseBooleanOpt(data.lifeConfig.rollbackScoreAfterFailure, path, "lifeConfig.rollbackScoreAfterFailure") or false
    elseif self.lifeConfig.type == "coins" then
        self.lifeConfig.startingLives = u.parseInteger(data.lifeConfig.startingLives, path, "lifeConfig.startingLives")
        self.lifeConfig.coinsPerLife = u.parseInteger(data.lifeConfig.coinsPerLife, path, "lifeConfig.coinsPerLife")
        self.lifeConfig.rollbackScoreAfterFailure = u.parseBooleanOpt(data.lifeConfig.rollbackScoreAfterFailure, path, "lifeConfig.rollbackScoreAfterFailure") or false
    elseif self.lifeConfig.type == "none" then
        self.lifeConfig.rollbackScoreAfterFailure = u.parseBooleanOpt(data.lifeConfig.rollbackScoreAfterFailure, path, "lifeConfig.rollbackScoreAfterFailure") or false
    else
        error(string.format("Unknown lifeConfig type: %s (expected \"score\", \"coins\" or \"none\")", self.lifeConfig.type))
    end
end



return DifficultyConfig