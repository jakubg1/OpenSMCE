local class = require "com.class"

---Represents a Music Track. Music Tracks live directly in the Resource Manager and should not be instantiated on the fly.
---@class MusicTrack
---@overload fun(config: MusicTrackConfig, path: string):MusicTrack
local MusicTrack = class:derive("MusicTrack")

---Constructs a new Music Track.
---@param config MusicTrackConfig The Music Track Config.
---@param path string A path to the Music Track file.
function MusicTrack:new(config, path)
    self.path = path

	local sound = config.audio
	-- TODO: This likes to crash with certain music files (MIDI). Look into it in the future.
	self.instance = _DFLAG_ASL and sound:makeAdvancedSource() or sound:makeSource("stream")
	assert(self.instance, "Failed to load sound data: " .. tostring(config.audio) .. " from " .. path)
	self.instance:setLooping(true)

	self.volume = 0
	self.targetVolume = 0
	self.targetVolumeSpeed = nil
	self.targetStop = false
	self.sourceVolume = nil
	self.sourceIsPlaying = false
end

---Updates the Music Track.
---@param dt number Time delta in seconds.
function MusicTrack:update(dt)
	-- Change the volume over time or instantly if the current volume doesn't match the target.
	if self.volume ~= self.targetVolume then
		if self.targetVolumeSpeed then
			if self.volume > self.targetVolume then
				self.volume = math.max(self.volume - dt * self.targetVolumeSpeed, self.targetVolume)
			else
				self.volume = math.min(self.volume + dt * self.targetVolumeSpeed, self.targetVolume)
			end
		else
			self.volume = self.targetVolume
		end
	end

	-- Update the volume of the track based on its current volume and the global music volume.
	local sourceVolume = self.volume * _Game:getEffectiveMusicVolume()
	if self.sourceVolume ~= sourceVolume then
		-- Setting the volumes of ASources is VERY, VERY EXPENSIVE!
		-- Same for getting the volume. I do not know why that is...
		self.instance:setVolume(sourceVolume)
		self.sourceVolume = sourceVolume
	end

	---Update the playing state of the track based on its current volume.
	---When the volume reaches 0, the track is paused or stopped.
	---When the volume is greater than 0, the track is resumed or played from the beginning.
	---And yes, getting/setting the playback state is expensive as well!
	if self.sourceIsPlaying and self.volume == 0 then
		if self.targetStop then
			self.instance:stop()
		else
			self.instance:pause()
		end
		self.sourceIsPlaying = false
	end
	if not self.sourceIsPlaying and self.volume > 0 then
		self.instance:play()
		self.sourceIsPlaying = true
	end
end

---Plays the track or changes its volume.
---@param volume number? The track volume. `1` is maximum volume, `0` is mute. Defaults to `1`. Set to `0` if you want to pause the track.
---@param duration number? The duration of the transition. If not specified, the change in volume will be instant.
function MusicTrack:play(volume, duration)
	volume = volume or 1
	duration = duration or 0

	self.targetVolume = volume
	self.targetVolumeSpeed = (duration > 0) and (1 / duration)
	self.targetStop = false
end

---Stops the track. When played again, it will start from the beginning.
---@param duration number? The duration of the transition. If not specified, the track will be stopped immediately.
function MusicTrack:stop(duration)
	duration = duration or 0

	self.targetVolume = 0
	self.targetVolumeSpeed = (duration > 0) and (1 / duration)
	self.targetStop = true
	if duration == 0 then
		self.instance:stop()
	end
end

---Sets the playback speed of this Music Track.
---This feature only works when using ASL. Otherwise, throws an error.
---@param speed number The playback speed. 1 is the nominal speed.
function MusicTrack:setSpeed(speed)
	assert(_DFLAG_ASL, "Attempt to call `MusicTrack:setSpeed()` without the ASL debug flag set. Wrap your call around with an `if` statement or turn the flag on.")
	self.instance:setTimeStretch(speed)
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function MusicTrack.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a Music Track by a given path.
    ---@param path string The resource path.
    ---@return MusicTrack
    function ResourceManager:getMusicTrack(path)
        return self:getResourceAsset(path, "MusicTrack")
    end
end

return MusicTrack
