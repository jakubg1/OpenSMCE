local class = require "com.class"
local SoundInstance = require("src.Essentials.SoundInstance")
local SoundInstanceList = require("src.Essentials.SoundInstanceList")
local Expression = require("src.Expression")

---Represents a Sound Event, which can be played by miscellaneous events during the game and from the user interface.
---@class SoundEvent
---@overload fun(data, path):SoundEvent
local SoundEvent = class:derive("SoundEvent")

---Constructs a Sound Event. This represents data from a file located in the `sound_events` folder.
---@param config SoundEventConfig The parsed data from the sound event file.
---@param path string The path to the `sound_events/*.json` file the event has been loaded from.
function SoundEvent:new(config, path)
    self.path = path

    ---@alias SoundEntry {config: table, playsThisFrame: integer, instances: SoundInstance[]}
    ---@type SoundEntry[]
    self.sounds = {}
    if config.sound then
        local entry = {config = config, playsThisFrame = 0, instances = {}}
        for i = 1, config.instances do
            entry.instances[i] = SoundInstance(config.sound:makeSource("static"))
        end
        self.sounds[1] = entry
    elseif config.sounds then
        for i, snd in ipairs(config.sounds) do
            local entry = {config = snd, playsThisFrame = 0, instances = {}}
            for j = 1, snd.instances do
                entry.instances[j] = SoundInstance(snd.sound:makeSource("static"))
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
---@private
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
        if entry.config.playsPerFrame and entry.playsThisFrame >= entry.config.playsPerFrame then
            -- Entry playback limit this frame reached, don't play anything.
            conditionsPassed = false
        end
        if conditionsPassed and _Utils.checkExpressions(entry.config.conditions) then
            entry.playsThisFrame = entry.playsThisFrame + 1
            local instance = self:getFreeInstance(i)
            if instance then
                instance:setVolume(entry.config.volume:evaluate())
                instance:setPitch(entry.config.pitch:evaluate())
                if x and y and not entry.config.flat then
                    instance:setPos(x, y)
                end
                instance:setLoop(entry.config.loop)
                if instance:isPlaying() then
                    instance:stop()
                end
                instance:play()
                table.insert(instances, instance)
            end
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

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function SoundEvent.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a SoundEvent by a given path.
    ---@param path string The resource path.
    ---@return SoundEvent
    function ResourceManager:getSoundEvent(path)
        return self:getResourceAsset(path, "SoundEvent")
    end
end

return SoundEvent
