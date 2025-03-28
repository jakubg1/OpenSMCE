--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class SphereConfig
---@overload fun(data, path):SphereConfig
local SphereConfig = class:derive("SphereConfig")

local Vec2 = require("src.Essentials.Vector2")



---Constructs an instance of SphereConfig.
---@param data table Raw data from a file.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function SphereConfig:new(data, path)
    local u = _ConfigUtils
    self._path = path

    self.sprites = {}
    for i = 1, #data.sprites do
        self.sprites[i] = {}
        self.sprites[i].sprite = u.parseSprite(data.sprites[i].sprite, path, "sprites[" .. tostring(i) .. "].sprite")
        self.sprites[i].rotate = u.parseBooleanOpt(data.sprites[i].rotate, path, "sprites[" .. tostring(i) .. "].rotate") ~= false
        self.sprites[i].animationSpeed = u.parseNumberOpt(data.sprites[i].animationSpeed, path, "sprites[" .. tostring(i) .. "].animationSpeed")
        self.sprites[i].rollingSpeed = u.parseNumberOpt(data.sprites[i].rollingSpeed, path, "sprites[" .. tostring(i) .. "].rollingSpeed") or 0.63662
    end

    self.shadowSprite = u.parseSpriteOpt(data.shadowSprite, path, "shadowSprite")
    self.shadowOffset = u.parseVec2Opt(data.shadowOffset, path, "shadowOffset") or Vec2(4, 4)
    self.size = u.parseNumberOpt(data.size, path, "size") or 32
    self.idleParticle = u.parseParticleOpt(data.idleParticle, path, "idleParticle")
    self.holdParticle = u.parseParticleOpt(data.holdParticle, path, "holdParticle")
    self.destroyParticle = u.parseParticleOpt(data.destroyParticle, path, "destroyParticle")
    self.destroyCollectible = u.parseCollectibleGeneratorConfigOpt(data.destroyCollectible, path, "destroyCollectible")
    self.destroySound = u.parseSoundEventOpt(data.destroySound, path, "destroySound")
    self.destroyEvent = u.parseGameEventConfigOpt(data.destroyEvent, path, "destroyEvent")
    self.color = u.parseColorOpt(data.color, path, "color")
    self.colorPalette = u.parseColorPaletteOpt(data.colorPalette, path, "colorPalette")
    self.colorPaletteSpeed = u.parseNumberOpt(data.colorPaletteSpeed, path, "colorPaletteSpeed")
    self.swappable = u.parseBooleanOpt(data.swappable, path, "swappable") ~= false

    self.shotBehavior = {}
    self.shotBehavior.type = u.parseString(data.shotBehavior.type, path, "shotBehavior.type")
    if self.shotBehavior.type == "normal" then
        self.shotBehavior.amount = u.parseIntegerOpt(data.shotBehavior.amount, path, "shotBehavior.amount") or 1
        self.shotBehavior.spreadAngle = u.parseNumberOpt(data.shotBehavior.spreadAngle, path, "shotBehavior.spreadAngle") or 0
        self.shotBehavior.gameEvent = u.parseGameEventConfigOpt(data.shotBehavior.gameEvent, path, "shotBehavior.gameEvent")
    elseif self.shotBehavior.type == "destroySpheres" then
        self.shotBehavior.selector = u.parseSphereSelectorConfig(data.shotBehavior.selector, path, "shotBehavior.selector")
        self.shotBehavior.scoreEvent = u.parseScoreEventConfigOpt(data.shotBehavior.scoreEvent, path, "shotBehavior.scoreEvent")
        self.shotBehavior.scoreEventPerSphere = u.parseScoreEventConfigOpt(data.shotBehavior.scoreEventPerSphere, path, "shotBehavior.scoreEventPerSphere")
        self.shotBehavior.gameEvent = u.parseGameEventConfigOpt(data.shotBehavior.gameEvent, path, "shotBehavior.gameEvent")
        self.shotBehavior.gameEventPerSphere = u.parseGameEventConfigOpt(data.shotBehavior.gameEventPerSphere, path, "shotBehavior.gameEventPerSphere")
    else
        error(string.format("Unknown shotBehavior type: %s (expected \"normal\", \"destroySpheres\")", self.shotBehavior.type))
    end

    self.shotEffects = {}
    if data.shotEffects then
        for i = 1, #data.shotEffects do
            self.shotEffects[i] = u.parseCollectibleEffectConfig(data.shotEffects[i], path, "shotEffects[" .. tostring(i) .. "]")
        end
    end

    self.shotSpeed = u.parseNumberOpt(data.shotSpeed, path, "shotSpeed")
    self.shotCooldown = u.parseNumberOpt(data.shotCooldown, path, "shotCooldown")
    self.shotSound = u.parseSoundEventOpt(data.shotSound, path, "shotSound")

    self.hitBehavior = {}
    self.hitBehavior.type = u.parseString(data.hitBehavior.type, path, "hitBehavior.type")
    if self.hitBehavior.type == "normal" then
        self.hitBehavior.effects = {}
        if data.hitBehavior.effects then
            for i = 1, #data.hitBehavior.effects do
                self.hitBehavior.effects[i] = u.parseSphereEffectConfig(data.hitBehavior.effects[i], path, "hitBehavior.effects[" .. tostring(i) .. "]")
            end
        end
    elseif self.hitBehavior.type == "destroySpheres" then
        self.hitBehavior.selector = u.parseSphereSelectorConfig(data.hitBehavior.selector, path, "hitBehavior.selector")
        self.hitBehavior.scoreEvent = u.parseScoreEventConfigOpt(data.hitBehavior.scoreEvent, path, "hitBehavior.scoreEvent")
        self.hitBehavior.scoreEventPerSphere = u.parseScoreEventConfigOpt(data.hitBehavior.scoreEventPerSphere, path, "hitBehavior.scoreEventPerSphere")
        self.hitBehavior.gameEvent = u.parseGameEventConfigOpt(data.hitBehavior.gameEvent, path, "hitBehavior.gameEvent")
        self.hitBehavior.gameEventPerSphere = u.parseGameEventConfigOpt(data.hitBehavior.gameEventPerSphere, path, "hitBehavior.gameEventPerSphere")
        self.hitBehavior.pierce = u.parseBooleanOpt(data.hitBehavior.pierce, path, "hitBehavior.pierce")
    elseif self.hitBehavior.type == "recolorSpheres" then
        self.hitBehavior.selector = u.parseSphereSelectorConfig(data.hitBehavior.selector, path, "hitBehavior.selector")
        self.hitBehavior.color = u.parseExprInteger(data.hitBehavior.color, path, "hitBehavior.color")
        self.hitBehavior.particle = u.parseParticleOpt(data.hitBehavior.particle, path, "hitBehavior.particle")
        self.hitBehavior.pierce = u.parseBooleanOpt(data.hitBehavior.pierce, path, "hitBehavior.pierce")
    elseif self.hitBehavior.type == "splitAndPushBack" then
        self.hitBehavior.speed = u.parseNumber(data.hitBehavior.speed, path, "hitBehavior.speed")
        self.hitBehavior.pierce = u.parseBooleanOpt(data.hitBehavior.pierce, path, "hitBehavior.pierce")
    elseif self.hitBehavior.type == "applyEffect" then
        self.hitBehavior.selector = u.parseSphereSelectorConfig(data.hitBehavior.selector, path, "hitBehavior.selector")
        self.hitBehavior.effect = u.parseSphereEffectConfig(data.hitBehavior.effect, path, "hitBehavior.effect")
        self.hitBehavior.pierce = u.parseBooleanOpt(data.hitBehavior.pierce, path, "hitBehavior.pierce")
    else
        error(string.format("Unknown hitBehavior type: %s (expected \"normal\", \"destroySpheres\", \"recolorSpheres\", \"splitAndPushBack\", \"applyEffect\")", self.hitBehavior.type))
    end

    self.hitSound = u.parseSoundEventOpt(data.hitSound, path, "hitSound")
    self.type = u.parseStringOpt(data.type, path, "type")
    self.autofire = u.parseBooleanOpt(data.autofire, path, "autofire") == true

    self.matches = {}
    for i = 1, #data.matches do
        self.matches[i] = u.parseInteger(data.matches[i], path, "matches[" .. tostring(i) .. "]")
    end

    self.doesNotCollideWith = {}
    if data.doesNotCollideWith then
        for i = 1, #data.doesNotCollideWith do
            self.doesNotCollideWith[i] = u.parseInteger(data.doesNotCollideWith[i], path, "doesNotCollideWith[" .. tostring(i) .. "]")
        end
    end
end



return SphereConfig