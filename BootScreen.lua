--- A specific type of Game; is used for a game selection screen.
-- @classmod BootScreen



-- Class identification
local class = require "class"
local BootScreen = class:derive("BootScreen")

-- Include commons
local Vec2 = require("Essentials/Vector2")



--- Constructors
-- @section constructors

--- Object constructor.
-- Executed when this object is created.
function BootScreen:new()
	-- prepare fonts of various sizes
	self.font = love.graphics.newFont()
	self.fontBig = love.graphics.newFont(18)
	
	-- github url link
	self.url = "https://github.com/jakubg1/OpenSMCE"
	self.urlHovered = false
	self.urlHoverPos = Vec2(35, 204)
	self.urlHoverSize = Vec2(365, 25)
	
	-- game list
	self.games = self:getGames()
	self.gameHovered = nil
end



--- Callbacks
-- @section callbacks

--- An update callback.
-- @tparam number dt Delta time in seconds.
-- @see main.update
function BootScreen:update(dt)
	-- game hover
	self.gameHovered = nil
	for i, game in ipairs(self.games) do
		if mousePos.x > 34 and mousePos.x < 766 and mousePos.y > 280 + i * 24 and mousePos.y < 304 + i * 24 then
			self.gameHovered = game
			break
		end
	end
	
	-- URL hover
	self.urlHovered = mousePos.x > self.urlHoverPos.x and
					mousePos.x < self.urlHoverPos.x + self.urlHoverSize.x and
					mousePos.y > self.urlHoverPos.y and
					mousePos.y < self.urlHoverPos.y + self.urlHoverSize.y
end



--- A drawing callback.
-- @see main.draw
function BootScreen:draw()
	-- White color
	love.graphics.setColor(1, 1, 1)
	
	-- Header
	love.graphics.setFont(self.fontBig)
	love.graphics.print("OpenSMCE Boot Menu", 30, 30)
	love.graphics.print("Version: " .. VERSION, 560, 30)
	
	-- Notes
	-- WARNING text
	love.graphics.setColor(1, 0.2, 0.2)
	love.graphics.print("WARNING", 45, 75)
	-- WARNING contents
	love.graphics.setColor(1, 1, 0.2)
	love.graphics.setFont(self.font)
	love.graphics.print("This engine is still in EARLY BETA DEVELOPMENT.\nDON'T expect it to be full of features, DO expect it will be full of bugs.\nThis version is dedicated to people who want to test the engine and examine it.\nHowever, you are modifying the game files at your own risk!! It may break, and I'm aware of that.\nThis version should NOT be treated like a full version. It's still far from it.\nRemember to post issues and feature suggestions at the following Github repository link.\nHowever, bear in mind I'm not taking suggestions for now. Keep them for later, now I'm working on crucial things.", 45, 100)
	-- Github link
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(self.fontBig)
	love.graphics.print(self.url, 45, 205)
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 30, 60, 740, 180) -- frame
	
	-- Game list
	love.graphics.print("Game List", 30, 270)
	love.graphics.setLineWidth(1)
	for i, game in ipairs(self.games) do
		if game == self.gameHovered then
			love.graphics.setColor(0.8, 0.8, 0.8)
		else
			love.graphics.setColor(0.4, 0.4, 0.4)
		end
		love.graphics.rectangle("fill", 34, 280 + i * 24, 732, 24)
		love.graphics.setColor(0.2, 0.2, 0.2)
		love.graphics.rectangle("line", 34, 280 + i * 24, 732, 24)
		love.graphics.setColor(0, 0, 0)
		love.graphics.print(game, 38, 282 + i * 24)
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
	if self.urlHovered then
		love.graphics.print("<--- Click here to open the page!", self.urlHoverPos.x + self.urlHoverSize.x + 20, self.urlHoverPos.y + 8, 0.1)
	end
end



--- Mouse press callback.
-- @tparam number x X coordinate where the mouse was when a button was pressed.
-- @tparam number y Y coordinate where the mouse was when a button was pressed.
-- @tparam number button Which mouse button was pressed.
-- @see main.mousepressed
function BootScreen:mousepressed(x, y, button)
	-- STUB
end



--- Mouse release callback.
-- @tparam number x X coordinate where the mouse was when a button was released.
-- @tparam number y Y coordinate where the mouse was when a button was released.
-- @tparam number button Which mouse button was released.
-- @see main.mousereleased
function BootScreen:mousereleased(x, y, button)
	-- Game
	if self.gameHovered then
		loadGame(self.gameHovered)
	end
	-- URL
	if self.urlHovered then
		love.system.openURL(self.url)
	end
end



--- Key press callback.
-- @tparam string key Which key was pressed.
-- @see main.keypressed
function BootScreen:keypressed(key)
	-- STUB
end



--- Key release callback.
-- @tparam string key Which key was pressed.
-- @see main.keyreleased
function BootScreen:keyreleased(key)
	-- STUB
end



--- @section end

--- Scans the games directory and returns valid game directories.
-- @treturn {string,...} List of valid game directories. For a folder to be a valid game directory, it must contain a config.json file with a valid JSON structure.
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



return BootScreen