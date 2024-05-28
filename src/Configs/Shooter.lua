local class = require "com.class"

---@class ShooterConfig
---@overload fun(data, path):ShooterConfig
local ShooterConfig = class:derive("ShooterConfig")

local u = require("src.Configs.utils")
local usmc = require("src.Configs.utils_smc")
local Vec2 = require("src.Essentials.Vector2")



---Constructs a new Shooter Config.
---@param data table Raw data parsed from `config/shooters/*.json`.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function ShooterConfig:new(data, path)
    self.movement = usmc.parseShooterMovementConfig(data.movement, path, "movement")
    self.sprite = u.parseSprite(data.sprite, path, "sprite")
    self.spriteOffset = u.parseVec2Opt(data.spriteOffset, path, "spriteOffset") or Vec2()
    self.spriteAnchor = u.parseVec2Opt(data.spriteAnchor, path, "spriteAnchor") or Vec2(0.5, 0)
    self.shadowSprite = u.parseSpriteOpt(data.shadowSprite, path, "shadowSprite")
    self.shadowSpriteOffset = u.parseVec2Opt(data.shadowSpriteOffset, path, "shadowSpriteOffset") or Vec2(8)
    self.shadowSpriteAnchor = u.parseVec2Opt(data.shadowSpriteAnchor, path, "shadowSpriteAnchor") or Vec2(0.5, 0)
    self.ballPos = u.parseVec2Opt(data.ballPos, path, "ballPos") or Vec2(0, 5)

    self.nextBallSprites = {}
    for n, nextBallData in pairs(data.nextBallSprites) do
        local nextBall = {
            sprite = u.parseSprite(nextBallData.sprite, path, "nextBallSprites." .. tostring(n) .. ".sprite"),
            spriteAnimationSpeed = u.parseNumberOpt(nextBallData.spriteAnimationSpeed, path, "nextBallSprites." .. tostring(n) .. ".spriteAnimationSpeed")
        }
        self.nextBallSprites[tonumber(n)] = nextBall
    end

    self.nextBallOffset = u.parseVec2Opt(data.nextBallOffset, path, "nextBallOffset") or Vec2(0, 21)
    self.nextBallAnchor = u.parseVec2Opt(data.nextBallAnchor, path, "nextBallAnchor") or Vec2(0.5, 0)

    self.reticle = {}
    if data.reticle then
        self.reticle.sprite = u.parseSpriteOpt(data.reticle.sprite, path, "reticle.sprite")
        self.reticle.nextBallSprite = u.parseSpriteOpt(data.reticle.nextBallSprite, path, "reticle.nextBallSprite")
        self.reticle.nextBallOffset = u.parseVec2Opt(data.reticle.nextBallOffset, path, "reticle.nextBallOffset")
        self.reticle.radiusSprite = u.parseSpriteOpt(data.reticle.radiusSprite, path, "reticle.radiusSprite")
        self.reticle.colorFadeTime = u.parseNumberOpt(data.reticle.colorFadeTime, path, "reticle.colorFadeTime")
        self.reticle.nextColorFadeTime = u.parseNumberOpt(data.reticle.nextColorFadeTime, path, "reticle.nextColorFadeTime")
    end

    self.speedShotBeam = {}
    self.speedShotBeam.sprite = u.parseSprite(data.speedShotBeam.sprite, path, "speedShotBeam.sprite")
    self.speedShotBeam.fadeTime = u.parseNumber(data.speedShotBeam.fadeTime, path, "speedShotBeam.fadeTime")
    self.speedShotBeam.renderingType = u.parseString(data.speedShotBeam.renderingType, path, "speedShotBeam.renderingType")
    self.speedShotBeam.colored = u.parseBoolean(data.speedShotBeam.colored, path, "speedShotBeam.colored")

    self.sounds = {}
    if data.sounds then
        self.sounds.sphereSwap = u.parseSoundEvent(data.sounds.sphereSwap, path, "sounds.sphereSwap")
        self.sounds.sphereFill = u.parseSoundEvent(data.sounds.sphereFill, path, "sounds.sphereFill")
    end

    self.speedShotParticle = u.parseParticle(data.speedShotParticle, path, "speedShotParticle")
    self.shotCooldown = u.parseNumberOpt(data.shotCooldown, path, "shotCooldown") or 0
    self.shotCooldownFade = u.parseNumberOpt(data.shotCooldownFade, path, "shotCooldownFade") or 0
    self.multishot = u.parseBooleanOpt(data.multishot, path, "multishot") or false
    self.destroySphereOnFail = u.parseBooleanOpt(data.destroySphereOnFail, path, "destroySphereOnFail") or false
    self.shootSpeed = u.parseNumber(data.shootSpeed, path, "shootSpeed")
    self.hitboxOffset = u.parseVec2Opt(data.hitboxOffset, path, "hitboxOffset") or Vec2()
    self.hitboxSize = u.parseVec2Opt(data.hitboxSize, path, "hitboxSize") or Vec2()
end



return ShooterConfig