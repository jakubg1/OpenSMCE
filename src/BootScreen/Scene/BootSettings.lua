local class = require "com.class"

---@class BootSettings
---@overload fun(bootScreen):BootSettings
local BootSettings = class:derive("BootSettings")

local Vec2 = require("src.Essentials.Vector2")
local Button = require("src.BootScreen.UI.Button")
local Checkbox = require("src.BootScreen.UI.Checkbox")



function BootSettings:new(bootScreen)
  	self.bootScreen = bootScreen

	self.SETTINGS = {
		{name = "Enable Discord Rich Presence", f = function(state) _EngineSettings:setDiscordRPC(state) end, tooltip = "Shows your game progress in your Discord profile, if you have Discord running\non your computer.\n\nThis feature currently works only on Windows systems."},
		{name = "Go back to Boot Screen after closing a game", f = function(state) _EngineSettings:setBackToBoot(state) end, tooltip = "If enabled, when quitting a game, the Boot Screen will show up again."},
		{name = "  Even if the game window is closed by X", f = function(state) _EngineSettings:setBackToBootWithX(state) end, tooltip = "If enabled, when quitting a game by pressing X on the window, the Boot Screen\nwill show up again as well."},
		{name = "Maximize On Start", f = function(state) _EngineSettings:setMaximizeOnStart(state) end, tooltip = "Some games have a large native resolution, which is bigger than the desktop size.\nThis setting makes sure that the window will be maximized to prevent overgrowing."},
		{name = "Aiming Retical", f = function(state) _EngineSettings:setAimingRetical(state) end, tooltip = "Enables the Aiming Retical, which is either one defined by the game or\na simple placeholder, if not defined."},
		{name = "Debug console window", f = function(state) _EngineSettings:setConsoleWindow(state) end, tooltip = "Whether a separate console window should appear when launching the game.\nUseful for debugging.\nThis setting does not work when running directly from the source code,\nbut the console output will be suppressed.\nYou will need to restart the engine for this setting change to take effect."},
		{name = "Enable 3D Sound", f = function(state) _EngineSettings:set3DSound(state) end, tooltip = "Enables 3D sound.\nThat means sounds which originate on the left side of the screen will lean\nslightly more towards the left speaker, and these which originate on the right\nside will be amplified on the right speaker."},
		{name = "Hide incompatible games", f = function(state) _EngineSettings:setHideIncompatibleGames(state) end, tooltip = "Hides all incompatible games from the boot menu, including games which have\nan unknown supported version."},
		{name = "Print deprecation notices", f = function(state) _EngineSettings:setPrintDeprecationNotices(state) end, tooltip = "For developers!\n\nEnables printing code deprecation notices."}
	}

	-- buttons
	self.saveBtn = Button("Save", _FONT_BIG, Vec2(540, 530), Vec2(230, 24), function() _EngineSettings:save(); self.bootScreen:setScene("main") end)
	self.menuBtn = Button("Cancel", _FONT_BIG, Vec2(540, 554), Vec2(230, 24), function() self.bootScreen:setScene("main") end)
	self.settingCheckboxes = {}
	for i, setting in ipairs(self.SETTINGS) do
		table.insert(self.settingCheckboxes, Checkbox(setting.name, _FONT_BIG, Vec2(34, 64 + (i - 1) * 24), Vec2(732, 24), setting.f))
	end

	-- tooltip
	self.tooltip = nil
end



function BootSettings:init()
	self.settingCheckboxes[1].selected = _EngineSettings:getDiscordRPC()
	self.settingCheckboxes[2].selected = _EngineSettings:getBackToBoot()
	self.settingCheckboxes[3].selected = _EngineSettings:getBackToBootWithX()
	self.settingCheckboxes[4].selected = _EngineSettings:getMaximizeOnStart()
	self.settingCheckboxes[5].selected = _EngineSettings:getAimingRetical()
	self.settingCheckboxes[6].selected = _EngineSettings:getConsoleWindow()
	self.settingCheckboxes[7].selected = _EngineSettings:get3DSound()
	self.settingCheckboxes[8].selected = _EngineSettings:getHideIncompatibleGames()
	self.settingCheckboxes[9].selected = _EngineSettings:getPrintDeprecationNotices()
end



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



function BootSettings:mousereleased(x, y, button)
	-- Buttons
	self.saveBtn:mousereleased(x, y, button)
	self.menuBtn:mousereleased(x, y, button)
	for i, checkbox in ipairs(self.settingCheckboxes) do
		checkbox:mousereleased(x, y, button)
	end
end



return BootSettings
