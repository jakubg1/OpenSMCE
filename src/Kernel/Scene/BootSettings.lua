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
	self.menuBtn = Button("Save and Go Back", self.fontBig, Vec2(30, 546), Vec2(300, 24), function() engineSettings:save(); self.bootScreen:setScene("main") end)
	self.settingCheckboxes = {
    Checkbox("Enable Discord Rich Presence", self.fontBig, Vec2(40, 110), Vec2(760, 24), function(state) engineSettings:setDiscordRPC(state) end),
    Checkbox("Go back to the boot menu when exiting a game", self.fontBig, Vec2(40, 140), Vec2(760, 24), function(state) engineSettings:setBackToBoot(state) end),
    Checkbox("Aiming Retical", self.fontBig, Vec2(40, 170), Vec2(760, 24), function(state) engineSettings:setAimingRetical(state) end),
    Checkbox("Debug console window (restart to see the effect)", self.fontBig, Vec2(40, 200), Vec2(760, 24), function(state) engineSettings:setConsoleWindow(state) end),
    Checkbox("Enable 3D Sound", self.fontBig, Vec2(40, 230), Vec2(760, 24), function(state) engineSettings:set3DSound(state) end)
  }
end



function BootSettings:init()
  self.settingCheckboxes[1].selected = engineSettings:getDiscordRPC()
  self.settingCheckboxes[2].selected = engineSettings:getBackToBoot()
  self.settingCheckboxes[3].selected = engineSettings:getAimingRetical()
  self.settingCheckboxes[4].selected = engineSettings:getConsoleWindow()
  self.settingCheckboxes[5].selected = engineSettings:get3DSound()
end



function BootSettings:update(dt)
	-- buttons
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
	love.graphics.print(string.format("Version: %s (%s)", VERSION_NAME, VERSION), 520, 30)

	-----------------------------
	-- SETTING LIST
	-----------------------------
	love.graphics.print("Settings", 30, 70)
	love.graphics.setColor(1, 1, 1)
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 30, 100, 740, 200) -- frame

	-----------------------------
	-- GO BACK BUTTON
	-----------------------------
	self.menuBtn:draw()
  for i, checkbox in ipairs(self.settingCheckboxes) do
    checkbox:draw()
  end

end



function BootSettings:mousereleased(x, y, button)
	-- Buttons
	self.menuBtn:mousereleased(x, y, button)
  for i, checkbox in ipairs(self.settingCheckboxes) do
    checkbox:mousereleased(x, y, button)
  end
end



return BootSettings
