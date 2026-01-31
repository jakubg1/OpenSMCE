local class = require "com.class"

---@class Log
---@overload fun():Log
local Log = class:derive("Log")

---Constructs the Logger.
function Log:new()
    self.FILE = "log.txt"
    self.SAVE_DELAY = 10
    self.saveTime = 0
    -- The raw log file contents, exactly as it will be written to the file.
    -- TODO: Append to the file instead, and perhaps make a buffer in case if the save fails somehow.
    self.contents = ""

    self:printt("Log", string.format("OpenSMCE Log - Version: %s (Build: %s)", _VERSION, _BUILD_NUMBER))
end

---Updates the logger. This is needed so it can track the time between saves, and saving the log every certain time needs to be performed
---as some unusual close cases (such as ending the process via Task Manager, a Not Responding state or your computer simply BSOD-ing off
---or your mice snapping your yummy power cables) will not trigger any exit functions and therefore won't save the log.
---This way we are retaining most of the log.
---@param dt number Delta time in seconds.
function Log:update(dt)
    self.saveTime = self.saveTime + dt
    if self.saveTime >= self.SAVE_DELAY then
        self.saveTime = 0
        self:save(false)
    end
end

---Appends a new line to the log.
---@param text string The text to be written to log.
function Log:print(text)
    self.contents = self.contents .. string.format("[%.6f] %s\n", _GetPreciseTime(), text)
    if _Settings:getSetting("consoleWindow") then
        print("[ LOG ]   " .. text)
    end
end

---Prints a line to the log along with the tag, enclosed in square brackets.
---@param tag string A tag to be included in the printed line.
---@param text string The text to be written to log.
function Log:printt(tag, text)
    self:print(string.format("[%s] %s", tag, text))
end

---Saves the current log to the log file.
---@param quit boolean If not set to `true`, a notice will be added at the end that several last lines might have been omitted. See `Log:update()` for details.
function Log:save(quit)
    local s = self.contents
    if not quit then
        s = s .. "...This is not a final log; a few recent lines might have been omitted!\n"
    end
    _Utils.saveFile(self.FILE, s)
end

return Log