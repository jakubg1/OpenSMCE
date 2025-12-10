local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")
local Button = require("src.BootScreen.UI.Button")

---@class BootMain
---@overload fun(bootScreen):BootMain
local BootMain = class:derive("BootMain")

function BootMain:new(bootScreen)
    self.bootScreen = bootScreen

    -- github url link
    self.url = "https://github.com/jakubg1/OpenSMCE"
    self.urlHovered = false
    self.urlHoverPos = Vec2(45, 174)
    self.urlHoverSize = Vec2(345, 25)

    -- game list
    self.gameButtons = {}
    self.gameButtonsOffset = 0
    self.selectedGame = nil

    -- joke!
    self.joke = false

    -- buttons
    self.buttons = {
        pagePrev = Button("<", _FONT_BIG, Vec2(404, 266), Vec2(24, 28), function() self:prevPage() end),
        pageNext = Button(">", _FONT_BIG, Vec2(492, 266), Vec2(24, 28), function() self:nextPage() end),
        loadGame = Button("Start!", _FONT_BIG, Vec2(544, 448), Vec2(222, 24), function() self:loadSelectedGame() end),
        editGame = Button("Edit Game", _FONT_BIG, Vec2(544, 472), Vec2(222, 24), function() self:editSelectedGame() end),
        settings = Button("Engine Settings", _FONT_BIG, Vec2(540, 530), Vec2(230, 24), function() self.bootScreen:setScene("settings") end),
        quit = Button("Exit", _FONT_BIG, Vec2(540, 554), Vec2(230, 24), function() love.event.quit() end),
    }

    if self.joke then
        self.buttons.fun = Button("Buy Now", _FONT_BIG, Vec2(45, 180), Vec2(200, 24), function() end)
        self.buttons.fun2 = Button("Already Paid", _FONT_BIG, Vec2(255, 180), Vec2(200, 24), function() end)
        self.buttons.fun3 = Button("More Engines", _FONT_BIG, Vec2(465, 180), Vec2(200, 24), function() end)
    end
end



function BootMain:init()
    -- set buttons up
    self:initGameButtons()
    self.buttons.loadGame.visible = false
    self.buttons.editGame.visible = false
end



function BootMain:initGameButtons()
    self.gameButtons = {}
    for i = 1, 8 do
        local id = i + self.gameButtonsOffset * 8
        local game = self.bootScreen.games[id]
        if not game then
            break
        end
        local button = Button(game.name, _FONT_BIG, Vec2(34, 280 + i * 24), Vec2(482, 24), function() self:selectGame(id) end)
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
    self.urlHovered = _Utils.isPointInsideBox(_MouseX, _MouseY, self.urlHoverPos.x, self.urlHoverPos.y, self.urlHoverSize.x, self.urlHoverSize.y)
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
    self.buttons.editGame.visible = self:getSelectedGameVersionStatus() ~= 3
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

function BootMain:editSelectedGame()
    _LoadGameEditor(self:getSelectedGameName())
end



function BootMain:draw()
    -- White color
    love.graphics.setColor(1, 1, 1)

    -----------------------------
    -- HEADER
    -----------------------------
    love.graphics.setFont(_FONT_BIG)
    love.graphics.print("OpenSMCE Boot Menu", 30, 22)
    local s = string.format("Version: %s (%s)", _VERSION_NAME, _VERSION)
    love.graphics.print(s, 770 - _FONT_BIG:getWidth(s), 22)

    love.graphics.setFont(_FONT)
    local s = "Unable to check the newest version!"
    love.graphics.setColor(0.5, 0.5, 0.5)
    if self.bootScreen.versionManager.newestVersionAvailable then
        s = string.format("Update available! (%s)", self.bootScreen.versionManager.newestVersion)
        love.graphics.setColor(1, 1, 0)
    elseif self.bootScreen.versionManager.newestVersion then
        s = "Up to date!"
        love.graphics.setColor(0, 1, 0)
    end
    love.graphics.print(s, 770 - _FONT:getWidth(s), 41)

    -----------------------------
    -- NOTES
    -----------------------------
    -- Frame
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 30, 60, 740, 150)
    if not self.joke then
        -- Warning text
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.setFont(_FONT_BIG)
        love.graphics.print("WARNING - BETA VERSION !!!", 45, 75)
        -- Warning contents
        love.graphics.setColor(1, 1, 0.2)
        love.graphics.setFont(_FONT)
        love.graphics.print("This version is not guaranteed to work properly.\nBreaking changes may occur at any time.\n\nThank you for your support!", 45, 100)
        -- Github link
        if self.urlHovered then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.2, 1, 1)
        end
        love.graphics.setFont(_FONT_BIG)
        love.graphics.print(self.url, 45, 175)
        love.graphics.setLineWidth(1)
        love.graphics.line(self.urlHoverPos.x, self.urlHoverPos.y + self.urlHoverSize.y, self.urlHoverPos.x + self.urlHoverSize.x, self.urlHoverPos.y + self.urlHoverSize.y)
    else
        -- Trial version (JOKE! THIS ENGINE WILL NEVER BE PAID)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(_FONT_BIG)
        love.graphics.print("Trial Version", 45, 75)
        love.graphics.setFont(_FONT)
        love.graphics.print("Welcome to the trial version of OpenSMCE!\nYou can test the engine as you like. However, when the time runs out, you will not be able to run the games anymore\nand you will have to purchase a license key for unlimited access.", 45, 100)
    
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", 45, 150, 710, 25)
        love.graphics.setColor(0.2, 0.8, 0.2)
        love.graphics.rectangle("fill", 45, 150, 710*58.5/60, 25)
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", 45, 150, 710, 25)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(_FONT_BIG)
        love.graphics.print("59 minutes remaining.", 300, 152)
    end

    -----------------------------
    -- GAME LIST
    -----------------------------
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Game List", 30, 270)
    for i, gameButton in ipairs(self.gameButtons) do
        gameButton:draw()
    end
    love.graphics.setColor(1, 1, 1)
    if #self.gameButtons == 0 then
        love.graphics.print("Looks like you don't have any games installed...", 65, 350)
        love.graphics.print("Install games to the \"games/\" directory", 100, 400)
        love.graphics.print("or convert the original Luxor game (see README.txt)!", 40, 420)
    end
    if self:getPageCount() <= 1 then
        self.buttons.pagePrev.visible = false
        self.buttons.pageNext.visible = false
    else
        love.graphics.print(string.format("%s / %s", self.gameButtonsOffset + 1, self:getPageCount()), 436, 270)
    end
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
        love.graphics.setFont(_FONT)

        if versionStatus == -1 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.print(string.format("Unknown supported version!"), 544, 324)
        else
            love.graphics.print(string.format("Supported Version: %s", supportedVersion), 544, 324)
        end

        if versionStatus == -1 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("\nThe engine will probably crash\nwhen you try to load this game.\n\n\nRun at your own risk!", 544, 338)
        elseif versionStatus == 0 then
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
            love.graphics.print("This game is incompatible!\n\n\nUse an older version of this engine\nin order to play this game.", 544, 338)
        end
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 540, 300, 230, 200) -- frame

    -----------------------------
    -- FOOTER
    -----------------------------
    love.graphics.setFont(_FONT)
    love.graphics.print("OpenSMCE is a short for Open-Source Sphere Matcher Community Engine.", 30, 525)
    love.graphics.print("Copyright (C) 2020-2025 jakubg1 & contributors\nThis software is licensed under MIT license.", 30, 555)

    -----------------------------
    -- BUTTONS
    -----------------------------
    for i, button in pairs(self.buttons) do
        button:draw()
    end

    -----------------------------
    -- DISCORD RICH PRESENCE STATUS
    -----------------------------
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(_FONT_BIG)
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
