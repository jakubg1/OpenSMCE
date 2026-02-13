local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")
local Button = require("src.BootScreen.UI.Button")
local Checkbox = require("src.BootScreen.UI.Checkbox")

---@class BootSettings
---@overload fun(bootScreen: BootScreen):BootSettings
local BootSettings = class:derive("BootSettings")

---Constructs a new Boot Screen's Settings menu.
---@param bootScreen BootScreen The boot screen this Settings menu is a part of.
function BootSettings:new(bootScreen)
  	self.bootScreen = bootScreen

	---@type {name: string, key: Setting, tooltip: string}[]
	self.SETTINGS = {
		{name = "Enable Discord Rich Presence", key = "discordRPC", tooltip = "Shows your game progress in your Discord profile, if you have Discord running\non your computer.\n\nThis feature currently works only on Windows systems."},
		{name = "Go back to Boot Screen after closing a game", key = "backToBoot", tooltip = "If enabled, when quitting a game, the Boot Screen will show up again."},
		{name = "  Even if the game window is closed by X", key = "backToBootWithX", tooltip = "If enabled, when quitting a game by pressing X on the window, the Boot Screen\nwill show up again as well."},
		{name = "Maximize On Start", key = "maximizeOnStart", tooltip = "Some games have a large native resolution, which is bigger than the desktop size.\nThis setting makes sure that the window will be maximized to prevent overgrowing."},
		{name = "Aiming Retical", key = "aimingRetical", tooltip = "Enables the Aiming Retical, which is either one defined by the game or\na simple placeholder, if not defined."},
		{name = "Debug console window", key = "consoleWindow", tooltip = "Whether a separate console window should appear when launching the game.\nUseful for debugging.\nThis setting does not work when running directly from the source code,\nbut the console output will be suppressed.\nYou will need to restart the engine for this setting change to take effect."},
		{name = "Enable 3D Sound", key = "threedeeSound", tooltip = "Enables 3D sound.\nThat means sounds which originate on the left side of the screen will lean\nslightly more towards the left speaker, and these which originate on the right\nside will be amplified on the right speaker."},
		{name = "Hide incompatible games", key = "hideIncompatibleGames", tooltip = "Hides all incompatible games from the boot menu, including games which have\nan unknown supported version.\n\nThis setting requires a restart to take effect."},
		{name = "Print deprecation notices", key = "printDeprecationNotices", tooltip = "For developers!\n\nEnables printing code deprecation notices."},
		{name = "Enable Profiler", key = "enableProfiler", tooltip = "For developers!\n\nEnables performance profiling.\nRequires an engine restart."}
	}

	-- buttons
	self.saveBtn = Button("Save", _FONT_BIG, Vec2(540, 530), Vec2(230, 24), function() self:save() end)
	self.menuBtn = Button("Cancel", _FONT_BIG, Vec2(540, 554), Vec2(230, 24), function() self:cancel() end)
	---@type Checkbox[]
	self.settingCheckboxes = {}
	for i, setting in ipairs(self.SETTINGS) do
		table.insert(self.settingCheckboxes, Checkbox(setting.name, _FONT_BIG, Vec2(34, 64 + (i - 1) * 24), Vec2(732, 24), function(state) _Settings:setWorkSetting(setting.key, state) end))
	end

	-- tooltip
	self.tooltip = nil
end

---Sets the initial states for the setting checkboxes.
function BootSettings:init()
	for i, checkbox in ipairs(self.settingCheckboxes) do
		checkbox.selected = _Settings:getWorkSetting(self.SETTINGS[i].key)
	end
end

---Updates the Boot Screen's Settings menu.
---@param dt number Time delta in seconds.
function BootSettings:update(dt)
	self.tooltip = nil
	-- buttons
	self.saveBtn:update(dt)
	self.menuBtn:update(dt)
	for i, checkbox in ipairs(self.settingCheckboxes) do
		checkbox:update(dt)
		if checkbox.hovered then
			self.tooltip = self.SETTINGS[i].tooltip
		end
	end
end

---Saves the new settings and goes back to the main boot screen.
---@private
function BootSettings:save()
	_Settings:saveWork()
	_Settings:save()
	self.bootScreen:setScene("main")
end

---Discards the new settings and goes back to the main boot screen.
---@private
function BootSettings:cancel()
	_Settings:restoreWork()
	self.bootScreen:setScene("main")
end

---Draws the Boot Screen's Settings menu.
function BootSettings:draw()
	-- White color
	love.graphics.setColor(1, 1, 1)

	-----------------------------
	-- HEADER
	-----------------------------
	love.graphics.setFont(_FONT_BIG)
	love.graphics.print("Engine Settings", 30, 22)

	-----------------------------
	-- SETTING LIST
	-----------------------------
	self.saveBtn:draw()
	self.menuBtn:draw()
	for i, checkbox in ipairs(self.settingCheckboxes) do
		checkbox:draw()
	end
	-- Tooltip
	if self.tooltip then
		love.graphics.setColor(1, 1, 0)
		love.graphics.setFont(_FONT)
		love.graphics.print(self.tooltip, 30, 525)
	end
	-- Frame
	love.graphics.setColor(1, 1, 1)
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 30, 60, 740, #self.settingCheckboxes * 24 + 8) -- max h: 440
end

---Executed when a mouse button is released.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button.
function BootSettings:mousereleased(x, y, button)
	-- Buttons
	self.saveBtn:mousereleased(x, y, button)
	self.menuBtn:mousereleased(x, y, button)
	for i, checkbox in ipairs(self.settingCheckboxes) do
		checkbox:mousereleased(x, y, button)
	end
end

return BootSettings
