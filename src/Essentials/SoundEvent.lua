local class = require "com.class"

---Represents a Sound Event, which can be played by miscellaneous events during the game and from the user interface.
---@class SoundEvent
---@overload fun(data, path, namespace, batches):SoundEvent
local SoundEvent = class:derive("SoundEvent")

local SoundInstance = require("src.Essentials.SoundInstance")



---Constructs a Sound Event. This represents data from a file located in the `sound_events` folder.
---@param data table The parsed JSON data from the sound event file.
---@param path string The path to the `sound_events/*.json` file to load the event from.
---@param namespace string? The namespace this resource is loaded as. Pass forward to all resource getters inside.
---@param batches table? The batch names this resource is loaded as a part of. Pass forward to all resource getters inside.
function SoundEvent:new(data, path, namespace, batches)
    self.path = path

    self.volume = data.volume or 1
    self.pitch = data.volume or 1
    self.loop = data.loop or false
    self.flat = data.flat or false
    self.instanceCount = data.instances or 8

    self.instances = {}
    if data.path then
        local sound = _Game.resourceManager:getSound(data.path, namespace, batches)
        for i = 1, self.instanceCount do
            self.instances[i] = SoundInstance(sound:makeSource("static"))
        end
    end
end



---Updates the Sound Event. This is required so that the sound volume can update according to the game volume.
---@param dt number Time delta in seconds.
function SoundEvent:update(dt)
	for i, instance in ipairs(self.instances) do
		instance:update(dt)
	end
end



---Returns the first free instance of this SoundEvent's sound, or `1` if none are available right now (play the first instance).
---Can return `nil` if this SoundEvent has no sound assigned to it.
---@return SoundInstance?
function SoundEvent:getFreeInstance()
	for i, instance in ipairs(self.instances) do
		if not instance:isPlaying() then
			return instance
		end
	end
    return self.instances[1]
end



---Plays a Sound Event and returns a SoundInstance or itself.
---Returning a SoundInstance allows the caller to change the sound parameters (position) while the sound is playing.
---  - Returns a `SoundInstance` instance if the assigned sound has been correctly played.
---  - Returns itself if this Sound Event does not have any sound assigned to it.
---@param pitch number? The pitch of the sound. Defaults to 1. This is multiplied by the event-defined pitch.
---@param pos Vector2? The position of the sound for sounds which support 3D positioning.
---@return SoundEvent|SoundInstance
function SoundEvent:play(pitch, pos)
    local instance = self:getFreeInstance()
    if not instance then
        return self
    end
    instance:setVolume(_ParseNumber(self.volume))
    instance:setPitch(_ParseNumber(self.pitch) * (pitch or 1))
    instance:setPos(not self.flat and pos)
    instance:setLoop(self.loop)
    instance:play()
    return instance
end



---Stops all the sound instances assigned to this Sound Event.
function SoundEvent:stop()
	for i, instance in ipairs(self.instances) do
		instance:stop()
	end
end



return SoundEvent
