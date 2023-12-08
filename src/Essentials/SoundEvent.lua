local class = require "com.class"

---Represents a Sound Event, which can be played by miscellaneous events during the game and from the user interface.
---@class SoundEvent
---@overload fun(path):SoundEvent
local SoundEvent = class:derive("SoundEvent")



---Constructs a Sound Event. This represents data from a file located in the `sound_events` folder.
---@param path string The path to the `sound_events/*.json` file to load the event from.
function SoundEvent:new(path)
    self.path = path
    local data = _LoadJson(path)

    self.sound = nil
    if data.path then
        self.sound = _Game.resourceManager:getSound(data.path)
    end
    self.volume = data.volume or 1
    self.pitch = data.volume or 1
    self.loop = data.loop or false
    self.flat = data.flat or false
end



---Plays a Sound Event and returns itself, a SoundInstance or `nil`.
---In principle, this should allow the caller to change the sound parameters (position) later on.
---In practice, this could lead to crashes.
---  - Returns itself if this Sound Event does not have any sound assigned to it.
---  - Returns a `SoundInstance` instance if the assigned sound has been correctly played.
---  - Returns `nil` if the assigned sound has not been played due to exhaustion of available instances.
---@param pitch number? The pitch of the sound. Defaults to 1. This is multiplied by the event-defined pitch.
---@param pos Vector2? The position of the sound for sounds which support 3D positioning.
---@return SoundEvent|SoundInstance|nil
function SoundEvent:play(pitch, pos)
    if not self.sound then
        return self
    end
    pitch = pitch or 1
    local eventVolume = _ParseNumber(self.volume)
    local eventPitch = _ParseNumber(self.pitch)
    local eventPos = not self.flat and pos
    return self.sound:play(eventVolume, pitch * eventPitch, eventPos, self.loop)
end



---Stops the sound assigned to this Sound Event.
function SoundEvent:stop()
    if not self.sound then
        return
    end
    self.sound:stop()
end



return SoundEvent
