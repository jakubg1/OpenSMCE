local class = require "com.class"

---@class ScoreEventConfig
---@overload fun(data, path):ScoreEventConfig
local ScoreEventConfig = class:derive("ScoreEventConfig")



---Constructs a new Score Event Config.
---@param data table Raw score event data.
---@param path string Path to the file. The file is not loaded here, and it is not used in error messages, but some classes use it for saving data. TODO: Find an alternative.
function ScoreEventConfig:new(data, path)
    local u = _ConfigUtils

    self.score = u.parseExprInteger(data.score, path, "score")
    self.ignoreDifficultyMultiplier = u.parseBooleanOpt(data.ignoreDifficultyMultiplier, path, "ignoreDifficultyMultiplier")
    self.text = u.parseExprStringOpt(data.text, path, "text")
    self.font = u.parseFontOpt(data.font, path, "font")

    if data.fonts then
        self.fonts = {}
        self.fonts.options = {}
        for i = 1, #data.fonts.options do
            self.fonts.options[i] = u.parseFont(data.fonts.options[i], path, "fonts.options[" .. tostring(i) .. "]")
        end
        self.fonts.default = u.parseFont(data.fonts.default, path, "fonts.default")
        self.fonts.choice = u.parseExprInteger(data.fonts.choice, path, "fonts.choice")
    end
end



return ScoreEventConfig