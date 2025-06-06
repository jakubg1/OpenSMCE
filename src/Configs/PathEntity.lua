--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class PathEntityConfig
---@overload fun(data, path, isAnonymous):PathEntityConfig
local PathEntityConfig = class:derive("PathEntityConfig")

PathEntityConfig.metadata = {
    schemaPath = "path_entity.json"
}

---Constructs an instance of PathEntityConfig.
---@param data table Raw data from a file.
---@param path string? Path to the file. Used for error messages and saving data.
---@param isAnonymous boolean? If `true`, this resource is anonymous and its path is invalid for saving data.
function PathEntityConfig:new(data, path, isAnonymous)
    local u = _ConfigUtils
    self._path = path
    self._alias = data._alias
    self._isAnonymous = isAnonymous

    self.sprite = u.parseSpriteOpt(data.sprite, path, "sprite")
    self.shadowSprite = u.parseSpriteOpt(data.shadowSprite, path, "shadowSprite")
    self.spawnPlacement = u.parseString(data.spawnPlacement, path, "spawnPlacement")
    self.spawnOffset = u.parseNumberOpt(data.spawnOffset, path, "spawnOffset") or 0
    self.speed = u.parseNumber(data.speed, path, "speed")
    self.acceleration = u.parseNumberOpt(data.acceleration, path, "acceleration") or 0
    self.maxSpeed = u.parseNumberOpt(data.maxSpeed, path, "maxSpeed")
    self.maxOffset = u.parseNumberOpt(data.maxOffset, path, "maxOffset")
    self.destroyOffset = u.parseNumberOpt(data.destroyOffset, path, "destroyOffset")
    self.destroyTime = u.parseNumberOpt(data.destroyTime, path, "destroyTime")
    self.destroyWhenPathEmpty = u.parseBooleanOpt(data.destroyWhenPathEmpty, path, "destroyWhenPathEmpty")
    self.destroyAtClearOffset = u.parseBooleanOpt(data.destroyAtClearOffset, path, "destroyAtClearOffset")
    self.particle = u.parseParticleEffectConfigOpt(data.particle, path, "particle")
    self.particleSeparation = u.parseNumberOpt(data.particleSeparation, path, "particleSeparation")
    self.renderParticlesInTunnels = u.parseBooleanOpt(data.renderParticlesInTunnels, path, "renderParticlesInTunnels")
    self.loopSound = u.parseSoundEventOpt(data.loopSound, path, "loopSound")
    self.collectibleGenerator = u.parseCollectibleGeneratorConfigOpt(data.collectibleGenerator, path, "collectibleGenerator")
    self.collectibleGeneratorSeparation = u.parseNumberOpt(data.collectibleGeneratorSeparation, path, "collectibleGeneratorSeparation")
    self.destroyParticle = u.parseParticleEffectConfigOpt(data.destroyParticle, path, "destroyParticle")
    self.destroySound = u.parseSoundEventOpt(data.destroySound, path, "destroySound")
    self.destroyScoreEvent = u.parseScoreEventConfigOpt(data.destroyScoreEvent, path, "destroyScoreEvent")
    self.destroyCollectibleGenerator = u.parseCollectibleGeneratorConfigOpt(data.destroyCollectibleGenerator, path, "destroyCollectibleGenerator")
    self.canDestroySpheres = u.parseBooleanOpt(data.canDestroySpheres, path, "canDestroySpheres")
    self.sphereDestroySound = u.parseSoundEventOpt(data.sphereDestroySound, path, "sphereDestroySound")
    self.sphereDestroyScoreEvent = u.parseScoreEventConfigOpt(data.sphereDestroyScoreEvent, path, "sphereDestroyScoreEvent")
    self.maxSpheresDestroyed = u.parseIntegerOpt(data.maxSpheresDestroyed, path, "maxSpheresDestroyed")
    self.maxSphereChainsDestroyed = u.parseIntegerOpt(data.maxSphereChainsDestroyed, path, "maxSphereChainsDestroyed")
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function PathEntityConfig.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a PathEntityConfig by given path.
    ---@param reference string The path to the resource.
    ---@return PathEntityConfig
    function ResourceManager:getPathEntityConfig(reference)
        return self:getResourceConfig(reference, "PathEntity")
    end
end

return PathEntityConfig