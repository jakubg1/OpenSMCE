local class = require "com/class"

---@class UI2Sequence
---@overload fun(manager, config):UI2Sequence
local UI2Sequence = class:derive("UI2Sequence")



---Constructs the UI2Sequence.
---@param manager UI2Manager The UI Manager this Sequence belongs to.
---@param config UI2SequenceConfig The UI Sequence Config which defines this Sequence.
function UI2Sequence:new(manager, config)
    self.manager = manager
    self.config = config

    self.currentStep = 1
    self.waitTime = nil -- nil if not waiting, -1 if waiting indefinitely (for a callback), positive when waiting a certain time
end



---Updates this Sequence.
---@param dt number Time delta in seconds.
function UI2Sequence:update(dt)
    -- Execute as many steps as possible before stumbling in a waiting state.
    if self.waitTime and self.waitTime > 0 then
        self.waitTime = self.waitTime - dt
        if self.waitTime <= 0 then
            self.waitTime = nil
        end
    end
    while not self.waitTime do
        if self:isFinished() then
            break
        end
        self:executeEntry(self.currentStep)
        self.currentStep = self.currentStep + 1
    end
end



---Executes a single entry in this Sequence.
---@param n integer The entry ID to be executed.
function UI2Sequence:executeEntry(n)
    local entry = self.config.timeline[n]

    if entry.type == "playAnimation" then
        self.manager:getNode(entry.node):playAnimation(entry.animation, self, n)
        if entry.waitUntilFinished then
            self.waitTime = -1
        end
    elseif entry.type == "wait" then
        self.waitTime = entry.time
    end
end



---Releases the "wait until finished" lock to allow executing next steps of this Sequence. Used in a callback fired from a UI Node.
function UI2Sequence:releaseLock()
    if self.waitTime == -1 then
        self.waitTime = nil
    end
end



---Returns whether this Sequence has finished its work.
---@return boolean
function UI2Sequence:isFinished()
    return self.currentStep > #self.config.timeline
end



return UI2Sequence