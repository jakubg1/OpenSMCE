local class = require "com.class"

---@class ScoreEventConfig
---@overload fun(data, path):ScoreEventConfig
local ScoreEventConfig = class:derive("ScoreEventConfig")

local u = require("src.Configs.utils")



---Constructs a new Score Event Config.
---@param data table Raw score event data.
---@param path string Path to the file. The file is not loaded here, but is used in error messages.
function ScoreEventConfig:new(data, path)
    self.score = u.parseExprInteger(data.score, path, "score")
    self.text = u.parseExprStringOpt(data.text, path, "text")
    self.font = u.parseFontOpt(data.font, path, "font")
end



return ScoreEventConfig