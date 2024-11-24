local class = require "com.class"

---@class ShooterConfig
---@overload fun(data, path):ShooterConfig
local ShooterConfig = class:derive("ShooterConfig")

local Vec2 = require("src.Essentials.Vector2")



---Constructs a new Shooter Config.
---@param data table Raw data parsed from `config/shooters/*.json`.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function ShooterConfig:new(data, path)
    local u = _ConfigUtils

    self.movement = u.parseShooterMovementConfig(data.movement, path, "movement")
    self.sprite = u.parseSprite(data.sprite, path, "sprite")
    self.spriteOffset = u.parseVec2Opt(data.spriteOffset, path, "spriteOffset") or Vec2()
    self.spriteAnchor = u.parseVec2Opt(data.spriteAnchor, path, "spriteAnchor") or Vec2(0.5, 0)
    self.shadowSprite = u.parseSpriteOpt(data.shadowSprite, path, "shadowSprite")
    self.shadowSpriteOffset = u.parseVec2Opt(data.shadowSpriteOffset, path, "shadowSpriteOffset") or Vec2(8, 8)
    self.shadowSpriteAnchor = u.parseVec2Opt(data.shadowSpriteAnchor, path, "shadowSpriteAnchor") or Vec2(0.5, 0)

    self.spheres = {}
    for i = 1, #data.spheres do
        self.spheres[i] = {}
        self.spheres[i].pos = u.parseVec2(data.spheres[i].pos, path, "spheres[" .. tostring(i) .. "].pos")
        self.spheres[i].shotPos = u.parseVec2Opt(data.spheres[i].shotPos, path, "spheres[" .. tostring(i) .. "].shotPos")
    end

    self.nextBallSprites = {}
    for n, _ in pairs(data.nextBallSprites) do
        self.nextBallSprites[tonumber(n)] = {}
        self.nextBallSprites[tonumber(n)].sprite = u.parseSprite(data.nextBallSprites[n].sprite, path, "nextBallSprites." .. tostring(n) .. ".sprite")
        self.nextBallSprites[tonumber(n)].spriteAnimationSpeed = u.parseNumberOpt(data.nextBallSprites[n].spriteAnimationSpeed, path, "nextBallSprites." .. tostring(n) .. ".spriteAnimationSpeed")
    end

    self.nextBallOffset = u.parseVec2Opt(data.nextBallOffset, path, "nextBallOffset") or Vec2(0, 21)
    self.nextBallAnchor = u.parseVec2Opt(data.nextBallAnchor, path, "nextBallAnchor") or Vec2(0.5, 0)

    if data.reticle then
        self.reticle = {}
        self.reticle.sprite = u.parseSpriteOpt(data.reticle.sprite, path, "reticle.sprite")
        self.reticle.offset = u.parseVec2Opt(data.reticle.offset, path, "reticle.offset")
        self.reticle.nextBallSprite = u.parseSpriteOpt(data.reticle.nextBallSprite, path, "reticle.nextBallSprite")
        self.reticle.nextBallOffset = u.parseVec2Opt(data.reticle.nextBallOffset, path, "reticle.nextBallOffset")
        self.reticle.radiusSprite = u.parseSpriteOpt(data.reticle.radiusSprite, path, "reticle.radiusSprite")
        self.reticle.colorFadeTime = u.parseNumberOpt(data.reticle.colorFadeTime, path, "reticle.colorFadeTime")
        self.reticle.nextColorFadeTime = u.parseNumberOpt(data.reticle.nextColorFadeTime, path, "reticle.nextColorFadeTime")
    end

    self.sounds = {}
    self.sounds.sphereSwap = u.parseSoundEvent(data.sounds.sphereSwap, path, "sounds.sphereSwap")
    self.sounds.sphereFill = u.parseSoundEvent(data.sounds.sphereFill, path, "sounds.sphereFill")

    self.speedShotBeam = {}
    self.speedShotBeam.sprite = u.parseSprite(data.speedShotBeam.sprite, path, "speedShotBeam.sprite")
    self.speedShotBeam.fadeTime = u.parseNumber(data.speedShotBeam.fadeTime, path, "speedShotBeam.fadeTime")
    self.speedShotBeam.renderingType = u.parseString(data.speedShotBeam.renderingType, path, "speedShotBeam.renderingType")
    self.speedShotBeam.colored = u.parseBoolean(data.speedShotBeam.colored, path, "speedShotBeam.colored")

    self.speedShotParticle = u.parseString(data.speedShotParticle, path, "speedShotParticle")
    self.shotCooldown = u.parseNumberOpt(data.shotCooldown, path, "shotCooldown") or 0
    self.shotCooldownFade = u.parseNumberOpt(data.shotCooldownFade, path, "shotCooldownFade") or 0
    self.multishot = u.parseBooleanOpt(data.multishot, path, "multishot") or false
    self.destroySphereOnFail = u.parseBooleanOpt(data.destroySphereOnFail, path, "destroySphereOnFail") or false
    self.shootSpeed = u.parseNumber(data.shootSpeed, path, "shootSpeed")
    self.hitboxOffset = u.parseVec2Opt(data.hitboxOffset, path, "hitboxOffset") or Vec2()
    self.hitboxSize = u.parseVec2(data.hitboxSize, path, "hitboxSize")
end



return ShooterConfig