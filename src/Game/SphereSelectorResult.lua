local class = require "com.class"
local Vec2 = require("src.Essentials.Vector2")

---Represents the result of executing a Sphere Selector.
---
---Sphere Selector Results are used to contain a list of Spheres which conform to the conditions
---specified by the provided Sphere Selector Config.
---
---You should utilize and dispose it on the same frame it is created, as its contents do NOT update
---between frames.
---@class SphereSelectorResult
---@overload fun(config, pos):SphereSelectorResult
local SphereSelectorResult = class:derive("SphereSelectorResult")

---Constructs a new SphereSelectorResult.
---@param config SphereSelectorConfig The Sphere Selector configuration that will be used to generate a result of this selector.
---@param pos Vector2? A position to check the spheres' positions against. Note that the position-related variables will not be available if this argument is not provided.
function SphereSelectorResult:new(config, pos)
	self.config = config
	self.pos = pos

	self.spheres = {}
	-- TODO: Trigger evaluation for all spheres only when necessary. The `:hasSphere()` function does not need full information.
	for i, operation in ipairs(config.operations) do
		if operation.type == "add" then
			for j, path in ipairs(_Game.level.map.paths) do
				for k = #path.sphereChains, 1, -1 do
					local sphereChain = path.sphereChains[k]
					for l = #sphereChain.sphereGroups, 1, -1 do
						local sphereGroup = sphereChain.sphereGroups[l]
						for m = #sphereGroup.spheres, 1, -1 do
							local sphere = sphereGroup.spheres[m]
							sphere:dumpVariables("sphere", self.pos)
							if sphere.color ~= 0 and operation.condition:evaluate() then
								table.insert(self.spheres, sphere)
							end
							_Vars:unset("sphere")
						end
					end
				end
			end
		elseif operation.type == "addOne" then
			local sphere = operation.sphere:evaluate()
			table.insert(self.spheres, sphere)
		elseif operation.type == "select" then
			local amount = #self.spheres * operation.percentage
			if operation.round == "down" then
				amount = math.floor(amount)
			elseif operation.round == "up" then
				amount = math.ceil(amount)
			elseif operation.round == "nearest" then
				amount = math.floor(amount + 0.5)
			end
			-- Remove spheres randomly until the required amount has been reached.
			while #self.spheres > amount do
				table.remove(self.spheres, math.random(#self.spheres))
			end
		end
	end
end

---Destroys all of the spheres contained in this Result.
---@param scoreEvent ScoreEventConfig? The Score Event that will be executed once on the whole batch.
---@param scoreEventPerSphere ScoreEventConfig? The Score Event that will be executed separately for each sphere.
---@param gameEvent GameEventConfig? The Game Event which will be executed once on the whole batch.
---@param gameEventPerSphere GameEventConfig? The Game Event which will be executed separately for each sphere.
---@param forceEventPosCalculation boolean? If set, even if this Sphere Selector Result has a position, the Score Event position will be calculated by averaging all the spheres' positions.
function SphereSelectorResult:destroy(scoreEvent, scoreEventPerSphere, gameEvent, gameEventPerSphere, forceEventPosCalculation)
	_Vars:set("selector.sphereCount", #self.spheres)
	if scoreEvent then
		local eventPos = self.pos
		if not eventPos or forceEventPosCalculation then
			local minPos, maxPos
			-- The event position will be calculated by taking the center of the smallest box surrounding all spheres.
			for i, sphere in ipairs(self.spheres) do
				local spherePos = sphere:getPos()
				minPos = minPos and minPos:min(spherePos) or spherePos
				maxPos = maxPos and maxPos:max(spherePos) or spherePos
			end
			eventPos = minPos and ((minPos + maxPos) / 2) or Vec2()
		end
		_Game.level:executeScoreEvent(scoreEvent, eventPos.x, eventPos.y)
	end
	if gameEvent then
		_Game:executeGameEvent(gameEvent)
	end
	for i, sphere in ipairs(self.spheres) do
		sphere:dumpVariables("sphere", self.pos)
		if scoreEventPerSphere then
			local pos = sphere:getPos()
			_Game.level:executeScoreEvent(scoreEventPerSphere, pos.x, pos.y)
		end
		if gameEventPerSphere then
			_Game:executeGameEvent(gameEventPerSphere)
		end
		_Vars:unset("sphere")
		sphere.sphereGroup:destroySphere(sphere.sphereGroup:getSphereID(sphere))
	end
	_Vars:unset("selector")
end

---Changes the color of all of the spheres contained in this Result to a given color.
---@param color integer The new color of affected spheres.
---@param particle ParticleEffectConfig? The particle effect to be used for each affected sphere.
function SphereSelectorResult:changeColor(color, particle)
	for i, sphere in ipairs(self.spheres) do
		sphere:changeColor(color, particle)
	end
end

---Applies a Sphere Effect to all of the spheres contained in this Result.
---@param effect string The path to the Sphere Effect to be applied.
function SphereSelectorResult:applyEffect(effect)
	for i, sphere in ipairs(self.spheres) do
		sphere:applyEffect(effect)
	end
end

---Returns the amount of spheres contained in this Result.
---@return integer
function SphereSelectorResult:countSpheres()
	return #self.spheres
end

---Returns a table, where keys are the sphere colors, and the values are the amounts of spheres of corresponding color contained in this Result.
---@return table
function SphereSelectorResult:countColors()
	local result = {}
	for i, sphere in ipairs(self.spheres) do
		local color = sphere.color
		if not result[color] then
			result[color] = 1
		else
			result[color] = result[color] + 1
		end
	end
	return result
end

---Returns whether the provided Sphere is contained in this Result.
---@param sphere Sphere The sphere to be searched for.
---@return boolean
function SphereSelectorResult:hasSphere(sphere)
	return _Utils.isValueInTable(self.spheres, sphere)
end

return SphereSelectorResult
