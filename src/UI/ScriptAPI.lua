-- This is the UI Script API.
-- The following functions will be the only functions available in the UI Script, in the global scope.
-- Anything not marshalled here from the actual global scope will be inaccessible.
-- There are lots of benefits, like malware games which mess with your files on the entire system are impossible
-- because there's no `os.execute()` available. Who would want to go out of their way and do that? No idea! Better be safe than sorry though.
-- Also this is an excuse for my lazy ass to make proper API for accessing stuff like mouse position.
-- Have fun, although there is none to be had here! (Why am I so negative? Gosh I will never land a job if I keep being snarky like this)

local api = {}

---Loads all game resources.
function api.loadResources() _Game:loadResources() end
---Ends the current level and triggers a `gameOver` callback.
function api.sessionTerminate() _Game:gameOver() end
---Returns the percentage of the resources loaded, as a number from 0 to 1.
---@return number
function api.loadingGetProgress() return _Res:getLoadProgress("main") end

---Starts a new Level from the current Profile, or loads one in progress if it has one.
---This also executes an appropriate entry in the UI script if the current level set's entry is a UI Script one. Yep, it's a mess.
function api.levelStart() _Game:startLevel() end
---Moves on to the next sequence step if the current step is a UI callback which is waiting.
function api.levelContinue() _Game.level:continueSequence() end
---Pauses the level.
function api.levelPause() _Game.level:setPause(true) end
---Unpauses the level.
function api.levelUnpause() _Game.level:setPause(false) end
---Marks this level as lost and restarts it if there are some lives left. Otherwise, ends the game.
function api.levelRestart() _Game.level:tryAgain() end
---Ends the current level without saving its data.
function api.levelEnd() _Game:endLevel() end
---Ends the current level without saving its data and marks it as a win.
function api.levelWin() _Game:winLevel() end
---Ends the current level and saves its data in the current profile.
function api.levelSave() _Game:saveLevel() end
---Exits the game.
function api.quit() _Game:quit() end

---Returns `true` if a level is in progress and can be accessed, `false` otherwise.
---@return boolean
function api.levelExists() return _Game.level ~= nil end
---Returns the percentage progress of the `n`-th objective as a number in range [0, 1].
---@param n integer? The objective index, defaults to 1.
---@return number
function api.levelGetProgress(n) return _Game.level:getObjectiveProgress(n or 1) end
---Returns a list of objectives in the current level.
---@return LevelObjective[]
function api.levelGetObjectives() return _Game.level.objectives end
---Returns the total amount of points scored in this level.
---@return integer
function api.levelGetScore() return _Game.level.score end
---Returns the total amount of shot spheres in this level.
---@return integer
function api.levelGetShots() return _Game.level.spheresShot end
---Returns the total amount of coins collected in this level.
---@return integer
function api.levelGetCoins() return _Game.level.coins end
---Returns the total amount of gems collected in this level.
---@return integer
function api.levelGetGems() return _Game.level.gems end
---Returns the total amount of sphere trains spawned in this level.
---@return integer
function api.levelGetChains() return _Game.level.sphereChainsSpawned end
---Returns the current streak value (amount of consecutive matches) in this level.
---@return integer
function api.levelGetStreak() return _Game.level.streak end
---Returns the maximum streak value (amount of consecutive matches) achieved in this level.
---@return integer
function api.levelGetMaxStreak() return _Game.level.maxStreak end
---Returns the maximum cascade value (chain reactions) achieved in this level.
---@return integer
function api.levelGetMaxCascade() return _Game.level.maxCascade end
---Returns whether this level score beats the previously recorded best score for this level.
---@return boolean
function api.levelGetNewRecord() return _Game.level:hasNewScoreRecord() end
---Returns the current shot accuracy in this level as a percentage from 0 to 1.
---@return number
function api.levelGetAccuracy() return _Game.level:getShotAccuracy() end

---Executes a Score Event on the current level.
---@param event string Path to the Score Event to be evaluated and executed.
---@param x number? X position of the score event, used for floating text.
---@param y number? Y position of the score event, used for floating text.
function api.levelExecuteScoreEvent(event, x, y) _Game.level:executeScoreEvent(_Res:getScoreEventConfig(event), x, y) end

---Plays or resumes the specified Music Track.
---@param music string Path to the Music Track to be affected.
---@param duration number? If specified, the track will fade in for this time in seconds. Otherwise, the change will be instant.
function api.musicPlay(music, duration) _Res:getMusicTrack(music):play(duration) end
---Pauses the specified Music Track.
---@param music string Path to the Music Track to be affected.
---@param duration number? If specified, the track will fade out for this time in seconds. Otherwise, the change will be instant.
function api.musicPause(music, duration) _Res:getMusicTrack(music):pause(duration) end
---Stops the specified Music Track.
---@param music string Path to the Music Track to be affected.
---@param duration number? If specified, the track will fade out for this time in seconds. Otherwise, the change will be instant.
function api.musicStop(music, duration) _Res:getMusicTrack(music):stop(duration) end
---Changes the volume of the specified Music Track. This is independent from the music volume set by the game settings.
---@param music string Path to the Music Track to be affected.
---@param volume number New volume for this Music Track.
---@param duration number? If specified, the change time in seconds. Otherwise, the change will be instant.
function api.musicVolume(music, volume, duration) _Res:getMusicTrack(music):setVolume(volume, duration) end
---comment
---@param playlist any
---@param duration any
function api.playlistPlay(playlist, duration) _Res:getMusicPlaylist(playlist):getTrack():play(duration) end
---comment
---@param playlist any
---@param duration any
function api.playlistPause(playlist, duration) _Res:getMusicPlaylist(playlist):getTrack():pause(duration) end
---comment
---@param playlist any
---@param duration any
function api.playlistStop(playlist, duration) _Res:getMusicPlaylist(playlist):getTrack():stop(duration) end
---comment
---@param playlist any
---@param volume any
---@param duration any
function api.playlistVolume(playlist, volume, duration) _Res:getMusicPlaylist(playlist):getTrack():setVolume(volume, duration) end
---comment
---@param playlist any
function api.playlistSkip(playlist) _Res:getMusicPlaylist(playlist):nextTrack() end
---comment
---@param sound any
function api.playSound(sound) _Res:getSoundEvent(sound):play() end

---comment
---@param name any
function api.profileMSet(name) _Game.profileManager:setCurrentProfile(name) end
---comment
---@param name any
---@return boolean
function api.profileMCreate(name) return _Game.profileManager:createProfile(name) end
---comment
---@param name any
function api.profileMDelete(name) _Game.profileManager:deleteProfile(name) end

---comment
---@return table
function api.profileMGetNameOrder() return _Game.profileManager.order end

---comment
---@param checkpoint any
---@param difficulty any
function api.profileNewGame(checkpoint, difficulty) _Game:getProfile():newGame(checkpoint, _Res:getDifficultyConfig(difficulty)) end
---comment
function api.profileDeleteGame() _Game:getProfile():deleteGame() end
---comment
function api.profileLevelAdvance() _Game:getSession():advanceLevel() end
---comment
---@return integer?
function api.profileHighscoreWrite() return _Game:getSession():writeHighscore() end

---comment
---@return boolean
function api.profileGetExists() return _Game:getProfile() ~= nil end
---comment
---@return string
function api.profileGetName() return _Game:getProfile().name end
---comment
---@return unknown
function api.profileGetLives() return _Game:getSession():getLives() end
---comment
---@return integer
function api.profileGetCoins() return _Game:getSession():getCoins() end
---comment
---@return integer
function api.profileGetScore() return _Game:getSession():getScore() end
---comment
---@return ProfileSession?
function api.profileGetSession() return _Game:getSession() end
---comment
---@return integer
function api.profileGetLevel() return _Game:getSession():getTotalLevel() end
---comment
---@return LevelConfig
function api.profileGetLevelData() return _Game:getSession():getLevelData() end
---comment
---@return string
function api.profileGetLevelName() return _Game:getSession():getLevelName() end
---comment
---@return DifficultyConfig
function api.profileGetDifficultyConfig() return _Game:getSession():getDifficultyConfig() end
---comment
---@return table?
function api.profileGetSavedLevel() return _Game:getSession():getLevelSaveData() end
---comment
---@return table?
function api.profileGetMap() return _Game:getSession():getMapData() end
---comment
---@return integer?
function api.profileGetLatestCheckpoint() return _Game:getSession():getLatestCheckpoint() end
---comment
---@param levelSet any
---@return integer[]
function api.profileGetUnlockedCheckpoints(levelSet) return _Game:getProfile():getUnlockedCheckpoints(_Res:getLevelSetConfig(levelSet)) end
---comment
---@param levelSet any
---@param n any
---@return boolean
function api.profileIsCheckpointUnlocked(levelSet, n) return _Game:getProfile():isCheckpointUnlocked(_Res:getLevelSetConfig(levelSet), n) end
---comment
---@return boolean
function api.profileIsCheckpointUpcoming() return _Game:getSession():isCheckpointUpcoming() end

---comment
---@param name any
---@param value any
function api.profileSetVariable(name, value) _Game:getProfile():setVariable(name, value) end
---comment
---@param name any
---@return any
function api.profileGetVariable(name) return _Game:getProfile():getVariable(name) end

---comment
function api.highscoreReset() _Game.highscores:reset() end
---comment
---@param n any
---@return table
function api.highscoreGetEntry(n) return _Game.highscores:getEntry(n) end

---comment
---@param key any
---@param ... unknown
---@return string
function api.translate(key, ...) return _Game:translate(key, ...) end
---comment
---@param name any
---@return table
function api.configGetMapData(name) return _Game:getMapData(name) end
---comment
---@param levelSet any
---@param n any
---@return unknown
function api.configGetLevelData(levelSet, n) return _Res:getLevelSetConfig(levelSet).levelOrder[n].level end
---comment
---@param levelSet any
---@param n any
---@return unknown
function api.configGetLevelName(levelSet, n) return _Res:getLevelSetConfig(levelSet).levelOrder[n].name end
---comment
---@param levelSet any
---@return integer
function api.configGetLevelCount(levelSet) return #_Res:getLevelSetConfig(levelSet).levelOrder end
---comment
---@param levelSet any
---@param n any
---@return integer
function api.configGetCheckpointID(levelSet, n) return _Game:getProfile():getCheckpointData(_Res:getLevelSetConfig(levelSet))[n].levelID end
---comment
---@param levelSet any
---@param n any
---@return integer
function api.configGetCheckpointLevel(levelSet, n) return _Game:getProfile():getCheckpointLevelN(_Res:getLevelSetConfig(levelSet), n) end
---comment
---@param levelSet any
---@return integer
function api.configGetCheckpointCount(levelSet) return #_Game:getProfile():getCheckpointData(_Res:getLevelSetConfig(levelSet)) end

---comment
---@return any
function api.optionsGetMusicVolume() return _Game.options:getSetting("musicVolume") end
---comment
---@return any
function api.optionsGetSoundVolume() return _Game.options:getSetting("soundVolume") end
---comment
---@return any
function api.optionsGetFullscreen() return _Game.options:getSetting("fullscreen") end
---comment
---@return any
function api.optionsGetMute() return _Game.options:getSetting("mute") end
---comment
---@param volume any
function api.optionsSetMusicVolume(volume) _Game.options:setSetting("musicVolume", volume) end
---comment
---@param volume any
function api.optionsSetSoundVolume(volume) _Game.options:setSetting("soundVolume", volume) end
---comment
---@param fullscreen any
function api.optionsSetFullscreen(fullscreen) _Game.options:setSetting("fullscreen", fullscreen) end
---comment
---@param mute any
function api.optionsSetMute(mute) _Game.options:setSetting("mute", mute) end

---comment
---@param name any
---@param data any
function api.load(name, data) _Game.uiManager:loadRootNode(name, data) end
---comment
---@param name any
function api.unload(name) _Game.uiManager:unloadRootNode(name) end
---comment
---@param names any
---@return UIWidget?
function api.getWidgetN(names) return _Game.uiManager:getWidgetN(names) end
---comment
---@param names any
---@return UIWidget[]
function api.getWidgetListN(names) return _Game.uiManager:getWidgetListN(names) end
---comment
function api.resetActive() _Game.uiManager:resetActive() end

return api