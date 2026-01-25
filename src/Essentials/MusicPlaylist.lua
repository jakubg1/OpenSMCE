local class = require "com.class"

---Music Playlists are a temporary measure to include the possibility of playing different tracks at random.
---@class MusicPlaylist
---@overload fun(data, path):MusicPlaylist
local MusicPlaylist = class:derive("MusicPlaylist")

---Constructs a new Music Playlist.
---@param config MusicPlaylistConfig The config of this Music Playlist.
---@param path string Path to the Music Playlist file.
function MusicPlaylist:new(config, path)
    self.config = config
	self.path = path

    self.track = 1 -- The currently played or queued track number.
end

---Returns the currently played Music Track in this Playlist.
---@return MusicTrack
function MusicPlaylist:getTrack()
    return self.config.tracks[self.track]
end

---Stops the current track and moves on to the next one (or picks one at random).
function MusicPlaylist:nextTrack()
    self:getTrack():stop()
    if self.config.order == "random" then
        self.track = math.random(1, #self.config.tracks)
    elseif self.config.order == "sequence" then
        self.track = self.track % #self.config.tracks + 1
    end
end

---Injects functions to Resource Manager regarding this resource type.
---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.
function MusicPlaylist.inject(ResourceManager)
    ---@class ResourceManager
    ResourceManager = ResourceManager

    ---Retrieves a Music Playlist by a given path.
    ---@param path string The resource path.
    ---@return MusicPlaylist
    function ResourceManager:getMusicPlaylist(path)
        return self:getResourceAsset(path, "MusicPlaylist")
    end
end

return MusicPlaylist
