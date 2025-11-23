-- Utilities for easier resource loading for Config Classes.

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")
local Expression = require("src.Expression")
local CollectibleConfig = require("src.Configs.Collectible")
local CollectibleEffectConfig = require("src.Configs.CollectibleEffect")
local CollectibleGeneratorConfig = require("src.Configs.CollectibleGenerator")
local ColorGeneratorConfig = require("src.Configs.ColorGenerator")
local GameEventConfig = require("src.Configs.GameEvent")
local LevelConfig = require("src.Configs.Level")
local LevelSequenceConfig = require("src.Configs.LevelSequence")
local LevelSetConfig = require("src.Configs.LevelSet")
local LevelTrainRulesConfig = require("src.Configs.LevelTrainRules")
local ParticleConfig = require("src.Configs.Particle")
local ParticleEffectConfig = require("src.Configs.ParticleEffect")
local ParticleEmitterConfig = require("src.Configs.ParticleEmitter")
local PathConfig = require("src.Configs.Path")
local PathEntityConfig = require("src.Configs.PathEntity")
local ProjectileConfig = require("src.Configs.Projectile")
local ScoreEventConfig = require("src.Configs.ScoreEvent")
local ShooterMovementConfig = require("src.Configs.ShooterMovement")
local SphereConfig = require("src.Configs.Sphere")
local SphereEffectConfig = require("src.Configs.SphereEffect")
local SphereSelectorConfig = require("src.Configs.SphereSelector")
local SpriteAtlasConfig = require("src.Configs.SpriteAtlas")
local VariableProvidersConfig = require("src.Configs.VariableProviders")

local utils = {}



-- HELPER FUNCTIONS
local function isValidExpression(data)
	return type(data) ~= "string" or (data:sub(1, 2) == "${" and data:sub(data:len(), data:len()) == "}")
end

---Returns `data` indexed by the provided path of fields.
---For example, providing `{"test", 1}` will return `data.test[1]`.
---Returns `nil` if at any point the value at the provided index doesn't exist.
---@param data any Data to be indexed.
---@param fields any[]? A list of indexes. If not specified, `data` itself is returned.
---@return any?
local function getDataValue(data, fields)
	if not fields then
		return data
	end
	for i, index in ipairs(fields) do
		data = data[index]
		if not data then
			return nil
		end
	end
	return data
end

---Turns the provided path of fields into a string representation.
---For example, providing `{"test", 1}` will return `"test[1]"`.
---@param fields any[]? A list of indexes. If not specified, the function will return `""`.
---@return string
local function getFieldPathStr(fields)
	if not fields then
		return ""
	end
	local str = ""
	for i, index in ipairs(fields) do
		if type(index) == "string" then
			if i > 1 then
				str = str .. "."
			end
			str = str .. index
		else
			str = str .. "[" .. tostring(index) .. "]"
		end
	end
	return str
end



---@return integer
function utils.parseInteger(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	assert(value, string.format("field %s is missing (integer expected)", getFieldPathStr(fields)))
	return value
end

---@return integer?
function utils.parseIntegerOpt(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	return value
end

---@return number
function utils.parseNumber(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	assert(value, string.format("field %s is missing (number expected)", getFieldPathStr(fields)))
	return value
end

---@return number?
function utils.parseNumberOpt(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	return value
end

---@return boolean
function utils.parseBoolean(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	assert(data ~= nil, string.format("field %s is missing (boolean expected)", getFieldPathStr(fields)))
	return value
end

---@return boolean?
function utils.parseBooleanOpt(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	return value
end

---@return string
function utils.parseString(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	assert(value, string.format("field %s is missing (string expected)", getFieldPathStr(fields)))
	return value
end

---@return string?
function utils.parseStringOpt(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	return value
end



---Parses a required Vector2 field for a config file.
---@param data table The data to be parsed.
---@param fields any[] A list of indexes specifying the path inside of the file.
---@return Vector2
function utils.parseVec2(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	assert(value, string.format("field %s is missing (Vector2 expected)", getFieldPathStr(fields)))
	return Vec2(value.x, value.y)
end

---Parses an optional Vector2 field for a config file.
---@param data table The data to be parsed.
---@param fields any[] A list of indexes specifying the path inside of the file.
---@return Vector2?
function utils.parseVec2Opt(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	return value and Vec2(value.x, value.y)
end

---@return Color
function utils.parseColor(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	assert(value, string.format("field %s is missing (Color expected)", getFieldPathStr(fields)))
	return Color(value.r, value.g, value.b)
end

---@return Color?
function utils.parseColorOpt(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	return value and Color(value.r, value.g, value.b)
end



---@return Expression
function utils.parseExprNumber(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	assert(value, string.format("field %s is missing (number expression expected)", getFieldPathStr(fields)))
	assert(isValidExpression(value), string.format("%s is not a vaild expression (format is ${<expression>})", value))
	return Expression(value)
end

---@return Expression?
function utils.parseExprNumberOpt(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	if value then
		assert(isValidExpression(value), string.format("%s is not a vaild expression (format is ${<expression>})", value))
	end
	return value and Expression(value)
end

---@return Expression
function utils.parseExprInteger(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	assert(value, string.format("field %s is missing (integer expression expected)", getFieldPathStr(fields)))
	assert(isValidExpression(value), string.format("%s is not a vaild expression (format is ${<expression>})", value))
	return Expression(value)
end

---@return Expression?
function utils.parseExprIntegerOpt(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	if value then
		assert(isValidExpression(value), string.format("%s is not a vaild expression (format is ${<expression>})", value))
	end
	return value and Expression(value)
end

---@return Expression
function utils.parseExprBoolean(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	assert(value, string.format("field %s is missing (boolean expression expected)", getFieldPathStr(fields)))
	assert(isValidExpression(value), string.format("%s is not a vaild expression (format is ${<expression>})", value))
	return Expression(value)
end

---@return Expression?
function utils.parseExprBooleanOpt(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	if value then
		assert(isValidExpression(value), string.format("%s is not a vaild expression (format is ${<expression>})", value))
	end
	return value and Expression(value)
end

---@return Expression
function utils.parseExprString(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	assert(value, string.format("field %s is missing (string expression expected)", getFieldPathStr(fields)))
	return Expression(value)
end

---@return Expression?
function utils.parseExprStringOpt(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	return value and Expression(value)
end

---@return Expression
function utils.parseExprVec2(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	assert(value, string.format("field %s is missing (Vector2 expression expected)", getFieldPathStr(fields)))
	assert(isValidExpression(value), string.format("%s is not a vaild expression (format is ${<expression>})", value))
	return Expression(value)
end

---@return Expression?
function utils.parseExprVec2Opt(data, base, path, fields)
	local value = getDataValue(data, fields) or getDataValue(base, fields)
	if value then
		assert(isValidExpression(value), string.format("%s is not a vaild expression (format is ${<expression>})", value))
	end
	return value and Expression(value)
end



---Internal function for class parsing logic.
---Returns a resource based on provided data.
---@param data string Path to the resource.
---@param path string Path to the config which will host the resource.
---@param fields any[] A list of indexes specifying the path inside of the file.
---@param resType string The type of the provided resource.
---@param getter function Resource getter which will return a resource if the resource path is provided. Intended to be `ResourceManager:get*()`.
---@return any
local function parseResource(data, base, path, fields, resType, getter)
	local value = getDataValue(data, fields)
	if value then
		return getter(_Res, value)
	end
	return assert(getDataValue(base, fields), string.format("%s: field %s is missing (%s expected)", path, getFieldPathStr(fields), resType))
end

---Internal function for class parsing logic.
---Returns an optional resource based on provided data.
---Returns `nil` if no data is provided.
---@param data string Path to the resource.
---@param path string Path to the config which will host the resource.
---@param fields any[] A list of indexes specifying the path inside of the file.
---@param resType string The type of the provided resource.
---@param getter function Resource getter which will return a resource if the resource path is provided. Intended to be `ResourceManager:get*()`.
---@return any?
local function parseResourceOpt(data, base, path, fields, resType, getter)
	local value = getDataValue(data, fields)
	if value then
		return getter(_Res, value)
	end
	return getDataValue(base, fields)
end



---@return Image
function utils.parseImage(data, base, path, fields)
	return parseResource(data, base, path, fields, "Image", _Res.getImage)
end

---@return Image?
function utils.parseImageOpt(data, base, path, fields)
	return parseResourceOpt(data, base, path, fields, "Image", _Res.getImage)
end

---@return Sound
function utils.parseSound(data, base, path, fields)
	return parseResource(data, base, path, fields, "Sound", _Res.getSound)
end

---@return Sound?
function utils.parseSoundOpt(data, base, path, fields)
	return parseResourceOpt(data, base, path, fields, "Sound", _Res.getSound)
end

---@return FontFile
function utils.parseFontFile(data, base, path, fields)
	return parseResource(data, base, path, fields, "FontFile", _Res.getFontFile)
end

---@return FontFile?
function utils.parseFontFileOpt(data, base, path, fields)
	return parseResourceOpt(data, base, path, fields, "FontFile", _Res.getFontFile)
end

---@return SoundEvent
function utils.parseSoundEvent(data, base, path, fields)
	return parseResource(data, base, path, fields, "SoundEvent", _Res.getSoundEvent)
end

---@return SoundEvent?
function utils.parseSoundEventOpt(data, base, path, fields)
	return parseResourceOpt(data, base, path, fields, "SoundEvent", _Res.getSoundEvent)
end

---@return Music
function utils.parseMusic(data, base, path, fields)
	return parseResource(data, base, path, fields, "Music", _Res.getMusic)
end

---@return Music?
function utils.parseMusicOpt(data, base, path, fields)
	return parseResourceOpt(data, base, path, fields, "Music", _Res.getMusic)
end



-- The following are moved to Config Classes, but use singleton getters instead:

---@return Sprite
function utils.parseSprite(data, base, path, fields)
	return parseResource(data, base, path, fields, "Sprite", _Res.getSprite)
end

---@return Sprite?
function utils.parseSpriteOpt(data, base, path, fields)
	return parseResourceOpt(data, base, path, fields, "Sprite", _Res.getSprite)
end

---@return Font
function utils.parseFont(data, base, path, fields)
	return parseResource(data, base, path, fields, "Font", _Res.getFont)
end

---@return Font?
function utils.parseFontOpt(data, base, path, fields)
	return parseResourceOpt(data, base, path, fields, "Font", _Res.getFont)
end

---@return ColorPalette
function utils.parseColorPalette(data, base, path, fields)
	return parseResource(data, base, path, fields, "Color Palette", _Res.getColorPalette)
end

---@return ColorPalette?
function utils.parseColorPaletteOpt(data, base, path, fields)
	return parseResourceOpt(data, base, path, fields, "Color Palette", _Res.getColorPalette)
end



---Internal function for class parsing logic.
---Returns an instance of Config Class based on provided data.
---@param data string|table Either a string which is a resource path or any raw resource data which will be used to construct an anonymous resource.
---@param path string Resource path which will be passed to the potentially created anonymous resource.
---@param fields any[] A list of indexes specifying the path inside of the file.
---@param resType string The type of the provided resource.
---@param getter function Resource getter which will return a resource if the resource path is provided. Intended to be `ResourceManager:get*Config()`.
---@param constructor any Resource constructor which will construct the anonymous resource if resource data is provided.
---@return table
local function parseClassConfig(data, base, path, fields, resType, getter, constructor)
	local value = getDataValue(data, fields)
	if value then
		if type(value) == "table" then
			return constructor(value, path, true)
		else
			return getter(_Res, value)
		end
	end
	return assert(getDataValue(base, fields), string.format("%s: field %s is missing (%s Config expected)", path, getFieldPathStr(fields), resType))
end

---Internal function for class parsing logic.
---Returns an optional instance of Config Class based on provided data.
---Returns `nil` if no data is provided.
---@param data string|table Either a string which is a resource path or any raw resource data which will be used to construct an anonymous resource.
---@param path string Resource path which will be passed to the potentially created anonymous resource.
---@param fields any[] A list of indexes specifying the path inside of the file.
---@param resType string The type of the provided resource.
---@param getter function Resource getter which will return a resource if the resource path is provided. Intended to be `ResourceManager:get*Config()`.
---@param constructor any Resource constructor which will construct the anonymous resource if resource data is provided.
---@return table?
local function parseClassConfigOpt(data, base, path, fields, resType, getter, constructor)
	local value = getDataValue(data, fields)
	if value then
		return parseClassConfig(data, base, path, fields, resType, getter, constructor)
	end
	return getDataValue(base, fields)
end



---@return CollectibleConfig
function utils.parseCollectibleConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "Collectible", _Res.getCollectibleConfig, CollectibleConfig)
end

---@return CollectibleConfig?
function utils.parseCollectibleConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "Collectible", _Res.getCollectibleConfig, CollectibleConfig)
end

---@return CollectibleEffectConfig
function utils.parseCollectibleEffectConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "CollectibleEffect", _Res.getCollectibleEffectConfig, CollectibleEffectConfig)
end

---@return CollectibleEffectConfig?
function utils.parseCollectibleEffectConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "CollectibleEffect", _Res.getCollectibleEffectConfig, CollectibleEffectConfig)
end

---@return CollectibleGeneratorConfig
function utils.parseCollectibleGeneratorConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "CollectibleGenerator", _Res.getCollectibleGeneratorConfig, CollectibleGeneratorConfig)
end

---@return CollectibleGeneratorConfig?
function utils.parseCollectibleGeneratorConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "CollectibleGenerator", _Res.getCollectibleGeneratorConfig, CollectibleGeneratorConfig)
end

---@return ColorGeneratorConfig
function utils.parseColorGeneratorConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "ColorGenerator", _Res.getColorGeneratorConfig, ColorGeneratorConfig)
end

---@return ColorGeneratorConfig?
function utils.parseColorGeneratorConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "ColorGenerator", _Res.getColorGeneratorConfig, ColorGeneratorConfig)
end

---@return GameEventConfig
function utils.parseGameEventConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "GameEvent", _Res.getGameEventConfig, GameEventConfig)
end

---@return GameEventConfig?
function utils.parseGameEventConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "GameEvent", _Res.getGameEventConfig, GameEventConfig)
end

---@return LevelConfig
function utils.parseLevelConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "Level", _Res.getLevelConfig, LevelConfig)
end

---@return LevelConfig?
function utils.parseLevelConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "Level", _Res.getLevelConfig, LevelConfig)
end

---@return LevelSequenceConfig
function utils.parseLevelSequenceConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "LevelSequence", _Res.getLevelSequenceConfig, LevelSequenceConfig)
end

---@return LevelSequenceConfig?
function utils.parseLevelSequenceConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "LevelSequence", _Res.getLevelSequenceConfig, LevelSequenceConfig)
end

---@return LevelSetConfig
function utils.parseLevelSetConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "LevelSet", _Res.getLevelSetConfig, LevelSetConfig)
end

---@return LevelSetConfig?
function utils.parseLevelSetConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "LevelSet", _Res.getLevelSetConfig, LevelSetConfig)
end

---@return LevelTrainRulesConfig
function utils.parseLevelTrainRulesConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "LevelTrainRules", _Res.getLevelTrainRulesConfig, LevelTrainRulesConfig)
end

---@return LevelTrainRulesConfig?
function utils.parseLevelTrainRulesConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "LevelTrainRules", _Res.getLevelTrainRulesConfig, LevelTrainRulesConfig)
end

---@return ParticleConfig
function utils.parseParticleConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "Particle", _Res.getParticleConfig, ParticleConfig)
end

---@return ParticleConfig?
function utils.parseParticleConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "Particle", _Res.getParticleConfig, ParticleConfig)
end

---@return ParticleEffectConfig
function utils.parseParticleEffectConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "ParticleEffect", _Res.getParticleEffectConfig, ParticleEffectConfig)
end

---@return ParticleEffectConfig?
function utils.parseParticleEffectConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "ParticleEffect", _Res.getParticleEffectConfig, ParticleEffectConfig)
end

---@return ParticleEmitterConfig
function utils.parseParticleEmitterConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "ParticleEmitter", _Res.getParticleEmitterConfig, ParticleEmitterConfig)
end

---@return ParticleEmitterConfig?
function utils.parseParticleEmitterConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "ParticleEmitter", _Res.getParticleEmitterConfig, ParticleEmitterConfig)
end

---@return PathConfig
function utils.parsePathConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "Path", _Res.getPathConfig, PathConfig)
end

---@return PathConfig?
function utils.parsePathConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "Path", _Res.getPathConfig, PathConfig)
end

---@return PathEntityConfig
function utils.parsePathEntityConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "PathEntity", _Res.getPathEntityConfig, PathEntityConfig)
end

---@return PathEntityConfig?
function utils.parsePathEntityConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "PathEntity", _Res.getPathEntityConfig, PathEntityConfig)
end

---@return ProjectileConfig
function utils.parseProjectileConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "Projectile", _Res.getProjectileConfig, ProjectileConfig)
end

---@return ProjectileConfig?
function utils.parseProjectileConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "Projectile", _Res.getProjectileConfig, ProjectileConfig)
end

---@return ScoreEventConfig
function utils.parseScoreEventConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "ScoreEvent", _Res.getScoreEventConfig, ScoreEventConfig)
end

---@return ScoreEventConfig?
function utils.parseScoreEventConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "ScoreEvent", _Res.getScoreEventConfig, ScoreEventConfig)
end

---@return ShooterMovementConfig
function utils.parseShooterMovementConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "ShooterMovement", _Res.getShooterMovementConfig, ShooterMovementConfig)
end

---@return ShooterMovementConfig?
function utils.parseShooterMovementConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "ShooterMovement", _Res.getShooterMovementConfig, ShooterMovementConfig)
end

---@return SphereConfig
function utils.parseSphereConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "Sphere", _Res.getSphereConfig, SphereConfig)
end

---@return SphereConfig?
function utils.parseSphereConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "Sphere", _Res.getSphereConfig, SphereConfig)
end

---@return SphereEffectConfig
function utils.parseSphereEffectConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "SphereEffect", _Res.getSphereEffectConfig, SphereEffectConfig)
end

---@return SphereEffectConfig?
function utils.parseSphereEffectConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "SphereEffect", _Res.getSphereEffectConfig, SphereEffectConfig)
end

---@return SphereSelectorConfig
function utils.parseSphereSelectorConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "SphereSelector", _Res.getSphereSelectorConfig, SphereSelectorConfig)
end

---@return SphereSelectorConfig?
function utils.parseSphereSelectorConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "SphereSelector", _Res.getSphereSelectorConfig, SphereSelectorConfig)
end

---@return SpriteAtlasConfig
function utils.parseSpriteAtlasConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "SpriteAtlas", _Res.getSpriteAtlasConfig, SpriteAtlasConfig)
end

---@return SpriteAtlasConfig?
function utils.parseSpriteAtlasConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "SpriteAtlas", _Res.getSpriteAtlasConfig, SpriteAtlasConfig)
end

---@return VariableProvidersConfig
function utils.parseVariableProvidersConfig(data, base, path, fields)
	return parseClassConfig(data, base, path, fields, "VariableProviders", _Res.getVariableProvidersConfig, VariableProvidersConfig)
end

---@return VariableProvidersConfig?
function utils.parseVariableProvidersConfigOpt(data, base, path, fields)
	return parseClassConfigOpt(data, base, path, fields, "VariableProviders", _Res.getVariableProvidersConfig, VariableProvidersConfig)
end





return utils