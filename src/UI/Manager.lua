local class = require "com.class"
local ScriptAPI = require("src.UI.ScriptAPI")
local UIWidget = require("src.UI.Widget")

---@class UIManager
---@overload fun():UIManager
local UIManager = class:derive("UIManager")

---Constructs the UI Manager.
function UIManager:new()
    ---@type table<string, UIWidget?>
    self.widgets = {splash = nil, root = nil}

    self.script = nil

    self.hasFocus = true
end

---Loads a new root node into the UI Manager.
---@param name string The root node name, which is used in the paths.
---@param data string|table Path to the UI file to be loaded or raw UI data (not recommended).
function UIManager:loadRootNode(name, data)
    self.widgets[name] = UIWidget(data)
end

---Unloads a root node from the UI Manager.
---@param name string The root node name, which is used in the paths.
function UIManager:unloadRootNode(name)
    self.widgets[name] = nil
end

---Loads the UI Script and fires the `init` UI Script callback.
function UIManager:loadScript()
    self.script = require(_ParsePathDots("ui.script"))
    self:executeCallback("init")
end

---Updates the UI Manager.
---@param dt number Time delta in seconds.
function UIManager:update(dt)
    -- despite being called since the splash screen starts, scripts are loaded when the main game widgets are loaded, and therefore this tick is called only after such event happens
    self:executeCallback("tick", {dt})

    if self.hasFocus ~= love.window.hasFocus() then
        self.hasFocus = love.window.hasFocus()
        if not self.hasFocus then
            self:executeCallback("lostFocus")
        end
    end

    for widgetN, widget in pairs(self.widgets) do
        widget:update(dt)
    end
end

---Draws all UI elements on the screen.
function UIManager:draw()
    _Debug.uiWidgetCount = 0
    -- Draw the UI widgets.
    for widgetN, widget in pairs(self.widgets) do
        widget:draw()
    end
end

---Executed when a mouse button is pressed.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button.
function UIManager:mousepressed(x, y, button)
    if button == 1 then
        for widgetN, widget in pairs(self.widgets) do
            widget:click()
        end
    end
end

---Executed when a mouse button is released.
---@param x integer The X coordinate of mouse position.
---@param y integer The Y coordinate of mouse position.
---@param button integer The mouse button.
function UIManager:mousereleased(x, y, button)
    if button == 1 then
        for widgetN, widget in pairs(self.widgets) do
            widget:unclick()
        end
        self:executeCallback("click")
    end
end

---Executed when a key is pressed.
---@param key string The key code.
function UIManager:keypressed(key)
    for widgetN, widget in pairs(self.widgets) do
        widget:keypressed(key)
    end
end

---Executed when text is entered.
---@param t string The entered text.
function UIManager:textinput(t)
    for widgetN, widget in pairs(self.widgets) do
        widget:textinput(t)
    end
end

---Executes a UI script callback function, if it exists. Does nothing if the function does not exist in the UI script.
---@param name string The function name.
---@param parameters any[]? If specified, this is a list of parameters which will be passed to the executed function as a list.
function UIManager:executeCallback(name, parameters)
    local f = self.script[name]
    if f then
        f(ScriptAPI, parameters)
    end
end

---Temporary function. Works like `:executeCallback()` but you give the function itself.
---@param f function The function.
---@param parameters any[]? If specified, this is a list of parameters which will be passed to the executed function as a list.
function UIManager:executeFunction(f, parameters)
    f(ScriptAPI, parameters)
end

---Deactivates all Widgets, which means they are no longer interactable.
function UIManager:resetActive()
    for widgetN, widget in pairs(self.widgets) do
        widget:resetActive()
    end
end

---Returns whether any meaningful UI widget like a button has been hovered.
---@return boolean
function UIManager:isButtonHovered()
    if _Debug.uiDebug:isHovered() then
        return false
    end
    for widgetN, widget in pairs(self.widgets) do
        if widget:isButtonHovered() then
            return true
        end
    end
    return false
end

---Returns a widget by its path. If no widget exists at the given location, returns `nil`.
---@param names string[] Path to the widget represented as a list of widget names to traverse through, starting from one of the root widget names.
---@return UIWidget?
function UIManager:getWidget(names)
    local widget = self.widgets[names[1]]
    for i, name in ipairs(names) do
        if i > 1 then
            if not widget then
                --error("Could not find a widget: \"" .. strJoin(names, "/") .. "\"")
                return
            end
            widget = widget:getChildN(name)
        end
    end
    return widget
end

---Returns a widget by its path. If no widget exists at the given location, returns `nil`.
---@param names string Path to the widget represented as widget names separated by slashes, starting from one of the root widget names.
---@return UIWidget?
function UIManager:getWidgetN(names)
    return self:getWidget(_Utils.strSplit(names, "/"))
end

---Returns a list of children widgets of the widget by its path. The child names must start at `1` and be a sequence of numbers.
---For example, if `root/List` is provided, the function will return a list of nodes at `root/List/1`, `root/List/2` and so on.
---@param names string Path to the widget represented as widget names separated by slashes, starting from one of the root widget names.
---@return UIWidget[]
function UIManager:getWidgetListN(names)
    local widgets = {}
    local i = 1
    while self:getWidgetN(names .. "/" .. tostring(i)) do
        widgets[i] = self:getWidgetN(names .. "/" .. tostring(i))
        i = i + 1
    end
    return widgets
end

---Returns the default Sound Event which will be played when a UI button is pressed.
---@return SoundEvent?
function UIManager:getButtonClickSound()
    -- TODO: Move the `ui` section to a separate file or directly inside of the Game Config.
	return _Game.gameplayConfig.ui.buttonClickSound
end

---Returns the default Sound Event which will be played when a UI button is released.
---@return SoundEvent?
function UIManager:getButtonReleaseSound()
    -- TODO: Move the `ui` section to a separate file or directly inside of the Game Config.
	return _Game.gameplayConfig.ui.buttonReleaseSound
end

---Returns the default Sound Event which will be played when a UI button is hovered.
---@return SoundEvent?
function UIManager:getButtonHoverSound()
    -- TODO: Move the `ui` section to a separate file or directly inside of the Game Config.
	return _Game.gameplayConfig.ui.buttonHoverSound
end

return UIManager
