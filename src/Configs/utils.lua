-- Utilities for easier resource loading for Config Classes.

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")
local Expression = require("src.Expression")
local CollectibleGeneratorConfig = require("src.Configs.CollectibleGenerator")
local ScoreEventConfig = require("src.Configs.ScoreEvent")
local ShooterMovementConfig = require("src.Configs.ShooterMovement")

local utils = {}



-- HELPER FUNCTIONS
local function isValidExpression(data)
	return type(data) ~= "string" or (data:sub(1, 2) == "${" and data:sub(data:len(), data:len()) == "}")
end



---@return integer
function utils.parseInteger(data, path, field)
	assert(data, string.format("field %s is missing (integer expected)", field))
	return data
end

---@return integer?
function utils.parseIntegerOpt(data, path, field)
	return data
end

---@return number
function utils.parseNumber(data, path, field)
	assert(data, string.format("field %s is missing (number expected)", field))
	return data
end

---@return number?
function utils.parseNumberOpt(data, path, field)
	return data
end

---@return boolean
function utils.parseBoolean(data, path, field)
	assert(data ~= nil, string.format("field %s is missing (boolean expected)", field))
	return data
end

---@return boolean?
function utils.parseBooleanOpt(data, path, field)
	return data
end

---@return string
function utils.parseString(data, path, field)
	assert(data, string.format("field %s is missing (string expected)", field))
	return data
end

---@return string?
function utils.parseStringOpt(data, path, field)
	return data
end



---Parses a required Vector2 field for a config file.
---@param data table The data to be parsed.
---@param field string The field name inside of the file.
---@return Vector2
function utils.parseVec2(data, path, field)
	assert(data, string.format("field %s is missing (Vector2 expected)", field))
	return Vec2(data.x, data.y)
end

---Parses an optional Vector2 field for a config file.
---@param data table The data to be parsed.
---@param field string The field name inside of the file.
---@return Vector2?
function utils.parseVec2Opt(data, path, field)
	return data and Vec2(data.x, data.y)
end



---@return Expression
function utils.parseExprInteger(data, path, field)
	assert(data, string.format("field %s is missing (integer expression expected)", field))
	assert(isValidExpression(data), string.format("%s is not a vaild expression (format is ${<expression>})", data))
	return Expression(data)
end

---@return Expression?
function utils.parseExprIntegerOpt(data, path, field)
	if data then
		assert(isValidExpression(data), string.format("%s is not a vaild expression (format is ${<expression>})", data))
	end
	return data and Expression(data)
end

---@return Expression
function utils.parseExprBoolean(data, path, field)
	assert(data, string.format("field %s is missing (boolean expression expected)", field))
	assert(isValidExpression(data), string.format("%s is not a vaild expression (format is ${<expression>})", data))
	return Expression(data)
end

---@return Expression?
function utils.parseExprBooleanOpt(data, path, field)
	if data then
		assert(isValidExpression(data), string.format("%s is not a vaild expression (format is ${<expression>})", data))
	end
	return data and Expression(data)
end

---@return Expression
function utils.parseExprString(data, path, field)
	assert(data, string.format("field %s is missing (string expression expected)", field))
	return Expression(data)
end

---@return Expression?
function utils.parseExprStringOpt(data, path, field)
	return data and Expression(data)
end



---@return Color
function utils.parseColor(data, path, field)
	assert(data, string.format("field %s is missing (Color expected)", field))
	return Color(data.r, data.g, data.b)
end

---@return Color?
function utils.parseColorOpt(data, path, field)
	return data and Color(data.r, data.g, data.b)
end

---@return Image
function utils.parseImage(data, path, field)
	assert(data, string.format("field %s is missing (Image expected)", field))
	return _Game.resourceManager:getImage(data)
end

---@return Image?
function utils.parseImageOpt(data, path, field)
	return data and _Game.resourceManager:getImage(data)
end

---@return Sprite
function utils.parseSprite(data, path, field)
	assert(data, string.format("field %s is missing (Sprite expected)", field))
	return _Game.resourceManager:getSprite(data)
end

---@return Sprite?
function utils.parseSpriteOpt(data, path, field)
	return data and _Game.resourceManager:getSprite(data)
end

---@return Sound
function utils.parseSound(data, path, field)
	assert(data, string.format("field %s is missing (Sound expected)", field))
	return _Game.resourceManager:getSound(data)
end

---@return Sound?
function utils.parseSoundOpt(data, path, field)
	return data and _Game.resourceManager:getSound(data)
end

---@return SoundEvent
function utils.parseSoundEvent(data, path, field)
	assert(data, string.format("field %s is missing (Sound Event expected)", field))
	return _Game.resourceManager:getSoundEvent(data)
end

---@return SoundEvent?
function utils.parseSoundEventOpt(data, path, field)
	return data and _Game.resourceManager:getSoundEvent(data)
end

---@return Music
function utils.parseMusic(data, path, field)
	assert(data, string.format("field %s is missing (Music expected)", field))
	return _Game.resourceManager:getMusic(data)
end

---@return Music?
function utils.parseMusicOpt(data, path, field)
	return data and _Game.resourceManager:getMusic(data)
end

---@return table
function utils.parseParticle(data, path, field)
	assert(data, string.format("field %s is missing (Particle expected)", field))
	return _Game.resourceManager:getParticle(data)
end

---@return table?
function utils.parseParticleOpt(data, path, field)
	return data and _Game.resourceManager:getParticle(data)
end

---@return Font
function utils.parseFont(data, path, field)
	assert(data, string.format("field %s is missing (Font expected)", field))
	return _Game.resourceManager:getFont(data)
end

---@return Font?
function utils.parseFontOpt(data, path, field)
	return data and _Game.resourceManager:getFont(data)
end

---@return ColorPalette
function utils.parseColorPalette(data, path, field)
	assert(data, string.format("field %s is missing (Color Palette expected)", field))
	return _Game.resourceManager:getColorPalette(data)
end

---@return ColorPalette?
function utils.parseColorPaletteOpt(data, path, field)
	return data and _Game.resourceManager:getColorPalette(data)
end



---@return CollectibleGeneratorConfig
function utils.parseCollectibleGeneratorConfig(data, path, field)
	assert(data, string.format("field %s is missing (Collectible Generator Config expected)", field))
	if type(data) == "string" then
		return _Game.resourceManager:getCollectibleGeneratorConfig(data)
	elseif type(data) == "table" then
		return CollectibleGeneratorConfig(data, path)
	end
	error(string.format("field %s has incorrect data (Collectible Generator Config or a reference to it expected)", field))
end

---@return CollectibleGeneratorConfig?
function utils.parseCollectibleGeneratorConfigOpt(data, path, field)
	if data then
		if type(data) == "string" then
			return _Game.resourceManager:getCollectibleGeneratorConfig(data)
		elseif type(data) == "table" then
			return CollectibleGeneratorConfig(data, path)
		end
	end
end

---@return ScoreEventConfig
function utils.parseScoreEventConfig(data, path, field)
	assert(data, string.format("field %s is missing (Score Event Config expected)", field))
	if type(data) == "string" then
		return _Game.resourceManager:getScoreEventConfig(data)
	elseif type(data) == "table" then
		return ScoreEventConfig(data, path)
	end
	error(string.format("field %s has incorrect data (Score Event Config or a reference to it expected)", field))
end

---@return ScoreEventConfig?
function utils.parseScoreEventConfigOpt(data, path, field)
	if data then
		if type(data) == "string" then
			return _Game.resourceManager:getScoreEventConfig(data)
		elseif type(data) == "table" then
			return ScoreEventConfig(data, path)
		end
	end
end

---@return ShooterMovementConfig
function utils.parseShooterMovementConfig(data, path, field)
	assert(data, string.format("field %s is missing (Shooter Movement Config expected)", field))
	return ShooterMovementConfig(data, path)
end

---@return ShooterMovementConfig?
function utils.parseShooterMovementConfigOpt(data, path, field)
	return data and ShooterMovementConfig(data, path)
end

---@return UI2AnimationConfig
function utils.parseUIAnimationConfig(data, path, field)
	assert(data, string.format("field %s is missing (UI2 Animation Config expected)", field))
	return _Game.resourceManager:getUIAnimationConfig(data)
end

---@return UI2AnimationConfig?
function utils.parseUIAnimationConfigOpt(data, path, field)
	return data and _Game.resourceManager:getUIAnimationConfig(data)
end

---@return UI2NodeConfig
function utils.parseUINodeConfig(data, path, field)
	assert(data, string.format("field %s is missing (UI2 Node Config expected)", field))
	return _Game.resourceManager:getUINodeConfig(data)
end

---@return UI2NodeConfig?
function utils.parseUINodeConfigOpt(data, path, field)
	return data and _Game.resourceManager:getUINodeConfig(data)
end

---@return UI2SequenceConfig
function utils.parseUISequenceConfig(data, path, field)
	assert(data, string.format("field %s is missing (UI2 Sequence Config expected)", field))
	return _Game.resourceManager:getUISequenceConfig(data)
end

---@return UI2SequenceConfig?
function utils.parseUISequenceConfigOpt(data, path, field)
	return data and _Game.resourceManager:getUISequenceConfig(data)
end





return utils