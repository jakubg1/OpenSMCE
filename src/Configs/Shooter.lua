--!!--
-- Auto-generated by DocLang Generator
-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE
-- in order to protect it from being overwritten!
--!!--

local class = require "com.class"

---@class ShooterConfig
---@overload fun(data, path, isAnonymous):ShooterConfig
local ShooterConfig = class:derive("ShooterConfig")

local Vec2 = require("src.Essentials.Vector2")

ShooterConfig.metadata = {
    schemaPath = "shooter.json"
}

---Constructs an instance of ShooterConfig.
---@param data table Raw data from a file.
---@param path string? Path to the file. Used for error messages and saving data.
---@param isAnonymous boolean? If `true`, this resource is anonymous and its path is invalid for saving data.
---@param base ShooterConfig? If specified, this resource extends the provided resource. Any missing fields are prepended from the base resource.
function ShooterConfig:new(data, path, isAnonymous, base)
    local u = _ConfigUtils
    self._path = path
    self._alias = data._alias
    self._isAnonymous = isAnonymous

    base = base or {}

    self.movement = u.parseShooterMovementConfig(data, base, path, {"movement"})
    self.sprite = u.parseSprite(data, base, path, {"sprite"})
    self.spriteOffset = u.parseVec2Opt(data, base, path, {"spriteOffset"}) or Vec2()
    self.spriteAnchor = u.parseVec2Opt(data, base, path, {"spriteAnchor"}) or Vec2(0.5, 0)
    self.shadowSprite = u.parseSpriteOpt(data, base, path, {"shadowSprite"})
    self.shadowSpriteOffset = u.parseVec2Opt(data, base, path, {"shadowSpriteOffset"}) or Vec2(8, 8)
    self.shadowSpriteAnchor = u.parseVec2Opt(data, base, path, {"shadowSpriteAnchor"}) or Vec2(0.5, 0)

    self.spheres = {}
    for i = 1, #data.spheres do
        self.spheres[i] = {}
        self.spheres[i].pos = u.parseVec2(data, base, path, {"spheres", i, "pos"})
        self.spheres[i].shotPos = u.parseVec2Opt(data, base, path, {"spheres", i, "shotPos"})
    end

    self.nextBallSprites = {}
    for n, _ in pairs(data.nextBallSprites) do
        self.nextBallSprites[tonumber(n)] = {}
        self.nextBallSprites[tonumber(n)].sprite = u.parseSprite(data, base, path, {"nextBallSprites", n, "sprite"})
        self.nextBallSprites[tonumber(n)].spriteAnimationSpeed = u.parseNumberOpt(data, base, path, {"nextBallSprites", n, "spriteAnimationSpeed"})
    end

    self.nextBallOffset = u.parseVec2Opt(data, base, path, {"nextBallOffset"}) or Vec2(0, 21)
    self.nextBallAnchor = u.parseVec2Opt(data, base, path, {"nextBallAnchor"}) or Vec2(0.5, 0)

    self.reticle = {}
    if data.reticle then
        self.reticle.sprite = u.parseSpriteOpt(data, base, path, {"reticle", "sprite"})
        self.reticle.offset = u.parseVec2Opt(data, base, path, {"reticle", "offset"})
        self.reticle.nextBallSprite = u.parseSpriteOpt(data, base, path, {"reticle", "nextBallSprite"})
        self.reticle.nextBallOffset = u.parseVec2Opt(data, base, path, {"reticle", "nextBallOffset"})
        self.reticle.radiusSprite = u.parseSpriteOpt(data, base, path, {"reticle", "radiusSprite"})
        self.reticle.colorFadeTime = u.parseNumberOpt(data, base, path, {"reticle", "colorFadeTime"})
        self.reticle.nextColorFadeTime = u.parseNumberOpt(data, base, path, {"reticle", "nextColorFadeTime"})
    end

    self.sounds = {}
    self.sounds.sphereSwap = u.parseSoundEvent(data, base, path, {"sounds", "sphereSwap"})
    self.sounds.sphereFill = u.parseSoundEvent(data, base, path, {"sounds", "sphereFill"})

    self.speedShotBeam = {}
    self.speedShotBeam.sprite = u.parseSprite(data, base, path, {"speedShotBeam", "sprite"})
    self.speedShotBeam.fadeTime = u.parseNumber(data, base, path, {"speedShotBeam", "fadeTime"})
    self.speedShotBeam.renderingType = u.parseString(data, base, path, {"speedShotBeam", "renderingType"})
    self.speedShotBeam.colored = u.parseBoolean(data, base, path, {"speedShotBeam", "colored"})

    self.speedShotParticle = u.parseParticleEffectConfig(data, base, path, {"speedShotParticle"})
    self.shotSpeed = u.parseNumber(data, base, path, {"shotSpeed"})
    self.shotCooldown = u.parseNumberOpt(data, base, path, {"shotCooldown"}) or 0
    self.shotCooldownFade = u.parseNumberOpt(data, base, path, {"shotCooldownFade"}) or 0
    self.multishot = u.parseBooleanOpt(data, base, path, {"multishot"}) == true
    self.autofire = u.parseBooleanOpt(data, base, path, {"autofire"}) == true
    self.destroySphereOnFail = u.parseBooleanOpt(data, base, path, {"destroySphereOnFail"}) == true

    if data.knockback then
        self.knockback = {}
        self.knockback.duration = u.parseNumber(data, base, path, {"knockback", "duration"})
        self.knockback.strength = u.parseNumber(data, base, path, {"knockback", "strength"})
        self.knockback.speedShotDuration = u.parseNumberOpt(data, base, path, {"knockback", "speedShotDuration"})
        self.knockback.speedShotStrength = u.parseNumberOpt(data, base, path, {"knockback", "speedShotStrength"})
    end

    self.hitboxOffset = u.parseVec2Opt(data, base, path, {"hitboxOffset"}) or Vec2()
    self.hitboxSize = u.parseVec2(data, base, path, {"hitboxSize"})
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function ShooterConfig.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a ShooterConfig by given path.
    ---@param reference string The path to the resource.
    ---@return ShooterConfig
    function ResourceManager:getShooterConfig(reference)
        return self:getResourceConfig(reference, "Shooter")
    end
end

return ShooterConfig