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

	-- These fields refer to the volume which is set through `:setVolume()`.
	self.volume = 1
	self.targetVolume = 1
	self.targetVolumeSpeed = nil
	-- These fields refer to the volume which is set to either 0 or 1 whenever `:play()`, `:pause()` or `:stop()` is called.
	self.playVolume = 0
	self.targetPlayVolume = 0
	self.targetPlayVolumeSpeed = nil
	-- These fields are for speed `:setSpeed()`.
	self.speed = 1
	self.targetSpeed = 1
	self.targetSpeedSpeed = nil
	-- Control fields
	self.targetStop = false
	self.playing = false
	-- These values are cached for the source, because `ASource:getVolume()` is computationally expensive for a weird reason.
	self.sourceVolume = 0
	self.sourceSpeed = 1
end

---Updates the Music Track.
---@param dt number Time delta in seconds.
function MusicTrack:update(dt)
	-- Change the volume and speed over time or instantly if the current volume doesn't match the target.
	if self.volume ~= self.targetVolume then
		if self.targetVolumeSpeed then
			if self.volume > self.targetVolume then
				self.volume = math.max(self.volume - self.targetVolumeSpeed * dt, self.targetVolume)
			else
				self.volume = math.min(self.volume + self.targetVolumeSpeed * dt, self.targetVolume)
			end
		else
			self.volume = self.targetVolume
		end
	end

	if self.playVolume ~= self.targetPlayVolume then
		if self.targetPlayVolumeSpeed then
			if self.playVolume > self.targetPlayVolume then
				self.playVolume = math.max(self.playVolume - self.targetPlayVolumeSpeed * dt, self.targetPlayVolume)
			else
				self.playVolume = math.min(self.playVolume + self.targetPlayVolumeSpeed * dt, self.targetPlayVolume)
			end
		else
			self.playVolume = self.targetPlayVolume
		end
	end

	if self.speed ~= self.targetSpeed then
		if self.targetSpeedSpeed then
			if self.speed > self.targetSpeed then
				self.speed = math.max(self.speed - self.targetSpeedSpeed * dt, self.targetSpeed)
			else
				self.speed = math.min(self.speed + self.targetSpeedSpeed * dt, self.targetSpeed)
			end
		else
			self.speed = self.targetSpeed
		end
	end

	-- Update the volume of the track based on its current volume and the global music volume.
	local newSourceVolume = self.volume * self.playVolume * _Game:getEffectiveMusicVolume()
	if self.sourceVolume ~= newSourceVolume then
		-- Setting the volumes of ASources is VERY, VERY EXPENSIVE!
		-- Same for getting the volume. I do not know why that is the case...
		self.instance:setVolume(newSourceVolume)
		self.sourceVolume = newSourceVolume
	end

	if self.sourceSpeed ~= self.speed then
		self.instance:setTimeStretch(self.speed)
		self.sourceSpeed = self.speed
	end

	---Update the playing state of the track based on its current volume.
	---When the volume reaches 0, the track is paused or stopped.
	---When the volume is greater than 0, the track is resumed or played from the beginning.
	---And yes, getting/setting the playback state is expensive as well!
	if self.playing and self.playVolume == 0 then
		if self.targetStop then
			self.instance:stop()
		else
			self.instance:pause()
		end
		self.playing = false
	end
	if not self.playing and self.playVolume > 0 then
		self.instance:play()
		self.playing = true
	end
end

---Plays or resumes this Track.
---@param duration number? If specified, the music will fade in over this time in seconds. Otherwise the transition will be instant.
function MusicTrack:play(duration)
	self:setPlayVolume(1, duration)
	self.targetStop = false
end

---Pauses this Track. When `:play()` is called, the music will resume from its current point.
---@param duration number? If specified, the music will fade out over this time in seconds. Otherwise the music will be paused instantly.
function MusicTrack:pause(duration)
	self:setPlayVolume(0, duration)
	self.targetStop = false
end

---Stops this Track. When `:play()` is called, the music will start from the beginning.
---@param duration number? If specified, the music will fade out over this time in seconds. Otherwise the music will stop instantly.
function MusicTrack:stop(duration)
	self:setPlayVolume(0, duration)
	self.targetStop = true
	if not duration or duration == 0 then
		-- Allow stop-play without having to wait for the next frame.
		self.instance:stop()
	end
end

---Returns whether this Music Track is playing.
---Note that this returns `false` if this Track is on its way to be paused or stopped, even if the transition is still in progress.
---@return boolean
function MusicTrack:isPlaying()
	return self.targetPlayVolume > 0
end

---Sets this Track's play volume. This is used by track control functions.
---@private
---@param volume number The desired play volume. This should be only ever 1 or 0.
---@param duration number? The duration of the transition in seconds. If not specified, the change will be instant.
function MusicTrack:setPlayVolume(volume, duration)
	self.targetPlayVolume = volume
	self.targetPlayVolumeSpeed = (duration and duration > 0) and (1 / duration)
end

---Sets this Track's volume.
---@param volume number The new volume, ranging from 0 to 1.
---@param duration number? The duration of the transition in seconds. If not specified, the change will be instant.
function MusicTrack:setVolume(volume, duration)
	self.targetVolume = volume
	self.targetVolumeSpeed = (duration and duration > 0) and (1 / duration)
end

---Sets the playback speed of this Music Track.
---This feature only works when using ASL. Otherwise, throws an error.
---@param speed number The playback speed. 1 is the nominal speed.
---@param duration number? The duration of the transition in seconds. If not specified, the change will be instant.
function MusicTrack:setSpeed(speed, duration)
	assert(_DFLAG_ASL, "Attempt to call `MusicTrack:setSpeed()` without the ASL debug flag set. Wrap your call around with an `if` statement or turn the flag on.")
	self.targetSpeed = speed
	self.targetSpeedSpeed = (duration and duration > 0) and (1 / duration)
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
