local class = require "com.class"

---@class BootSettings
---@overload fun(bootScreen):BootSettings
local BootSettings = class:derive("BootSettings")

local Vec2 = require("src.Essentials.Vector2")
local Button = require("src.Kernel.UI.Button")
local Checkbox = require("src.Kernel.UI.Checkbox")



function BootSettings:new(bootScreen)
  	self.bootScreen = bootScreen

	-- buttons
	self.saveBtn = Button("Save", _FONT_BIG, Vec2(540, 530), Vec2(230, 24), function() _EngineSettings:save(); self.bootScreen:setScene("main") end)
	self.menuBtn = Button("Cancel", _FONT_BIG, Vec2(540, 554), Vec2(230, 24), function() self.bootScreen:setScene("main") end)
	self.settingCheckboxes = {
		Checkbox("Enable Discord Rich Presence", _FONT_BIG, Vec2(34, 64), Vec2(732, 24), function(state) _EngineSettings:setDiscordRPC(state) end),
		Checkbox("Go back to the boot menu when exiting a game", _FONT_BIG, Vec2(34, 88), Vec2(732, 24), function(state) _EngineSettings:setBackToBoot(state) end),
		Checkbox("Aiming Retical", _FONT_BIG, Vec2(34, 112), Vec2(732, 24), function(state) _EngineSettings:setAimingRetical(state) end),
		Checkbox("Debug console window", _FONT_BIG, Vec2(34, 136), Vec2(732, 24), function(state) _EngineSettings:setConsoleWindow(state) end),
		Checkbox("Enable 3D Sound", _FONT_BIG, Vec2(34, 160), Vec2(732, 24), function(state) _EngineSettings:set3DSound(state) end),
		Checkbox("Hide incompatible games", _FONT_BIG, Vec2(34, 184), Vec2(732, 24), function(state) _EngineSettings:setHideIncompatibleGames(state) end)
	}

	-- tooltip
	self.TOOLTIPS = {
		"Shows your game progress in your Discord profile, if you have Discord running\non your computer.",
		"If enabled, when quitting a game, the Boot Screen will show up again.\nThis setting does NOT affect quitting by pressing X on the window!",
		"Enables Aiming Retical, which is either one defined by the game or\na simple placeholder, if not defined.",
		"Whether a separate console window should appear when launching the game.\nUseful for debugging.\nThis setting does not work when running directly from the source code,\nbut the console output will be suppressed.\nYou will need to restart the engine for this setting change to take effect.",
		"Enables 3D sound.\nThat means sounds which originate on the left side of the screen will lean\nslightly more towards the left speaker, and these which originate on the right\nside will be amplified on the right speaker.\nSome sounds do not support this functionality yet.",
		"Hides all incompatible games from the boot menu, including games which have\nan unknown supported version."
	}
	self.tooltip = nil
end



function BootSettings:init()
	self.settingCheckboxes[1].selected = _EngineSettings:getDiscordRPC()
	self.settingCheckboxes[2].selected = _EngineSettings:getBackToBoot()
	self.settingCheckboxes[3].selected = _EngineSettings:getAimingRetical()
	self.settingCheckboxes[4].selected = _EngineSettings:getConsoleWindow()
	self.settingCheckboxes[5].selected = _EngineSettings:get3DSound()
	self.settingCheckboxes[6].selected = _EngineSettings:getHideIncompatibleGames()
end



function BootSettings:update(dt)
	self.tooltip = nil
	-- buttons
	self.saveBtn:update(dt)
	self.menuBtn:update(dt)
	for i, checkbox in ipairs(self.settingCheckboxes) do
		checkbox:update(dt)
		if checkbox.hovered then
			self.tooltip = self.TOOLTIPS[i]
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
