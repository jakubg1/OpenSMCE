local class = require "com/class"

---@class UI2Node
---@overload fun(manager, config, name, parent):UI2Node
local UI2Node = class:derive("UI2Node")

-- Place your imports here
local UI2WidgetRectangle = require("src/UI2/WidgetRectangle")

local Vec2 = require("src/Essentials/Vector2")



---Constructs a new UI2Node.
---@param manager UI2Manager The UI2 Manager this Node belongs to.
---@param config UI2NodeConfig The UI2 Node Config which describes this Node.
---@param name string Specifies the name of this Node. Should match with this Parent's child of this name, or "root" / "splash" if no parent specified.
---@param parent UI2Node? The UI2 Node which is a parent of this Node. If not specified, this will be a root node.
function UI2Node:new(manager, config, name, parent)
    self.manager = manager
    self.config = config
    self.name = name
    self.parent = parent

    -- Data
    self.pos = config.pos
    self.scale = config.scale
    self.alpha = config.alpha

    -- Animations
    -- Each element in this table has properties: "property", "from", "to", "duration", "time", and an optional property "sequence" (sequence to resume).
    self.activeAnimations = {}

    -- Children
    self.children = {}
    for childN, child in pairs(config.children) do
        local childConfig = child
        if type(childConfig) == "string" then
            -- Load from another file.
            childConfig = _Game.resourceManager:getUINodeConfig(childConfig)
        end
        self.children[childN] = UI2Node(manager, childConfig, childN, self)
    end

    -- Widget
    local w = config.widget
    if w then
        if w.type == "rectangle" then
            self.widget = UI2WidgetRectangle(self, w.align, w.size, w.color)
        end
    end
end



---Updates this Node and its children.
---@param dt number Time delta in seconds.
function UI2Node:update(dt)
    -- Update the animations.
    for i = #self.activeAnimations, 1, -1 do
        local animation = self.activeAnimations[i]
        animation.time = animation.time + dt
        local progress = math.min(animation.time / animation.duration, 1)
        local value = animation.from * (1 - progress) + animation.to * progress
        if animation.property == "alpha" then
            self.alpha = value
        elseif animation.property == "pos" then
            self.pos = value
        elseif animation.property == "posX" then
            self.pos.x = value
        elseif animation.property == "posY" then
            self.pos.y = value
        elseif animation.property == "scale" then
            self.scale = value
        elseif animation.property == "scaleX" then
            self.scale.x = value
        elseif animation.property == "scaleY" then
            self.scale.y = value
        end
        -- Kill the animation once it's finished.
        if progress == 1 then
            if animation.sequence then
                animation.sequence:releaseLock()
            end
            table.remove(self.activeAnimations, i)
        end
    end

    -- Update all children.
    for childN, child in pairs(self.children) do
        child:update(dt)
    end
end



---Plays an Animation on this Node.
---@param config UI2AnimationConfig The config of the animation to be applied.
---@param sequence UI2Sequence? The UI Sequence which has called this Animation.
---@param sequenceStep integer? The specific step of the UI Sequence which has called this Animation.
function UI2Node:playAnimation(config, sequence, sequenceStep)
    -- Prepend the current value if not specified.
    local from = config.from
    if not from then
        if config.property == "alpha" then
            from = self.alpha
        elseif config.property == "pos" then
            from = self.pos
        elseif config.property == "posX" then
            from = self.pos.x
        elseif config.property == "posY" then
            from = self.pos.y
        elseif config.property == "scale" then
            from = self.scale
        elseif config.property == "scaleX" then
            from = self.scale.x
        elseif config.property == "scaleY" then
            from = self.scale.y
        end
    end

    -- Insert to the active animation list.
    table.insert(self.activeAnimations, {
        property = config.property,
        from = from,
        to = config.to,
        duration = config.duration,
        time = 0,
        sequence = sequence,
        sequenceStep = sequenceStep
    })
end



---Returns the current effective position of this Node.
---@return Vector2
function UI2Node:getGlobalPos()
    if not self.parent then
        return self.pos
    end
    return self.parent:getGlobalPos() + self.pos
end



---Returns the current effective scale of this Node.
---@return Vector2
function UI2Node:getGlobalScale()
    if not self.parent then
        return self.scale
    end
    return self.parent:getGlobalScale() * self.scale
end



---Returns the current effective alpha value of this Node.
---@return number
function UI2Node:getGlobalAlpha()
    if not self.parent then
        return self.alpha
    end
    return self.parent:getGlobalAlpha() * self.alpha
end



---Returns a child of this Node with a given name if it exists.
---@return UI2Node?
function UI2Node:getChild(name)
    return self.children[name]
end



---Draws this Node and its children.
function UI2Node:draw()
    if self.widget then
        self.widget:draw()
    end
    for childN, child in pairs(self.children) do
        child:draw()
    end
end



---Debug function. Prints this Widget's tree.
---@param depth number? Used in recursion.
function UI2Node:printTree(depth)
    depth = depth or 0
    local s = ""
    for i = 1, depth do
        s = s .. "    "
    end
    s = s .. self.name
    print(s)
    for childN, child in pairs(self.children) do
        child:printTree(depth + 1)
    end
end



return UI2Node