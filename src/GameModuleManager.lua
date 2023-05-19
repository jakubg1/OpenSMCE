local class = require "com.class"

---This class will be soon deprecated, and thus will not be documented.
---In order for this class to be deleted, improved Sound Events must be implemented.
---@class GameModuleManager
---@overload fun():GameModuleManager
local GameModuleManager = class:derive("GameModuleManager")



function GameModuleManager:new()
	self.game = self:loadModule("game")
	MOD_GAME = self.game
end



function GameModuleManager:loadModule(name)
	_Log:printt("GameModuleManager", string.format("Loading Module: %s", name))
	local f = function() return require(string.format("games.%s.modules.%s", _Game.name, name)) end
	local success, mod = pcall(f)
	if success then
		_Log:printt("GameModuleManager", "Success!")
		return mod
	end
	-- if we're here, there's no module like that above
	_Log:printt("GameModuleManager", "No module found in game files, loading builtin module...")
	local mod = require(string.format("src.DefaultModules.%s", name))
	if mod then
		_Log:printt("GameModuleManager", "Success!")
		return mod
	end
end



return GameModuleManager
