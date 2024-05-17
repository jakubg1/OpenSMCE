-- Temporary appendix to utils.lua to fix a circular reference. Will remove it once we make a better system.

local ShooterMovementConfig = require("src.Configs.ShooterMovement")

local utils = {}



---@return ShooterMovementConfig
function utils.parseShooterMovementConfig(data, path, field)
	assert(data, string.format("%s: field %s is missing (Shooter Movement Config expected)", path, field))
	return ShooterMovementConfig(data, path)
end

---@return ShooterMovementConfig?
function utils.parseShooterMovementConfigOpt(data, path, field)
	return data and ShooterMovementConfig(data, path)
end





return utils