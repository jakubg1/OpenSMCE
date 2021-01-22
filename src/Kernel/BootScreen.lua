local class = require "com/class"
local BootScreen = class:derive("BootScreen")

local Vec2 = require("src/Essentials/Vector2")
local Button = require("src/Kernel/UI/Button")

function BootScreen:new()
	-- prepare fonts of various sizes
	self.font = love.graphics.newFont()
	self.fontBig = love.graphics.newFont(18)
	
	-- github url link
	self.url = "https://github.com/jakubg1/OpenSMCE"
	self.urlHovered = false
	self.urlHoverPos = Vec2(35, 174)
	self.urlHoverSize = Vec2(365, 25)
	
	-- game list
	self.games = nil
	self.gameButtons = {}
end

function BootScreen:init()
	-- game list
	self.games = self:getGames()
	-- set buttons up
	for i, game in ipairs(self.games) do
		table.insert(self.gameButtons, Button(game, self.fontBig, Vec2(34, 280 + i * 24), Vec2(732, 24), function() loadGame(game) end))
	end
	
	-- discord rpc connection
	discordRPC:connect()
	discordRPC:setStatus("Boot Screen", nil, true)
end

function BootScreen:update(dt)
	-- game hover
	for i, gameButton in ipairs(self.gameButtons) do
		gameButton:update(dt)
	end
	
	-- URL hover
	self.urlHovered = mousePos.x > self.urlHoverPos.x and
					mousePos.x < self.urlHoverPos.x + self.urlHoverSize.x and
					mousePos.y > self.urlHoverPos.y and
					mousePos.y < self.urlHoverPos.y + self.urlHoverSize.y
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
		if pcall(function() loadJson("games/" .. folder .. "/config.json") end) then
			table.insert(games, folder)
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
	-- White color
	love.graphics.setColor(1, 1, 1)
	
	-- Header
	love.graphics.setFont(self.fontBig)
	love.graphics.print("OpenSMCE Boot Menu", 30, 30)
	love.graphics.print(string.format("Version: %s (%s)", VERSION_NAME, VERSION), 520, 30)
	
	-- Notes
	-- WARNING text
	love.graphics.setColor(1, 0.2, 0.2)
	love.graphics.print("WARNING", 45, 75)
	-- WARNING contents
	love.graphics.setColor(1, 1, 0.2)
	love.graphics.setFont(self.font)
	love.graphics.print("This engine is in BETA DEVELOPMENT.\nExpect that it will be full of bugs. This version is dedicated to people who want to test the engine and examine it.\nThis version should NOT be treated like a full version.\nRemember to post issues and feature suggestions at the following Github repository link.", 45, 100)
	-- Github link
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(self.fontBig)
	love.graphics.print(self.url, 45, 175)
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 30, 60, 740, 150) -- frame
	
	-- Game list
	love.graphics.print("Game List", 30, 270)
	for i, gameButton in ipairs(self.gameButtons) do
		gameButton:draw()
	end
	love.graphics.setColor(1, 1, 1)
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 30, 300, 740, 200) -- frame
	
	-- Footer
	love.graphics.setFont(self.font)
	love.graphics.print("OpenSMCE is a short for Open-Source Sphere Matcher Community Engine.", 30, 525)
	love.graphics.print("This work was brought to you by jakubg1\nLicensed under MIT license.", 30, 555)
	
	-- URL hovering
	if self.urlHovered then
		love.graphics.setColor(1, 1, 0)
	else
		love.graphics.setColor(0.4, 0.4, 0)
	end
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", self.urlHoverPos.x, self.urlHoverPos.y, self.urlHoverSize.x, self.urlHoverSize.y)
	-- if self.urlHovered then
		-- love.graphics.print("<--- Click here to open the page!", self.urlHoverPos.x + self.urlHoverSize.x + 20, self.urlHoverPos.y + 8, 0.1)
	-- end
	
	-- Discord Rich Presence status
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(self.fontBig)
	love.graphics.print("Discord Integration: ", 30, 220)
	if discordRPC.enabled and discordRPC.connected then
		love.graphics.setColor(0, 1, 0)
		love.graphics.print(string.format("Connected! (%s)", discordRPC.username), 210, 220)
	elseif discordRPC.enabled and not discordRPC.connected then
		love.graphics.setColor(1, 1, 0)
		love.graphics.print("Connecting...", 210, 220)
	elseif not discordRPC.enabled and discordRPC.connected then
		love.graphics.setColor(1, 0.5, 0)
		love.graphics.print("Disconnecting...", 210, 220)
	elseif not discordRPC.enabled and not discordRPC.connected then
		love.graphics.setColor(0.75, 0.75, 0.75)
		love.graphics.print("Inactive", 210, 220)
	end
end



function BootScreen:mousepressed(x, y, button)
	-- STUB
end

function BootScreen:mousereleased(x, y, button)
	-- Game
	for i, gameButton in ipairs(self.gameButtons) do
		gameButton:mousereleased(x, y, button)
	end
	-- URL
	if self.urlHovered then
		love.system.openURL(self.url)
	end
end

function BootScreen:keypressed(key)
	-- STUB
end

function BootScreen:keyreleased(key)
	-- STUB
end

return BootScreen