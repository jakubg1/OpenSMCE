local class = require "com/class"
local BootSettings = class:derive("BootSettings")

local Vec2 = require("src/Essentials/Vector2")
local Button = require("src/Kernel/UI/Button")
local Checkbox = require("src/Kernel/UI/Checkbox")



function BootSettings:new(bootScreen)
  self.bootScreen = bootScreen

	-- prepare fonts of various sizes
	self.font = love.graphics.newFont()
	self.fontBig = love.graphics.newFont(18)

	-- buttons
	self.saveBtn = Button("Save", self.fontBig, Vec2(514, 546), Vec2(128, 24), function() _EngineSettings:save(); self.bootScreen:setScene("main") end)
	self.menuBtn = Button("Cancel", self.fontBig, Vec2(642, 546), Vec2(128, 24), function() self.bootScreen:setScene("main") end)
	self.settingCheckboxes = {
    Checkbox("Enable Discord Rich Presence", self.fontBig, Vec2(40, 110), Vec2(760, 24), function(state) _EngineSettings:setDiscordRPC(state) end),
    Checkbox("Go back to the boot menu when exiting a game", self.fontBig, Vec2(40, 140), Vec2(760, 24), function(state) _EngineSettings:setBackToBoot(state) end),
    Checkbox("Aiming Retical", self.fontBig, Vec2(40, 170), Vec2(760, 24), function(state) _EngineSettings:setAimingRetical(state) end),
    Checkbox("Debug console window (restart to see the effect)", self.fontBig, Vec2(40, 200), Vec2(760, 24), function(state) _EngineSettings:setConsoleWindow(state) end),
    Checkbox("Enable 3D Sound", self.fontBig, Vec2(40, 230), Vec2(760, 24), function(state) _EngineSettings:set3DSound(state) end)
  }
end



function BootSettings:init()
  self.settingCheckboxes[1].selected = _EngineSettings:getDiscordRPC()
  self.settingCheckboxes[2].selected = _EngineSettings:getBackToBoot()
  self.settingCheckboxes[3].selected = _EngineSettings:getAimingRetical()
  self.settingCheckboxes[4].selected = _EngineSettings:getConsoleWindow()
  self.settingCheckboxes[5].selected = _EngineSettings:get3DSound()
end



function BootSettings:update(dt)
	-- buttons
	self.saveBtn:update(dt)
	self.menuBtn:update(dt)
  for i, checkbox in ipairs(self.settingCheckboxes) do
    checkbox:update(dt)
  end
end



function BootSettings:draw()
	-- White color
	love.graphics.setColor(1, 1, 1)

	-----------------------------
	-- HEADER
	-----------------------------
	love.graphics.setFont(self.fontBig)
	love.graphics.print("OpenSMCE Boot Menu", 30, 30)
	local s = string.format("Version: %s (%s)", _VERSION_NAME, _VERSION)
	love.graphics.print(s, 770 - self.fontBig:getWidth(s), 30)

	-----------------------------
	-- SETTING LIST
	-----------------------------
	love.graphics.print("Settings", 30, 70)
	love.graphics.setColor(1, 1, 1)
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 30, 100, 740, 200) -- frame

	-----------------------------
	-- DRAWING
	-----------------------------
	self.saveBtn:draw()
	self.menuBtn:draw()
  for i, checkbox in ipairs(self.settingCheckboxes) do
    checkbox:draw()
  end

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
