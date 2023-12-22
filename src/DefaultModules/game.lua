-- This is a default module file for OpenSMCE games.
-- You can override any, or all of the methods below.
-- To do so, copy this file to games/<game>/modules/ folder and start editing.
-- Keep in mind that more methods may be added, or existing changed in the future.
-- These script files will be automatically updated if needed by the engine.

-- All methods will be stored here.
local f = {}



-- ON MATCH METHODS
-- Parameters:
-- length (number) - How many spheres were destroyed.
-- comboLv (number) - A number of consecutive matches done by player.
-- chainLv (number) - A chain reaction level - how many matches were done in a row via magnetization.
-- comboBoost (boolean) - Whether the match was done by a player (a sphere was shot into).

-- This function returns parameters for Game:playSound() when matching. Used for sound robustness.
function f.matchSound(length, comboLv, chainLv, comboBoost)
  local soundID = math.min(math.max(length - 2, 1), 5)
  return {
    name = "sound_events/collapse_" .. tostring(soundID) .. ".json",
    pitch = 1 + chainLv * 0.1
  }
end



-- Now we need to carry all functions that we've inserted over to the engine.
return f
