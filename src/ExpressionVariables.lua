local class = require "com.class"

---A storage class which is holding variables for Expressions.
---@class ExpressionVariables
---@overload fun():ExpressionVariables
local ExpressionVariables = class:derive("ExpressionVariables")

local SphereSelectorResult = require("src.Game.SphereSelectorResult")

---Constructor.
function ExpressionVariables:new()
    self.VARIABLE_PROVIDER_PATH = "config/variable_providers.json"

	self.data = {pi = math.pi}
    self.variableProviderCache = {}
    self.variableProviderCacheIndices = {} -- Used for tracking `nil` values.
end

---Sets a variable to be used by Expressions.
---@param name string The variable name.
---@param value any The value to be stored.
function ExpressionVariables:set(name, value)
    self.data[name] = value
end

---Unsets a variable and/or a context with the given name.
---@param name string The variable/context name.
function ExpressionVariables:unset(name)
    for key, value in pairs(self.data) do
        if key == name or _Utils.strStartsWith(key, name .. ".") then
            self.data[key] = nil
        end
    end
end

---Obtains a variable value.
---@param name string The variable name.
---@param default any? A value to be returned if this variable doesn't exist. If not specified, this function will raise an error in that case instead.
---@return any
function ExpressionVariables:get(name, default)
    if self.data[name] ~= nil then
        return self.data[name]
    end
    if self.variableProviderCacheIndices[name] then
        return self.variableProviderCache[name]
    end
    local providers = nil
    if _Game.resourceManager:isResourceLoaded(self.VARIABLE_PROVIDER_PATH) then
        providers = _Game.resourceManager:getVariableProvidersConfig(self.VARIABLE_PROVIDER_PATH).providers
    end
    if providers and providers[name] then
        local value = self:evaluateVariableProvider(providers[name])
        if providers[name].framePersistence then
            self.variableProviderCache[name] = value
            self.variableProviderCacheIndices[name] = true
        end
        if value ~= nil then
            return value
        end
    end
    assert(default ~= nil, "Tried to get a nonexistent variable: " .. name)
    return default
end

---Evaluates a Variable Provider.
---@param provider table A Variable Provider.
---@return any?
function ExpressionVariables:evaluateVariableProvider(provider)
    if provider.type == "value" then
        return provider.value
    elseif provider.type == "countSpheres" then
        assert(_Game.level, "Variable Provider error: Used `countSpheres` when no level is active!")
        local selection = SphereSelectorResult(provider.sphereSelector)
        return selection:countSpheres()
    elseif provider.type == "mostFrequentColor" then
        assert(_Game.level, "Variable Provider error: Used `mostFrequentColor` when no level is active!")
        local selection = SphereSelectorResult(provider.sphereSelector)
        local colors = selection:countColors()
        local maxAmount = 0
        local maxColors = {}
        for i, v in pairs(colors) do
            if v > maxAmount then
                -- New leader found! Reset the list.
                maxAmount = v
                maxColors = {i}
            elseif v == maxAmount then
                -- A tie! Add the color to the list.
                table.insert(maxColors, i)
            end
        end
        -- Failsafe if there's absolutely NOTHING on the board.
        if #maxColors == 0 then
            return provider.fallback:evaluate()
        end
        return maxColors[math.random(#maxColors)]
    elseif provider.type == "randomSpawnableColor" then
        assert(_Game.level, "Variable Provider error: Used `randomSpawnableColor` when no level is active!")
        local colors = _Game.level:getSpawnableColors()
        if provider.excludedColors then
            colors = _Utils.tableSubtract(colors, provider.excludedColors)
        end
        assert(#colors > 0, "Variable Provider error: You've excluded all colors in `randomSpawnableColor`!")
        return colors[math.random(#colors)]
    elseif provider.type == "redirectSphere" then
        assert(_Game.level, "Variable Provider error: Used `redirectSphere` when no level is active!")
        local sphere = provider.sphere:evaluate()
        local selection = SphereSelectorResult(provider.sphereSelector)
        if not selection:hasSphere(sphere) then
            -- The sphere can be redirected to the front or to the back. Both searches stop when either something that matches the requirements is found (valid result) or not (invalid result).
            local spherePrev = sphere
            local sphereNext = sphere
            while spherePrev and not selection:hasSphere(spherePrev) do
                spherePrev = spherePrev:getPrevSphereInChain()
            end
            while sphereNext and not selection:hasSphere(sphereNext) do
                sphereNext = sphereNext:getNextSphereInChain()
            end
            if spherePrev and sphereNext then
                -- We found both. Choose randomly.
                sphere = math.random() < 0.5 and spherePrev or sphereNext
            elseif spherePrev then
                sphere = spherePrev
            elseif sphereNext then
                sphere = sphereNext
            else
                -- We found nothing...?
                error("Variable Provider error: `redirectSphere` found nothing! I'm crashing out! (also if you only need a color, try `redirectSphereColor`!)")
            end
        end
        return sphere
    elseif provider.type == "redirectSphereColor" then
        assert(_Game.level, "Variable Provider error: Used `redirectSphereColor` when no level is active!")
        -- TODO: Don't copy code and extract the common denominator instead.
        local sphere = provider.sphere:evaluate()
        local selection = SphereSelectorResult(provider.sphereSelector)
        if not selection:hasSphere(sphere) then
            -- The sphere can be redirected to the front or to the back. Both searches stop when either something that matches the requirements is found (valid result) or not (invalid result).
            local spherePrev = sphere
            local sphereNext = sphere
            while spherePrev and not selection:hasSphere(sphere) do
                spherePrev = spherePrev:getPrevSphereInChain()
            end
            while sphereNext and not selection:hasSphere(sphere) do
                sphereNext = sphereNext:getNextSphereInChain()
            end
            if spherePrev and sphereNext then
                -- We found both. Choose randomly.
                sphere = math.random() < 0.5 and spherePrev or sphereNext
            elseif spherePrev then
                sphere = spherePrev
            elseif sphereNext then
                sphere = sphereNext
            else
                -- We found nothing!
                return provider.fallback:evaluate()
            end
        end
        return sphere.color
    end
end

---Clears the Variable Provider cache. This should be executed at the beginning (or end) of each frame.
function ExpressionVariables:clearVariableProviderCache()
    _Utils.emptyTable(self.variableProviderCache)
    _Utils.emptyTable(self.variableProviderCacheIndices)
end

---A debug function which returns a list of all the variables that are currently available for Expressions.
---@param prefix string? Internal; for recursion.
---@param data table? Internal; for recursion.
---@return string
function ExpressionVariables:getDebugText(prefix, data)
    --[[
    data = data or self.data

    local s = ""
    local keys = {}
    for key, value in pairs(data) do
        table.insert(keys, key)
    end
    table.sort(keys)

    for i, key in ipairs(keys) do
        local keyName = key
        if prefix then
            keyName = prefix .. "." .. key
        end
        print(keyName)
        local value = data[key]
        if type(value) == "table" then
            s = s .. string.format("%s:\n", keyName)
            s = s .. _Utils.strIndent(self:getDebugText(keyName, value), 4)
        else
            s = s .. string.format("%s = %s\n", keyName, value)
        end
    end
    return s
    ]]
    return "Variable debug unavailable for now!"
end

return ExpressionVariables
