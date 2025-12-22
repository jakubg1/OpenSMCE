local class = require "com.class"

---Represents a Sound Event, which can be played by miscellaneous events during the game and from the user interface.
---@class SoundEvent
---@overload fun(data, path):SoundEvent
local SoundEvent = class:derive("SoundEvent")

local SoundInstance = require("src.Essentials.SoundInstance")
local SoundInstanceList = require("src.Essentials.SoundInstanceList")
local Expression = require("src.Expression")



---Constructs a Sound Event. This represents data from a file located in the `sound_events` folder.
---@param data table The parsed JSON data from the sound event file.
---@param path string The path to the `sound_events/*.json` file to load the event from.
function SoundEvent:new(data, path)
    self.path = path

    self.sounds = {}
    -- TODO: Extract Sound Entries to a separate class.
    if data.sound then
        local sound = _Res:getSound(data.sound)
        local entry = {}
        entry.volume = Expression(data.volume or 1)
        entry.pitch = Expression(data.pitch or 1)
        entry.loop = data.loop or false
        entry.flat = data.flat or false
        entry.playsPerFrame = data.playsPerFrame
        entry.playsThisFrame = 0
        entry.instanceCount = data.instances or 8
        entry.instances = {}
        for i = 1, entry.instanceCount do
            entry.instances[i] = SoundInstance(sound:makeSource("static"))
        end
        self.sounds[1] = entry
    elseif data.sounds then
        for i, snd in ipairs(data.sounds) do
            local sound = _Res:getSound(snd.sound)
            local entry = {}
            entry.volume = Expression(snd.volume or 1)
            entry.pitch = Expression(snd.pitch or 1)
            entry.loop = snd.loop or false
            entry.flat = snd.flat or false
            entry.playsPerFrame = snd.playsPerFrame
            entry.playsThisFrame = 0
            entry.instanceCount = snd.instances or 8
            entry.instances = {}
            for j = 1, entry.instanceCount do
                entry.instances[j] = SoundInstance(sound:makeSource("static"))
            end
            if snd.conditions then
                entry.conditions = {}
                for j, condition in ipairs(snd.conditions) do
                    entry.conditions[j] = Expression(condition)
                end
            end
            self.sounds[i] = entry
        end
    end
end



---Updates the Sound Event. This is required so that the sound volume can update according to the game volume.
---@param dt number Time delta in seconds.
function SoundEvent:update(dt)
    for i, entry in ipairs(self.sounds) do
        entry.playsThisFrame = 0
        for j, instance in ipairs(entry.instances) do
            instance:update(dt)
        end
    end
end



---Returns the first free instance of this SoundEvent's sound, or `1` if none are available right now (play the first instance).
---Can return `nil` if this SoundEvent has no sound assigned to it.
---@param i integer The sound index from the `self.sounds` field.
---@return SoundInstance?
function SoundEvent:getFreeInstance(i)
	for j, instance in ipairs(self.sounds[i].instances) do
		if not instance:isPlaying() then
			return instance
		end
	end
    return self.sounds[i].instances[1]
end



---Plays a Sound Event and returns a SoundInstance or itself.
---Returning a SoundInstanceList allows the caller to change the sound parameters (like position) while the sound is playing.
---@param x number? The X position of the sound for sounds which support 3D positioning.
---@param y number? The Y position of the sound for sounds which support 3D positioning.
---@return SoundInstanceList
function SoundEvent:play(x, y)
    local instances = {}
    for i, entry in ipairs(self.sounds) do
        local conditionsPassed = true
        if entry.playsPerFrame and entry.playsThisFrame >= entry.playsPerFrame then
            -- Entry playback limit this frame reached, don't play anything.
            conditionsPassed = false
        end
        if conditionsPassed and _Utils.checkExpressions(entry.conditions) then
            entry.playsThisFrame = entry.playsThisFrame + 1
            local instance = self:getFreeInstance(i)
            if instance then
                instance:setVolume(entry.volume:evaluate())
                instance:setPitch(entry.pitch:evaluate())
                if x and y and not entry.flat then
                    instance:setPos(x, y)
                end
                instance:setLoop(entry.loop)
                if instance:isPlaying() then
                    instance:stop()
                end
                instance:play()
            else
                instance = self
            end
            table.insert(instances, instance)
        end
    end
    return SoundInstanceList(instances)
end



---Stops all the sound instances assigned to this Sound Event.
function SoundEvent:stop()
    for i, entry in ipairs(self.sounds) do
        for j, instance in ipairs(entry.instances) do
            instance:stop()
        end
    end
end



return SoundEvent
