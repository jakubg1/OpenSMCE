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
        {name = "Copy to clipboard", hovered = false, pos = Vec2(30, 530), size = Vec2(170, 25)},
        {name = "Report crash", hovered = false, pos = Vec2(220, 530), size = Vec2(170, 25)},
        {name = "Emergency save", hovered = false, pos = Vec2(410, 530), size = Vec2(170, 25)},
        {name = "Exit", hovered = false, pos = Vec2(600, 530), size = Vec2(170, 25)}
    }
    self.bottomText = ""
    self.bottomText2 = ""
    self.url = "https://github.com/jakubg1/OpenSMCE/issues"

    self.e00000e00 = math.random() < 1 / 100



    if math.random() <3 then
        pcall(function()
            local sound = love.audio.newSource("assets/crash.wav", "static")
            sound:play()
        end)
    end
end

function CrashScreen:update(dt)
    _MousePos = Vec2(love.mouse.getPosition())

    -- Button hover
    self.bottomText = ""
    for i, button in ipairs(self.buttons) do
        button.hovered = _MousePos.x > button.pos.x and
                        _MousePos.x < button.pos.x + button.size.x and
                        _MousePos.y > button.pos.y and
                        _MousePos.y < button.pos.y + button.size.y
        if button.hovered then
            if i == 1 then
                self.bottomText = self:transformText("Copies the error data to clipboard.")
            elseif i == 2 then
                self.bottomText = self:transformText("Copies the error data to clipboard and opens the issues page on GitHub.")
            elseif i == 3 then
                self.bottomText = self:transformText("Attempts to recover your progress.")
            elseif i == 4 then
                self.bottomText = self:transformText("Exits the program.")
            end
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
    love.graphics.print(self:transformText("OpenSMCE has encountered a problem and crashed.\nThis is not meant to happen and you should report this error to the Github repository page\n(unless you caused the crash, of course).\nYou can try to emergency save the progress, in order not to lose it.\n\nHere's some error info:"), 30, 70)

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
            elseif i == 2 then
                love.system.setClipboardText(self.err)
                love.system.openURL(self.url)
            elseif i == 3 then
                self:emergencySave()
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



function CrashScreen:emergencySave()
    _Log:printt("CrashScreen", "Emergency Saving...")

    -- Does a game exist?
    if _Game.name then
        local success = pcall(function() _Game:save() end)
        if success then
            self.bottomText2 = "Saved successfully!"
            _Log:printt("CrashScreen", "Save successful!")
        else
            self.bottomText2 = "Save unsuccessful!"
            _Log:printt("CrashScreen", "Save unsuccessful!")
        end
    else
        self.bottomText2 = "There was nothing to save, you were in Boot Screen, duh."
        _Log:printt("CrashScreen", "No, we're ending here")
    end
end

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