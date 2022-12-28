local class = require "com/class"

---@class ShooterConfig
---@overload fun(data):ShooterConfig
local ShooterConfig = class:derive("ShooterConfig")

local Vec2 = require("src/Essentials/Vector2")
local ShooterMovementConfig = require("src/Configs/ShooterMovement")



---Constructs a new Shooter Config.
---@param data table Raw data parsed from `config/shooters/*.json`.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function ShooterConfig:new(data, path)
    self._path = path

    self.movement = ShooterMovementConfig(data.movement, path)

    self.sprite = _Game.resourceManager:getSprite(data.sprite)
    self.shadowSprite = _Game.resourceManager:getSprite(data.shadowSprite)

    self.reticle = {
        ---@type Sprite?
        sprite = data.reticle.sprite and _Game.resourceManager:getSprite(data.reticle.sprite),
        ---@type Sprite?
        nextBallSprite = data.reticle.nextBallSprite and _Game.resourceManager:getSprite(data.reticle.nextBallSprite),
        ---@type Vector2?
        nextBallOffset = _ParseVec2(data.reticle.nextBallOffset),
        ---@type Sprite?
        radiusSprite = data.reticle.radiusSprite and _Game.resourceManager:getSprite(data.reticle.radiusSprite)
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

    ---@type string
    self.speedShotParticle = data.speedShotParticle
    ---@type number
    self.shootSpeed = data.shootSpeed
    ---@type Vector2
    self.hitboxSize = _ParseVec2(data.hitboxSize) or Vec2()
end



return ShooterConfig