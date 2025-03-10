--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class CollectibleEffectConfig
---@overload fun(data, path):CollectibleEffectConfig
local CollectibleEffectConfig = class:derive("CollectibleEffectConfig")



---Constructs an instance of CollectibleEffectConfig.
---@param data table Raw data from a file.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function CollectibleEffectConfig:new(data, path)
    local u = _ConfigUtils
    self._path = path

    self.type = u.parseString(data.type, path, "type")
    if self.type == "replaceSphere" then
        self.color = u.parseInteger(data.color, path, "color")
    elseif self.type == "multiSphere" then
        self.color = u.parseInteger(data.color, path, "color")
        self.count = u.parseExprInteger(data.count, path, "count")
    elseif self.type == "removeMultiSphere" then
        -- No fields
    elseif self.type == "speedShot" then
        self.time = u.parseNumber(data.time, path, "time")
        self.speed = u.parseNumber(data.speed, path, "speed")
    elseif self.type == "homingBugs" then
        self.time = u.parseNumber(data.time, path, "time")
    elseif self.type == "speedOverride" then
        self.speedBase = u.parseNumber(data.speedBase, path, "speedBase")
        self.speedMultiplier = u.parseNumber(data.speedMultiplier, path, "speedMultiplier")
        self.decceleration = u.parseNumber(data.decceleration, path, "decceleration")
        self.time = u.parseNumber(data.time, path, "time")
    elseif self.type == "destroySpheres" then
        self.selector = u.parseSphereSelectorConfig(data.selector, path, "selector")
        self.scoreEvent = u.parseScoreEventConfigOpt(data.scoreEvent, path, "scoreEvent")
        self.scoreEventPerSphere = u.parseScoreEventConfigOpt(data.scoreEventPerSphere, path, "scoreEventPerSphere")
    elseif self.type == "spawnPathEntity" then
        self.pathEntity = u.parsePathEntityConfig(data.pathEntity, path, "pathEntity")
    elseif self.type == "lightningStorm" then
        self.count = u.parseExprInteger(data.count, path, "count")
    elseif self.type == "activateNet" then
        self.time = u.parseNumber(data.time, path, "time")
    elseif self.type == "changeGameSpeed" then
        self.speed = u.parseNumber(data.speed, path, "speed")
        self.time = u.parseNumber(data.time, path, "time")
    elseif self.type == "setCombo" then
        self.combo = u.parseInteger(data.combo, path, "combo")
    elseif self.type == "executeScoreEvent" then
        self.scoreEvent = u.parseScoreEventConfig(data.scoreEvent, path, "scoreEvent")
    elseif self.type == "setScoreMultiplier" then
        self.multiplier = u.parseNumber(data.multiplier, path, "multiplier")
        self.time = u.parseNumber(data.time, path, "time")
    elseif self.type == "grantCoin" then
        -- No fields
    elseif self.type == "incrementGemStat" then
        -- No fields
    else
        error(string.format("Unknown CollectibleEffectConfig type: %s (expected \"replaceSphere\", \"multiSphere\", \"removeMultiSphere\", \"speedShot\", \"homingBugs\", \"speedOverride\", \"destroySpheres\", \"spawnPathEntity\", \"lightningStorm\", \"activateNet\", \"changeGameSpeed\", \"setCombo\", \"executeScoreEvent\", \"setScoreMultiplier\", \"grantCoin\", \"incrementGemStat\")", self.type))
    end
end



return CollectibleEffectConfig