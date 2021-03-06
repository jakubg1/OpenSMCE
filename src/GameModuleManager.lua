local class = require "com/class"
local GameModuleManager = class:derive("GameModuleManager")



function GameModuleManager:new()
	self.game = self:loadModule("game")
	MOD_GAME = self.game
end



function GameModuleManager:loadModule(name)
	print(string.format("[GameModuleManager] Loading Module: %s", name))
	local f = function() return require(string.format("games/%s/modules/%s", game.name, name)) end
	local success, mod = pcall(f)
	if success then
		print("[GameModuleManager] Success!")
		return mod
	end
	-- if we're here, there's no module like that above
	print("[GameModuleManager] No module found in game files, loading builtin module...")
	local mod = require(string.format("src/DefaultModules/%s", name))
	if mod then
		print("[GameModuleManager] Success!")
		return mod
	end
end



return GameModuleManager
