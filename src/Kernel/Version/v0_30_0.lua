local f = {}



-- path example: games/Luxor/
function f.main(path)
  -- Load Config
  local config = loadJson(path .. "config.json")

  -- Bump version
  config.engineVersion = "v0.30.0"

  -- Add new necessary variables to sphere entries
  for sphereN, sphereData in pairs(config.spheres) do
    -- new interchangeable boolean option
    sphereData.interchangeable = true
    -- "matches" supported by lightning and fireballs
    if sphereData.shootBehavior.type == "lightning" or sphereData.hitBehavior.type == "fireball" then
      local t = {}
      for k, v in pairs(config.spheres) do
        local n = tonumber(k)
        if n ~= 0 then
          table.insert(t, n)
        end
      end
      sphereData.matches = t
    end
    -- new resetCombo and destroyParticle options for lightning
    if sphereData.shootBehavior.type == "lightning" then
      sphereData.shootBehavior.resetCombo = true
      sphereData.destroyParticle = "particles/lightning_beam.json"
    end
  end

  -- Add bonus scarab configuration
  config.gameplay.bonusScarab = {
    image = "img/game/vise.png",
    stepLength = 24,
    pointsPerStep = 50,
    speed = 1000,
    trailParticle = "particles/bonus_scarab_trail.json",
    trailParticleDistance = 24,
    destroyParticle = "particles/collapse_vise.json",
    scoreFont = "fonts/score0.json"
  }

  -- Move speed shot speed from shooter to powerup configuration
  local speedShotSpeed = config.gameplay.shooter.speedShotSpeed
  config.gameplay.shooter.speedShotSpeed = nil
  for powerupN, powerup in pairs(config.powerups) do
    for i, effect in ipairs(powerup.effects) do
      effect.speed = speedShotSpeed
    end
  end

  -- Save Config
  saveJson(path .. "config.json", config)
end



return f
