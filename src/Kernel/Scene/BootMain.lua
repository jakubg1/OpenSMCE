local class = require "com/class"

---@class BootMain
---@overload fun(bootScreen):BootMain
local BootMain = class:derive("BootMain")

local Vec2 = require("src/Essentials/Vector2")
local Button = require("src/Kernel/UI/Button")



function BootMain:new(bootScreen)
  	self.bootScreen = bootScreen

	-- prepare fonts of various sizes
	self.font = love.graphics.newFont()
	self.fontBig = love.graphics.newFont(18)

	-- github url link
	self.url = "https://github.com/jakubg1/OpenSMCE"
	self.urlHovered = false
	self.urlHoverPos = Vec2(35, 174)
	self.urlHoverSize = Vec2(365, 25)

	-- game list
	self.gameButtons = {}
	self.gameButtonsOffset = 0
	self.selectedGame = nil

	-- buttons
	self.buttons = {
		pagePrev = Button("<", self.fontBig, Vec2(404, 266), Vec2(24, 28), function() self:prevPage() end),
		pageNext = Button(">", self.fontBig, Vec2(492, 266), Vec2(24, 28), function() self:nextPage() end),
		loadGame = Button("Start!", self.fontBig, Vec2(544, 472), Vec2(222, 24), function() self:loadSelectedGame() end),
		convertGame = Button("Convert!", self.fontBig, Vec2(544, 448), Vec2(222, 24), function() self:convertSelectedGame() end),
		settings = Button("Engine Settings", self.fontBig, Vec2(540, 530), Vec2(230, 24), function() self.bootScreen:setScene("settings") end),
		quit = Button("Exit", self.fontBig, Vec2(540, 554), Vec2(230, 24), function() love.event.quit() end)
	}
end



function BootMain:init()
	-- set buttons up
	self:initGameButtons()
	self.buttons.loadGame.visible = false
	self.buttons.convertGame.visible = false
end



function BootMain:initGameButtons()
	self.gameButtons = {}
	for i = 1, 8 do
		local id = i + self.gameButtonsOffset * 8
		local game = self.bootScreen.games[id]
		if not game then
			break
		end
		local button = Button(game.name, self.fontBig, Vec2(34, 280 + i * 24), Vec2(482, 24), function() self:selectGame(id) end)
		button.selected = self.selectedGame == id
		table.insert(self.gameButtons, button)
	end
end



function BootMain:update(dt)
	-- button hover
	for i, gameButton in ipairs(self.gameButtons) do
		gameButton:update(dt)
	end
	for i, button in pairs(self.buttons) do
		button:update(dt)
	end

	-- URL hover
	self.urlHovered = _MousePos.x > self.urlHoverPos.x and
					_MousePos.x < self.urlHoverPos.x + self.urlHoverSize.x and
					_MousePos.y > self.urlHoverPos.y and
					_MousePos.y < self.urlHoverPos.y + self.urlHoverSize.y
end



function BootMain:nextPage()
	if self.gameButtonsOffset == self:getPageCount() - 1 then
		return
	end
	self.gameButtonsOffset = self.gameButtonsOffset + 1
	self:initGameButtons()
end

function BootMain:prevPage()
	if self.gameButtonsOffset == 0 then
		return
	end
	self.gameButtonsOffset = self.gameButtonsOffset - 1
	self:initGameButtons()
end

function BootMain:getPageCount()
	return math.ceil(#self.bootScreen.games / 8)
end



function BootMain:selectGame(id)
	self.selectedGame = id
	self.buttons.loadGame.visible = self:getSelectedGameVersionStatus() ~= 3
	self.buttons.convertGame.visible = self:getSelectedGameVersionStatus() == 0
	self:initGameButtons()
end



function BootMain:getSelectedGameName()
  return self.bootScreen.games[self.selectedGame].name
end

function BootMain:getSelectedGameVersion()
	local c = self.bootScreen.games[self.selectedGame].config
  return c.engine_version or c.engineVersion
end

function BootMain:getSelectedGameVersionStatus()
  return self.bootScreen.versionManager:getVersionStatus(self:getSelectedGameVersion())
end

function BootMain:loadSelectedGame()
	_LoadGame(self:getSelectedGameName())
end

function BootMain:convertSelectedGame()
  self.bootScreen.versionManager:convertGame(self:getSelectedGameName(), self:getSelectedGameVersion())
  self.bootScreen:init()
end



function BootMain:draw()
	-- White color
	love.graphics.setColor(1, 1, 1)

	-----------------------------
	-- HEADER
	-----------------------------
	love.graphics.setFont(self.fontBig)
	love.graphics.print("OpenSMCE Boot Menu", 30, 25)
	local s = string.format("Version: %s (%s)", _VERSION_NAME, _VERSION)
	love.graphics.print(s, 770 - self.fontBig:getWidth(s), 25)
	s = string.format("Build %s", _BUILD_NUMBER)
	love.graphics.setFont(self.font)
	love.graphics.print(s, 770 - self.font:getWidth(s), 44)

	-----------------------------
	-- NOTES
	-----------------------------
	-- Warning text
	love.graphics.setColor(1, 0.2, 0.2)
	love.graphics.setFont(self.fontBig)
	love.graphics.print("WARNING", 45, 75)
	-- Warning contents
	love.graphics.setColor(1, 1, 0.2)
	love.graphics.setFont(self.font)
	love.graphics.print("This engine is in BETA DEVELOPMENT.\nThis version is dedicated to people who want to test the engine and examine it.\nThis version should not be treated like a full version yet, as the inner workings still may change heavily!\nRemember to post issues and feature suggestions at the following Github repository link.\nThank you for your support!", 45, 100)
	-- Github link
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(self.fontBig)
	love.graphics.print(self.url, 45, 175)
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 30, 60, 740, 150) -- frame

	-----------------------------
	-- GAME LIST
	-----------------------------
	love.graphics.print("Game List", 30, 270)
	love.graphics.print(string.format("%s / %s", self.gameButtonsOffset + 1, self:getPageCount()), 436, 270)
	for i, gameButton in ipairs(self.gameButtons) do
		gameButton:draw()
	end
	love.graphics.setColor(1, 1, 1)
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 30, 300, 490, 200) -- frame

	-----------------------------
	-- SELECTED GAME DATA
	-----------------------------
	love.graphics.print("Selected Game", 540, 270)
	if self.selectedGame then
		love.graphics.print(self.bootScreen.games[self.selectedGame].name, 544, 304)
		-- Version support
		local supportedVersion = self:getSelectedGameVersion()
    local versionStatus = self:getSelectedGameVersionStatus()
		love.graphics.setFont(self.font)

		if versionStatus == -1 then
			love.graphics.setColor(1, 1, 0)
			love.graphics.print(string.format("Unknown supported version!"), 544, 324)
    else
      love.graphics.print(string.format("Supported Version: %s", supportedVersion), 544, 324)
    end

		if versionStatus == 0 then
			love.graphics.setColor(1, 0.5, 0)
      love.graphics.print("This game is out of date!", 544, 338)
		elseif versionStatus == 1 then
			love.graphics.setColor(0, 1, 0)
      love.graphics.print("Your version is up to date!", 544, 338)
    elseif versionStatus == 2 then
			love.graphics.setColor(1, 0, 0)
      love.graphics.print("This game is intended to work with\na newer version of the engine!", 544, 338)
    elseif versionStatus == 3 then
			love.graphics.setColor(1, 0, 0)
      love.graphics.print("You have a too new engine version!\nYou can't convert this game to\nthis version!\n\nUse an older version of this engine\nin order to play this game.", 544, 338)
		end
	end
	love.graphics.setColor(1, 1, 1)
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 540, 300, 230, 200) -- frame

	-----------------------------
	-- FOOTER
	-----------------------------
	love.graphics.setFont(self.font)
	love.graphics.print("OpenSMCE is a short for Open-Source Sphere Matcher Community Engine.", 30, 525)
	love.graphics.print("Copyright (C) 2020-2022 jakubg1\nThis software is licensed under MIT license.", 30, 555)

	-----------------------------
	-- BUTTONS
	-----------------------------
	for i, button in pairs(self.buttons) do
		button:draw()
	end

	-----------------------------
	-- URL HOVERING
	-----------------------------
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

	-----------------------------
	-- DISCORD RICH PRESENCE STATUS
	-----------------------------
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(self.fontBig)
	love.graphics.print("Discord Integration: ", 30, 220)
	if _DiscordRPC.enabled and _DiscordRPC.connected then
		love.graphics.setColor(0, 1, 0)
		love.graphics.print(string.format("Connected! (%s)", _DiscordRPC.username), 210, 220)
	elseif _DiscordRPC.enabled and not _DiscordRPC.connected then
		love.graphics.setColor(1, 1, 0)
		love.graphics.print("Connecting...", 210, 220)
	elseif not _DiscordRPC.enabled and _DiscordRPC.connected then
		love.graphics.setColor(1, 0.5, 0)
		love.graphics.print("Disconnecting...", 210, 220)
	elseif not _DiscordRPC.enabled and not _DiscordRPC.connected then
		love.graphics.setColor(0.75, 0.75, 0.75)
		love.graphics.print("Inactive", 210, 220)
	end
end



function BootMain:mousereleased(x, y, button)
	-- Buttons
	for i, gameButton in ipairs(self.gameButtons) do
		gameButton:mousereleased(x, y, button)
	end
	for i, button in pairs(self.buttons) do
		button:mousereleased(x, y, button)
	end

	-- URL
	if self.urlHovered then
		love.system.openURL(self.url)
	end
end



return BootMain
