local f = {}



-- path example: games/Luxor/
function f.main(path)
  -- Load Config
  local config = loadJson(path .. "config.json")

  -- Bump version
  config.engineVersion = "v0.30.0"

  -- Save Config
  saveJson(path .. "config.json", config)
end



return f
