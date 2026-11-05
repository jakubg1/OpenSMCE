local Class = require("com.class")
local Vec2 = require("src.Essentials.Vector2")

---Base class for the GameBase, BootScreen, EditorMain and TestMain.
---@class RootScene : Class
---@abstract
---@overload fun(): RootScene
local RootScene = Class:derive("RootScene")

---Creates a Root Scene.
---This is an abstract class and should not be instantiated directly.
function RootScene:new()
	self.nativeResolution = Vec2(800, 600)
	self.isBootScreen = false
    ---@type string?
    self.name = nil
    ---@type Game?
    self.game = nil
    ---@type ParticleManager?
    self.particleManager = nil
    ---@type Timer?
    self.timer = nil
	error("RootScene is an abstract class and cannot be instantiated directly. Fix ur code smhsmh")
end

---Updates the scene.
---@param dt number Time delta in seconds.
function RootScene:update(dt)
	-- STUB
end

---Draws the scene on the screen.
function RootScene:draw()
	-- STUB
end

---Returns the native resolution of the scene, which is always 800 by 600.
---@return integer, integer
function RootScene:getNativeResolution()
	return self.nativeResolution.x, self.nativeResolution.y
end

---Returns whether the Discord Rich Presence should be active in this scene.
---@return boolean
function RootScene:isRichPresenceEnabled()
	return false
end

---Returns the Rich Presence Application ID for this scene, if it exists.
---@return string?
function RootScene:getRichPresenceApplicationID()
	return nil
end

---Returns the effective sound volume.
---@return number
function RootScene:getSoundVolume()
	return 1
end

---Returns the effective music volume.
---@return number
function RootScene:getMusicVolume()
	return 1
end

---Do not use. Throws the not implemented error. This function is used to silence warnings.
function RootScene:getTickRate()
	error("Not implemented")
end

---Do not use. Throws the not implemented error. This function is used to silence warnings.
function RootScene:gameOver()
	error("Not implemented")
end

---Do not use. Throws the not implemented error. This function is used to silence warnings.
function RootScene:spawnParticle(particleEffect, x, y, layer)
	error("Not implemented")
end

---Do not use. Throws the not implemented error. This function is used to silence warnings.
function RootScene:executeGameEvent(event, x, y)
	error("Not implemented")
end

---Do not use. Throws the not implemented error. This function is used to silence warnings.
function RootScene:getProfile()
	error("Not implemented")
end

---Do not use. Throws the not implemented error. This function is used to silence warnings.
function RootScene:getSession()
	error("Not implemented")
end

---Do not use. Throws the not implemented error. This function is used to silence warnings.
function RootScene:save()
	error("Not implemented")
end

---Do not use. Throws the not implemented error. This function is used to silence warnings.
function RootScene:translate(key, ...)
	error("Not implemented")
end

---Executed when a mouse button is pressed.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button.
function RootScene:mousepressed(x, y, button)
	-- STUB
end

---Executed when a mouse button is released.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button.
function RootScene:mousereleased(x, y, button)
	-- STUB
end

---Executed when a mouse wheel is scrolled.
---@param x integer The X wheel movement.
---@param y integer The Y wheel movement.
function RootScene:wheelmoved(x, y)
	-- STUB
end

---Executed when a key is pressed.
---@param key string The key code.
function RootScene:keypressed(key)
	-- STUB
end

---Executed when a key is released.
---@param key string The key code.
function RootScene:keyreleased(key)
	-- STUB
end

---Executed when some text is entered.
---@param t string The entered text.
function RootScene:textinput(t)
	-- STUB
end

---Exits the scene (or the entire game).
function RootScene:quit(forced)
	love.event.quit()
end

return RootScene