local class = require "com.class"

---@class Log
---@overload fun():Log
local Log = class:derive("Log")

---Constructs the Logger.
function Log:new()
    self.FILE = "log.txt"
    self.buffer = "" -- The buffer containing recent raw log file contents, exactly as it will be written to the file.
    self:clear()
    self:printt("Log", string.format("OpenSMCE Log - Version: %s (Build: %s)", _VERSION, _BUILD_NUMBER))
end

---Appends a new line to the log.
---@param text string The text to be written to log.
function Log:print(text)
    self.buffer = self.buffer .. string.format("[%.6f] %s\n", _GetPreciseTime(), text)
    self:save()
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

---Clears the log file. This should be only done once on startup.
function Log:clear()
    _Utils.saveFile(self.FILE, "")
end

---Adds the buffer to the log file and clears the buffer.
function Log:save()
    local success, result = pcall(function() _Utils.saveFile(self.FILE, self.buffer, true) end)
    if success then
        self.buffer = ""
    else
        print(string.format("Error saving log file: %s", tostring(result)))
    end
end

return Log