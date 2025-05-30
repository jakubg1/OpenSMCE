--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class ParticleEffectConfig
---@overload fun(data, path, isAnonymous):ParticleEffectConfig
local ParticleEffectConfig = class:derive("ParticleEffectConfig")

ParticleEffectConfig.metadata = {
    schemaPath = "particle_effect.json"
}

---Constructs an instance of ParticleEffectConfig.
---@param data table Raw data from a file.
---@param path string? Path to the file. Used for error messages and saving data.
---@param isAnonymous boolean? If `true`, this resource is anonymous and its path is invalid for saving data.
function ParticleEffectConfig:new(data, path, isAnonymous)
    local u = _ConfigUtils
    self._path = path
    self._alias = data._alias
    self._isAnonymous = isAnonymous

    self.emitters = {}
    for i = 1, #data.emitters do
        self.emitters[i] = u.parseParticleEmitterConfig(data.emitters[i], path, "emitters[" .. tostring(i) .. "]")
    end
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function ParticleEffectConfig.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a ParticleEffectConfig by given path.
    ---@param reference string The path to the resource.
    ---@return ParticleEffectConfig
    function ResourceManager:getParticleEffectConfig(reference)
        return self:getResourceConfig(reference, "ParticleEffect")
    end
end

return ParticleEffectConfig