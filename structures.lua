--- A list of structures (tables) that appear in the code.
-- THIS PAGE IS NOT A PART OF THE CODE ITSELF.
-- However, it's useful for understanding of some complex table structures that aren't considered classes.
-- @module Structures

--- Used as data for collectibles.
CollectibleData = {
	type = "powerup", -- A type of the collectible. Can be "coin", "gem" or "powerup".
	name = "colorbomb", -- Exists only when type = "powerup". A powerup name. Can be "slow", "stop", "reverse", "wild", "bomb", "lightning", "shotspeed" or "colorbomb".
	color = 3 -- Exists only when type = "gem" or when type = "powerup" and name = "colorbomb". A gem type or a color of the Color Bomb powerup.
}