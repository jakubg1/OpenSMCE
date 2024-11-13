local class = require "com.class"

---@class CollectibleGeneratorConfig
---@overload fun(data, path):CollectibleGeneratorConfig
local CollectibleGeneratorConfig = class:derive("CollectibleGeneratorConfig")



---Constructs a new Collectible Generator Config.
---@param data table Raw collectible generator data, found in `collectible_generators/*.json`.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function CollectibleGeneratorConfig:new(data, path)
    local u = _ConfigUtils

    self.type = u.parseString(data.type, path, "type")

    if self.type == "collectible" then
        -- TODO: Replace with parseCollectible once collectibles are moved to config files
        self.name = u.parseString(data.name, path, "name")
    elseif self.type == "collectibleGenerator" then
        self.generator = u.parseCollectibleGeneratorConfigRef(data.generator, path, "generator")
    elseif self.type == "combine" then
        self.entries = {}
        for i = 1, #data.entries do
            self.entries[i] = u.parseCollectibleGeneratorConfig(data.entries[i], path, "entries[" .. tostring(i) .. "]")
        end
    elseif self.type == "repeat" then
        self.entry = u.parseCollectibleGeneratorConfig(data.entry, path, "entry")
        self.count = u.parseExprInteger(data.count, path, "count")
    elseif self.type == "randomPick" then
        self.pool = {}
        for i = 1, #data.pool do
            local choice = {}
            choice.entry = u.parseCollectibleGeneratorConfig(data.pool[i].entry, path, "pool[" .. tostring(i) .. "].entry")
            choice.weight = u.parseNumberOpt(data.pool[i].weight, path, "pool[" .. tostring(i) .. "].weight")
            self.pool[i] = choice
        end
    else
        error(string.format("Unknown collectible generator type: %s (expected \"collectible\", \"collectibleGenerator\", \"combine\", \"repeat\" or \"randomPick\")", self.type))
    end

    self.conditions = {}
    if data.conditions then
        for i = 1, #data.conditions do
            self.conditions[i] = u.parseExprBoolean(data.conditions[i], path, "conditions[" .. tostring(i) .. "]")
        end
    end
end



return CollectibleGeneratorConfig