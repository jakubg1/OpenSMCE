local class = require "com.class"

---@class ShooterConfig
---@overload fun(data, path):ShooterConfig
local ShooterConfig = class:derive("ShooterConfig")

local Vec2 = require("src.Essentials.Vector2")
local ShooterMovementConfig = require("src.Configs.ShooterMovement")



---Constructs a new Shooter Config.
---@param data table Raw data parsed from `config/shooters/*.json`.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function ShooterConfig:new(data, path)
    self._path = path



    self.movement = ShooterMovementConfig(data.movement, path)

    self.sprite = _Game.resourceManager:getSprite(data.sprite)
    ---@type Vector2
    self.spriteOffset = _ParseVec2(data.spriteOffset) or Vec2()
    ---@type Vector2
    self.spriteAnchor = _ParseVec2(data.spriteAnchor) or Vec2(0.5, 0)
    self.shadowSprite = _Game.resourceManager:getSprite(data.shadowSprite)
    ---@type Vector2
    self.shadowSpriteOffset = _ParseVec2(data.shadowSpriteOffset) or Vec2(8, 8)
    ---@type Vector2
    self.shadowSpriteAnchor = _ParseVec2(data.shadowSpriteAnchor) or Vec2(0.5, 0)
    ---@type Vector2
    self.ballPos = _ParseVec2(data.ballPos) or Vec2(0, 5)
    self.nextBallSprites = {}
    for n, nextBallData in pairs(data.nextBallSprites) do
        local nextBall = {
            ---@type Sprite
            sprite = _Game.resourceManager:getSprite(nextBallData.sprite),
            ---@type number
            spriteAnimationSpeed = nextBallData.spriteAnimationSpeed
        }
        self.nextBallSprites[tonumber(n)] = nextBall
    end
    ---@type Vector2
    self.nextBallOffset = _ParseVec2(data.nextBallOffset) or Vec2(0, 21)
    ---@type Vector2
    self.nextBallAnchor = _ParseVec2(data.nextBallAnchor) or Vec2(0.5, 0)

    self.reticle = {
        ---@type Sprite?
        sprite = data.reticle and data.reticle.sprite and _Game.resourceManager:getSprite(data.reticle.sprite),
        ---@type Sprite?
        nextBallSprite = data.reticle and data.reticle.nextBallSprite and _Game.resourceManager:getSprite(data.reticle.nextBallSprite),
        ---@type Vector2?
        nextBallOffset = data.reticle and _ParseVec2(data.reticle.nextBallOffset),
        ---@type Sprite?
        radiusSprite = data.reticle and data.reticle.radiusSprite and _Game.resourceManager:getSprite(data.reticle.radiusSprite),
        ---@type number?
        colorFadeTime = data.reticle and data.reticle.colorFadeTime,
        ---@type number?
        nextColorFadeTime = data.reticle and data.reticle.nextColorFadeTime
    }

    self.speedShotBeam = {
        sprite = _Game.resourceManager:getSprite(data.speedShotBeam.sprite),
        ---@type number
        fadeTime = data.speedShotBeam.fadeTime,
        ---@type string
        renderingType = data.speedShotBeam.renderingType,
        ---@type boolean
        colored = data.speedShotBeam.colored
    }

    self.sounds = {
        sphereSwap = data.sounds and data.sounds.sphereSwap or "sound_events/shooter_swap.json",
        sphereFill = data.sounds and data.sounds.sphereFill or "sound_events/shooter_fill.json"
    }

    ---@type string
    self.speedShotParticle = data.speedShotParticle
    ---@type number
    self.shotCooldown = data.shotCooldown or 0
    ---@type number
    self.shotCooldownFade = data.shotCooldownFade or 0
    ---@type boolean
    self.multishot = data.multishot or false
    ---@type boolean
    self.destroySphereOnFail = data.destroySphereOnFail or false
    ---@type number
    self.shootSpeed = data.shootSpeed
    ---@type Vector2
    self.hitboxOffset = _ParseVec2(data.hitboxOffset) or Vec2()
    ---@type Vector2
    self.hitboxSize = _ParseVec2(data.hitboxSize) or Vec2()
end



return ShooterConfig