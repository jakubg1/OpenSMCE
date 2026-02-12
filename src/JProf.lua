local Class = require("com.class")

---The JProf class is a wrapper for the jprof profiler.
---@class JProf : Class
---@overload fun(): JProf
local JProf = Class:derive("JProf")

---Constructs the JProf profiler.
function JProf:new()
    self.FILE = "performance.jprof"
    self.jprof = nil
end

---Starts the profiler. If this is not called, any other calls will not work.
function JProf:start()
    PROF_CAPTURE = true
    self.jprof = require("com.jprof")
    self.jprof.connect()
end

---Updates the profiler.
---@param dt number Time delta in seconds.
function JProf:update(dt)
    if not self.jprof then
        return
    end
    self.jprof.netFlush()
end

---Pushes a profiler section onto the stack.
---@param name string The section name.
function JProf:push(name)
    if not self.jprof then
        return
    end
    self.jprof.push(name)
end

---Pops a profiler section from the stack.
---@param name string The section name.
function JProf:pop(name)
    if not self.jprof then
        return
    end
    self.jprof.pop()
end

---Ends the profiling session and saves the performance file.
function JProf:close()
    if not self.jprof then
        return
    end
    self.jprof.write(self.FILE)
    self.jprof = nil
end

return JProf