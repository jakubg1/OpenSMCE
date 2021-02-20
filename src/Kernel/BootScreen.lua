local class = require "com/class"
local BootScreen = class:derive("BootScreen")

local Vec2 = require("src/Essentials/Vector2")
local Button = require("src/Kernel/UI/Button")

local BootMain = require("src/Kernel/Scene/BootMain")

function BootScreen:new()
	-- game list
	self.games = nil

	self.mainScene = BootMain(self)
end

function BootScreen:init()
	-- game list
	self.games = self:getGames()

	-- init the main screen
	self.mainScene:init()

	-- discord rpc connection
	discordRPC:connect()
	discordRPC:setStatus(string.format("Boot Screen - Version: %s", VERSION_NAME), nil, true)
end

function BootScreen:update(dt)
	self.mainScene:update(dt)
end

function BootScreen:getGames()
	-- A given folder in the "games" folder is considered a valid game when it contains a "config.json" file with valid JSON structure.

	local games = {}

	-- If it's compiled /fused/, this piece of code is therefore needed to be able to read the external files
	if love.filesystem.isFused() then
		print("This is a compiled version. Mounting games...")
		local success = love.filesystem.mount(love.filesystem.getSourceBaseDirectory(), "")
		if not success then error("Failed to read the game list. Report this error to a developer.") end
	end
	-- Now we can access the games directory regardless of whether it's fused or not.
	local folders = love.filesystem.getDirectoryItems("games")
	for i, folder in ipairs(folders) do
		-- We check whether we can open the config.json file. If not, we skip the name.
		print("Checking folder \"" .. folder .. "\"...")
		local success, result = pcall(function() return loadJson("games/" .. folder .. "/config.json") end)
		if success then
			table.insert(games, {name = folder, config = result})
			print("SUCCESS!")
		else
			print("FAIL!")
		end
	end
	-- After the reading process, we can unmount the listing again.
	love.filesystem.unmount(love.filesystem.getSourceBaseDirectory())

	return games
end

function BootScreen:draw()
	self.mainScene:draw()
end



function BootScreen:mousepressed(x, y, button)
	-- STUB
end

function BootScreen:mousereleased(x, y, button)
	self.mainScene:mousereleased(x, y, button)
end

function BootScreen:keypressed(key)
	-- STUB
end

function BootScreen:keyreleased(key)
	-- STUB
end

return BootScreen
