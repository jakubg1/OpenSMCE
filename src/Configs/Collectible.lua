local class = require "com.class"

---@class CollectibleConfig
---@overload fun(data, path):CollectibleConfig
local CollectibleConfig = class:derive("CollectibleConfig")

---Constructs an instance of CollectibleConfig.
---@param data table Raw data from a file.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function CollectibleConfig:new(data, path)
    local u = _ConfigUtils
    self._path = path

    self.speed = u.parseExprVec2(data.speed, path, "speed")
    self.acceleration = u.parseExprVec2(data.acceleration, path, "acceleration")
    self.particle = u.parseParticle(data.particle, path, "particle")
    self.pickupParticle = u.parseParticle(data.pickupParticle, path, "pickupParticle")
    self.spawnSound = u.parseSoundEvent(data.spawnSound, path, "spawnSound")
    self.pickupSound = u.parseSoundEvent(data.pickupSound, path, "pickupSound")
    self.pickupName = u.parseStringOpt(data.pickupName, path, "pickupName")
    self.pickupFont = u.parseFontOpt(data.pickupFont, path, "pickupFont")

    self.effects = {}
    if data.effects then
        for i = 1, #data.effects do
            self.effects[i] = u.parseCollectibleEffectConfig(data.effects[i], path, "effects[" .. tostring(i) .. "]")
        end
    end

    self.dropEffects = {}
    if data.dropEffects then
        for i = 1, #data.dropEffects do
            self.dropEffects[i] = u.parseCollectibleEffectConfig(data.dropEffects[i], path, "dropEffects[" .. tostring(i) .. "]")
        end
    end
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager unknown Resource Manager class to inject the functions to.
function CollectibleConfig.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a Collectible Config by a given path.
    ---@param path string The resource path.
    ---@return CollectibleConfig
    function ResourceManager:getCollectibleConfig(path)
        return self:getResourceConfig(path, "collectible")
    end
end

return CollectibleConfig