local class = require "com.class"

---Represents a Sound loaded from an audio file. Hosts 8 copies of the same sound file, which are called instances. This allows a few copies of the same sound to be played simultaneously.
---@class Sound
---@overload fun(path):Sound
local Sound = class:derive("Sound")

local SoundInstance = require("src.Essentials.SoundInstance")



---Constructs a new Sound.
---@param path string The path to the sound file.
function Sound:new(path)
	self.INSTANCE_COUNT = 8
	-- Each sound has 8 instances of it so it can play up to 8 instances at the same time.
	self.instances = {}
	local sounds = _LoadSounds(path, "static", self.INSTANCE_COUNT)
	for i = 1, self.INSTANCE_COUNT do
		self.instances[i] = SoundInstance(sounds[i])
	end
end



---Updates the Sound. This is required so that the sound volume can update according to the game volume.
---@param dt number Time delta in seconds.
function Sound:update(dt)
	for i, instance in ipairs(self.instances) do
		instance:update(dt)
	end
end



---Returns the first free instance of this Sound, or `nil` if none are available right now.
---@return SoundInstance?
function Sound:getFreeInstance()
	for i, instance in ipairs(self.instances) do
		if not instance:isPlaying() then
			return instance
		end
	end
end



---Plays the Sound on one of its instances and returns that instance.
---If there are no free instances at the moment, no sound is played and `nil` is returned.
---@param volume number The sound volume.
---@param pitch number The sound pitch.
---@param pos Vector2 The position on the screen from where this sound is played.
---@param loop boolean Whether the sound should loop.
---@return SoundInstance?
function Sound:play(volume, pitch, pos, loop)
	pitch = pitch or 1
	local instance = self:getFreeInstance()
	if instance then
		instance:setVolume(volume)
		instance:setPitch(pitch)
		instance:setPos(pos)
		instance:setLoop(loop)
		instance:play()
		return instance
	end
	-- might add an algorithm that will nuke one of the sounds and play it again on that instance if no free instances
end



---Stops all instances of this Sound.
function Sound:stop()
	for i, instance in ipairs(self.instances) do
		instance:stop()
	end
end



return Sound
