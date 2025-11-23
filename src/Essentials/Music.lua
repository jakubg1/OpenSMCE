local class = require "com.class"

---Represents a Music track. Music tracks live directly in the Resource Manager and should not be instantiated on the fly.
---@class Music
---@overload fun(data, path):Music
local Music = class:derive("Music")



---Constructs a new Music track.
---@param data table The data from the Music Track configuration file.
---@param path string The path to the Music Track file the data is loaded from. Used only in error messages.
function Music:new(data, path)
    self.path = path

	local sound = _Res:getSound(data.audio)
	-- TODO: This likes to crash with certain music files. Look into it in the future.
	--self.instance = sound:makeAdvancedSource()
	self.instance = sound:makeSource("stream")
	if not self.instance then
		error("Failed to load sound data: " .. data.audio .. " from " .. path)
	end
	self.instance:setLooping(true)

	self.volume = 0
	self.targetVolume = 0
	self.targetVolumeSpeed = nil
	self.targetStop = false
	self.sourceVolume = nil
	self.sourceIsPlaying = false
end



---Updates the Music track.
---@param dt number Time delta in seconds.
function Music:update(dt)
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
function Music:play(volume, duration)
	volume = volume or 1
	duration = duration or 0

	self.targetVolume = volume
	self.targetVolumeSpeed = (duration > 0) and (1 / duration)
	self.targetStop = false
end



---Stops the track. When played again, it will start from the beginning.
---@param duration number? The duration of the transition. If not specified, the track will be stopped immediately.
function Music:stop(duration)
	duration = duration or 0

	self.targetVolume = 0
	self.targetVolumeSpeed = (duration > 0) and (1 / duration)
	self.targetStop = true
	if duration == 0 then
		self.instance:stop()
	end
end



return Music
