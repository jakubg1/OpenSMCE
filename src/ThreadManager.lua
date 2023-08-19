local class = require "com.class"

---Manages separate Threads, which can be used for multi-processing. Janky syntax and pretty barebones, be careful!
---@class ThreadManager
---@overload fun():ThreadManager
local ThreadManager = class:derive("ThreadManager")

-- Place your imports here



---Constructs a new Thread Manager.
function ThreadManager:new()
    self.jobs = {}
    -- Used to give unique names for the channels.
    self.nextJob = 1
end



---Updates the Thread Manager. This is needed so it is aware of which jobs have just finished.
---@param dt number Delta time in seconds.
function ThreadManager:update(dt)
    for i, job in pairs(self.jobs) do
        if not job.thread:isRunning() then
            if job.onFinish then
                if job.caller then
                    job.onFinish(job.caller, job.outChannel:pop())
                else
                    job.onFinish(job.outChannel:pop())
                end
            end
            self.jobs[i] = nil
        end
    end
end



---Starts a new Thread from a given file.
---@param name string The name of a Lua source code file which is located in the path `src.Threads.<name>`. That file must exist!
---@param data table? A table of values to be passed to the thread.
---@param onFinish function? The function which will be executed when this Thread finishes its job. Can contain a data table as an argument.
---@param caller any? Any class instance for which the `onFinish` function should run. Useful if you don't want to create anonymous functions.
function ThreadManager:startJob(name, data, onFinish, caller)
    local path = string.format("src/Threads/%s.lua", name)
    local outID = string.format("thr%s", self.nextJob)

    local job = {
        thread = love.thread.newThread(path),
        caller = caller,
        onFinish = onFinish,
        outChannel = love.thread.getChannel(outID)
    }
    job.thread:start(outID, data)

    self.jobs[self.nextJob] = job
    self.nextJob = self.nextJob + 1
end



return ThreadManager