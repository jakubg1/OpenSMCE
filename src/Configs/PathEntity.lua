local class = require "com.class"

---@class PathEntityConfig
---@overload fun(data, path):PathEntityConfig
local PathEntityConfig = class:derive("PathEntityConfig")

local u = require("src.Configs.utils")



---Constructs a new Path Entity Config.
---@param data table Raw path entity data.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function PathEntityConfig:new(data, path)
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
    self.particle = u.parseParticleOpt(data.particle, path, "particle")
    self.particleSeparation = u.parseNumberOpt(data.particleSeparation, path, "particleSeparation")
    self.loopSound = u.parseSoundEventOpt(data.loopSound, path, "loopSound")
    self.collectibleGenerator = u.parseStringOpt(data.collectibleGenerator, path, "collectibleGenerator")
    self.collectibleGeneratorSeparation = u.parseNumberOpt(data.collectibleGeneratorSeparation, path, "collectibleGeneratorSeparation")
    self.destroyParticle = u.parseParticleOpt(data.destroyParticle, path, "destroyParticle")
    self.destroySound = u.parseSoundEventOpt(data.destroySound, path, "destroySound")
    self.destroyScoreEvent = u.parseScoreEventConfigOpt(data.destroyScoreEvent, path, "destroyScoreEvent")
    self.destroyCollectibleGenerator = u.parseStringOpt(data.destroyCollectibleGenerator, path, "destroyCollectibleGenerator")
    self.canDestroySpheres = u.parseBooleanOpt(data.canDestroySpheres, path, "canDestroySpheres")
    self.sphereDestroySound = u.parseSoundEventOpt(data.sphereDestroySound, path, "sphereDestroySound")
    self.sphereDestroyScoreEvent = u.parseScoreEventConfigOpt(data.sphereDestroyScoreEvent, path, "sphereDestroyScoreEvent")
    self.maxSpheresDestroyed = u.parseIntegerOpt(data.maxSpheresDestroyed, path, "maxSpheresDestroyed")
    self.maxSphereChainsDestroyed = u.parseIntegerOpt(data.maxSphereChainsDestroyed, path, "maxSphereChainsDestroyed")
end



return PathEntityConfig