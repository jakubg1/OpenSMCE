local class = require "com.class"

---@class CrashScreen
---@overload fun(err):CrashScreen
local CrashScreen = class:derive("CrashScreen")

local Vec2 = require("src.Essentials.Vector2")



function CrashScreen:new(err)
    -- error message
    self.err = err

    -- button data
    self.buttons = {
        {name = "Copy to clipboard", hovered = false, pos = Vec2(30, 530), size = Vec2(170, 25), description = "Copies the error data to clipboard."},
        {name = "Report crash", hovered = false, pos = Vec2(220, 530), size = Vec2(170, 25), description = "Opens the New Issue page on GitHub with prefilled error information."},
        {name = "Restart", hovered = false, pos = Vec2(410, 530), size = Vec2(170, 25), description = "Restarts the game."},
        {name = "Exit", hovered = false, pos = Vec2(600, 530), size = Vec2(170, 25), description = "Exits the program."}
    }
    self.bottomText = ""
    self.bottomText2 = ""

    -- Replace with your project URL or remove if you want to disable the reporting functionality.
    self.url = "https://github.com/jakubg1/OpenSMCE/issues/new"

    self.e00000e00 = math.random() < 1 / 100

    -- Emergency save automatically.
    self:emergencySave()



    if math.random() <3 then
        pcall(function()
            local sound = love.audio.newSource("assets/crash.wav", "static")
            sound:play()
        end)
    end
end

function CrashScreen:update(dt)
    _MouseX, _MouseY = love.mouse.getPosition()

    -- Button hover
    self.bottomText = ""
    for i, button in ipairs(self.buttons) do
        button.hovered = _Utils.isPointInsideBoxExcl(_MouseX, _MouseY, button.pos.x, button.pos.y, button.size.x, button.size.y)
        if button.hovered then
            self.bottomText = self:transformText(button.description)
        end
    end
end

function CrashScreen:draw()
    -- Make fallback fonts if needed.
    _FONT = _FONT or love.graphics.setNewFont()
    _FONT_MED = _FONT_MED or love.graphics.setNewFont(14)
    _FONT_BIG = _FONT_BIG or love.graphics.setNewFont(18)
    _FONT_GIANT = _FONT_GIANT or love.graphics.setNewFont(30)

    -- White color
    love.graphics.setColor(1, 1, 1)

    -- Header
    love.graphics.setFont(_FONT_GIANT)
    love.graphics.print(self:transformText("Oh no!"), 30, 30)
    -- Text
    love.graphics.setFont(_FONT_MED)
    love.graphics.print(self:transformText("OpenSMCE has encountered a problem and crashed.\nThis is not meant to happen and you should report this error to the Github repository page\n(unless you caused the crash, of course).\n\n\nHere's some error info:"), 30, 70)

    -- Error frame
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 20, 175, 760, 345)

    -- Yellow color
    love.graphics.setColor(1, 1, 0)

    -- Error text
    love.graphics.setFont(_FONT)
    local result = pcall(function() love.graphics.printf(self.err, 30, 180, 740) end)
    if not result then
        love.graphics.print("Unable to print the crash message. Look at the console for more information!", 30, 180)
    end
    love.graphics.print(string.format("Version: %s (%s)", _VERSION_NAME, _VERSION), 550, 150)

    -- Button hovering
    love.graphics.setFont(_FONT_BIG)
    love.graphics.setLineWidth(1)
    for i, button in ipairs(self.buttons) do
        if button.hovered then
            love.graphics.setColor(0.8, 0.8, 0.8)
        else
            love.graphics.setColor(0.4, 0.4, 0.4)
        end
        love.graphics.rectangle("fill", button.pos.x, button.pos.y, button.size.x, button.size.y)
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("line", button.pos.x, button.pos.y, button.size.x, button.size.y)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print(button.name, button.pos.x + 5, button.pos.y + 1)
    end

    -- White color
    love.graphics.setColor(1, 1, 1)

    -- Bottom text
    love.graphics.setFont(_FONT)
    love.graphics.print(self.bottomText, 30, 560)

    -- Yellow color
    love.graphics.setColor(1, 1, 0)
    love.graphics.print(self.bottomText2, 30, 580)
end



function CrashScreen:mousepressed(x, y, button)
    -- STUB
end

function CrashScreen:mousereleased(x, y, button)
    -- Only left click counts.
    if button ~= 1 then
        return
    end

    for i, buttonW in ipairs(self.buttons) do
        if buttonW.hovered then
            if i == 1 then
                love.system.setClipboardText(self.err)
                self.bottomText2 = "Copied!"
            elseif i == 2 then
                self:reportIssue()
            elseif i == 3 then
                self:restart()
            elseif i == 4 then
                love.event.quit()
            end
        end
    end
end

function CrashScreen:keypressed(key)
    -- STUB
end

function CrashScreen:keyreleased(key)
    -- STUB
end



---Attempts to emergency save the player's progress.
function CrashScreen:emergencySave()
    -- Does a game exist?
    if not _Game or not _Game.name then
        return
    end
    self:say("Emergency Saving...")
    local success = pcall(function() _Game:save() end)
    if success then
        self.bottomText2 = "Emergency save successful!"
        self:say("Emergency save successful!")
    else
        self.bottomText2 = "Emergency save unsuccessful! You might have lost some progress... :'("
        self:say("Emergency save unsuccessful!")
    end
end

---Opens the browser with the GitHub issue form including prefilled error information.
function CrashScreen:reportIssue()
    if not self.url then
        -- Reporting is disabled.
        return
    end
    local body = "### Version\n" .. tostring(_VERSION) .. " (" .. tostring(_VERSION_NAME) .. ")\n\n"
    body = body .. "### Description\nPlease describe when the error happened. If it can be reproduced, a list of steps or a video would be really nice! :D\n\n"
    body = body .. "### Error Information\n```\n" .. self.err .. "\n```"
    local url = self.url
    --url = url .. "?title=" .. _Utils.strEncodeURL("Crash Report (Please replace and describe when the error happened!)")
    url = url .. "?body=" .. _Utils.strEncodeURL(body)
    love.system.openURL(url)
end

---Restarts the engine. In LOVE2D 12.0, additionally restarts the specific game the player was playing, if applicable.
function CrashScreen:restart()
    if love.getVersion() >= 12 then
        love.event.restart(_Game.name)
    else
        love.event.quit("restart")
    end
end

---Prints a message to log.
---@param message string The message to be printed.
function CrashScreen:say(message)
    if not _Log then
        return
    end
    _Log:printt("CrashScreen", message)
end

---Transforms text for the funni, if applicable.
---@param text string The text to be transformed.
---@return string
function CrashScreen:transformText(text)
    if not self.e00000e00 then
        return text
    end
    local s = ""
    for i = 1, text:len() do
        local c = text:sub(i, i)
        local b = c:byte()
        if b >= 97 and b <= 122 then
            s = s .. "0"
        else
            s = s .. c
        end
    end
    return s
end

return CrashScreen