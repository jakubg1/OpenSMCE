--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class ProjectileConfig
---@overload fun(data, path):ProjectileConfig
local ProjectileConfig = class:derive("ProjectileConfig")

ProjectileConfig.metadata = {
    schemaPath = "projectile.json"
}

---Constructs an instance of ProjectileConfig.
---@param data table Raw data from a file.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function ProjectileConfig:new(data, path)
    local u = _ConfigUtils
    self._path = path

    self.particle = u.parseParticleOpt(data.particle, path, "particle")
    self.speed = u.parseNumber(data.speed, path, "speed")
    self.spawnDistance = u.parseExprNumberOpt(data.spawnDistance, path, "spawnDistance")
    self.spawnSound = u.parseSoundEventOpt(data.spawnSound, path, "spawnSound")
    self.sphereAlgorithm = u.parseString(data.sphereAlgorithm, path, "sphereAlgorithm")
    self.homing = u.parseBooleanOpt(data.homing, path, "homing")
    self.destroyParticle = u.parseParticle(data.destroyParticle, path, "destroyParticle")
    self.destroySound = u.parseSoundEventOpt(data.destroySound, path, "destroySound")
    self.destroySphereSelector = u.parseSphereSelectorConfig(data.destroySphereSelector, path, "destroySphereSelector")
    self.destroyScoreEvent = u.parseScoreEventConfigOpt(data.destroyScoreEvent, path, "destroyScoreEvent")
    self.destroyScoreEventPerSphere = u.parseScoreEventConfigOpt(data.destroyScoreEventPerSphere, path, "destroyScoreEventPerSphere")
    self.destroyGameEvent = u.parseGameEventConfigOpt(data.destroyGameEvent, path, "destroyGameEvent")
    self.destroyGameEventPerSphere = u.parseGameEventConfigOpt(data.destroyGameEventPerSphere, path, "destroyGameEventPerSphere")
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function ProjectileConfig.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a ProjectileConfig by a given path.
    ---@param path string The resource path.
    ---@return ProjectileConfig
    function ResourceManager:getProjectileConfig(path)
        return self:getResourceConfig(path, "ProjectileConfig")
    end
end

return ProjectileConfig