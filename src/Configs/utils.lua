-- Utilities for easier resource loading for Config Classes.

local Vec2 = require("src.Essentials.Vector2")
local Color = require("src.Essentials.Color")

local utils = {}



---@return integer
function utils.parseInteger(data, path, field)
	assert(data, string.format("%s: field %s is missing (integer expected)", path, field))
	return data
end

---@return integer?
function utils.parseIntegerOpt(data, path, field)
	return data
end

---@return number
function utils.parseNumber(data, path, field)
	assert(data, string.format("%s: field %s is missing (number expected)", path, field))
	return data
end

---@return number?
function utils.parseNumberOpt(data, path, field)
	return data
end

---@return boolean
function utils.parseBoolean(data, path, field)
	assert(data ~= nil, string.format("%s: field %s is missing (boolean expected)", path, field))
	return data
end

---@return boolean?
function utils.parseBooleanOpt(data, path, field)
	return data
end

---@return string
function utils.parseString(data, path, field)
	assert(data, string.format("%s: field %s is missing (string expected)", path, field))
	return data
end

---@return string?
function utils.parseStringOpt(data, path, field)
	return data
end



---Parses a required Vector2 field for a config file.
---@param data table The data to be parsed.
---@param path string The path to the file.
---@param field string The field name inside of the file.
---@return Vector2
function utils.parseVec2(data, path, field)
	assert(data, string.format("%s: field %s is missing (Vector2 expected)", path, field))
	return Vec2(data.x, data.y)
end

---Parses an optional Vector2 field for a config file.
---@param data table The data to be parsed.
---@param path string The path to the file.
---@param field string The field name inside of the file.
---@return Vector2?
function utils.parseVec2Opt(data, path, field)
	return data and Vec2(data.x, data.y)
end



---@return Color
function utils.parseColor(data, path, field)
	assert(data, string.format("%s: field %s is missing (Color expected)", path, field))
	return Color(data.r, data.g, data.b)
end

---@return Color?
function utils.parseColorOpt(data, path, field)
	return data and Color(data.r, data.g, data.b)
end

---@return Image
function utils.parseImage(data, path, field)
	assert(data, string.format("%s: field %s is missing (Image expected)", path, field))
	return _Game.resourceManager:getImage(data)
end

---@return Image?
function utils.parseImageOpt(data, path, field)
	return data and _Game.resourceManager:getImage(data)
end

---@return Sprite
function utils.parseSprite(data, path, field)
	assert(data, string.format("%s: field %s is missing (Sprite expected)", path, field))
	return _Game.resourceManager:getSprite(data)
end

---@return Sprite?
function utils.parseSpriteOpt(data, path, field)
	return data and _Game.resourceManager:getSprite(data)
end

---@return Sound
function utils.parseSound(data, path, field)
	assert(data, string.format("%s: field %s is missing (Sound expected)", path, field))
	return _Game.resourceManager:getSound(data)
end

---@return Sound?
function utils.parseSoundOpt(data, path, field)
	return data and _Game.resourceManager:getSound(data)
end

---@return SoundEvent
function utils.parseSoundEvent(data, path, field)
	assert(data, string.format("%s: field %s is missing (Sound Event expected)", path, field))
	return _Game.resourceManager:getSoundEvent(data)
end

---@return SoundEvent?
function utils.parseSoundEventOpt(data, path, field)
	return data and _Game.resourceManager:getSoundEvent(data)
end

---@return Music
function utils.parseMusic(data, path, field)
	assert(data, string.format("%s: field %s is missing (Music expected)", path, field))
	return _Game.resourceManager:getMusic(data)
end

---@return Music?
function utils.parseMusicOpt(data, path, field)
	return data and _Game.resourceManager:getMusic(data)
end

---@return table
function utils.parseParticle(data, path, field)
	assert(data, string.format("%s: field %s is missing (Particle expected)", path, field))
	return _Game.resourceManager:getParticle(data)
end

---@return table?
function utils.parseParticleOpt(data, path, field)
	return data and _Game.resourceManager:getParticle(data)
end

---@return Font
function utils.parseFont(data, path, field)
	assert(data, string.format("%s: field %s is missing (Font expected)", path, field))
	return _Game.resourceManager:getFont(data)
end

---@return Font?
function utils.parseFontOpt(data, path, field)
	return data and _Game.resourceManager:getFont(data)
end

---@return ColorPalette
function utils.parseColorPalette(data, path, field)
	assert(data, string.format("%s: field %s is missing (Color Palette expected)", path, field))
	return _Game.resourceManager:getColorPalette(data)
end

---@return ColorPalette?
function utils.parseColorPaletteOpt(data, path, field)
	return data and _Game.resourceManager:getColorPalette(data)
end

---@return UI2AnimationConfig
function utils.parseUIAnimationConfig(data, path, field)
	assert(data, string.format("%s: field %s is missing (UI2 Animation Config expected)", path, field))
	return _Game.resourceManager:getUIAnimationConfig(data)
end

---@return UI2AnimationConfig?
function utils.parseUIAnimationConfigOpt(data, path, field)
	return data and _Game.resourceManager:getUIAnimationConfig(data)
end

---@return UI2NodeConfig
function utils.parseUINodeConfig(data, path, field)
	assert(data, string.format("%s: field %s is missing (UI2 Node Config expected)", path, field))
	return _Game.resourceManager:getUINodeConfig(data)
end

---@return UI2NodeConfig?
function utils.parseUINodeConfigOpt(data, path, field)
	return data and _Game.resourceManager:getUINodeConfig(data)
end

---@return UI2SequenceConfig
function utils.parseUISequenceConfig(data, path, field)
	assert(data, string.format("%s: field %s is missing (UI2 Sequence Config expected)", path, field))
	return _Game.resourceManager:getUISequenceConfig(data)
end

---@return UI2SequenceConfig?
function utils.parseUISequenceConfigOpt(data, path, field)
	return data and _Game.resourceManager:getUISequenceConfig(data)
end





return utils