local class = require "com.class"

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

local Vec2 = require("src.Essentials.Vector2")



---Constructs a new SphereSelectorResult.
---@param config SphereSelectorConfig The Sphere Selector configuration that will be used to generate a result of this selector.
---@param pos Vector2? A position to check the spheres' positions against. Note that the position-related variables will not be available if this argument is not provided.
function SphereSelectorResult:new(config, pos)
	self.config = config
	self.pos = pos

	self.spheres = {}
	for i, operation in ipairs(config.operations) do
		if operation.type == "add" then
			for j, path in ipairs(_Game.session.level.map.paths) do
				for k = #path.sphereChains, 1, -1 do
					local sphereChain = path.sphereChains[k]
					for l = #sphereChain.sphereGroups, 1, -1 do
						local sphereGroup = sphereChain.sphereGroups[l]
						for m = #sphereGroup.spheres, 1, -1 do
							local sphere = sphereGroup.spheres[m]
							local spherePos = sphereGroup:getSpherePos(m)
							if pos then
								_Vars:setC("sphere", "distance", (spherePos - pos):len())
								_Vars:setC("sphere", "distanceX", math.abs(spherePos.x - pos.x))
							end
							_Vars:setC("sphere", "object", sphere)
							_Vars:setC("sphere", "color", sphere.color)
							_Vars:setC("sphere", "isOffscreen", sphere:isOffscreen())
							if sphere.color ~= 0 and operation.condition:evaluate() then
								table.insert(self.spheres, {sphere = sphere, sphereGroup = sphereGroup, sphereIndex = m})
							end
							_Vars:unset("sphere")
						end
					end
				end
			end
		end
	end
end



---Destroys all of the spheres contained in this Result.
---@param scoreEvent ScoreEventConfig? The score event to be executed for all spheres together.
---@param scoreEventPerSphere ScoreEventConfig? The score event to be executed for each sphere separately.
---@param forceEventPosCalculation boolean? If set, even if this Sphere Selector Result has a position, the Score Event position will be calculated by averaging all the spheres' positions.
function SphereSelectorResult:destroy(scoreEvent, scoreEventPerSphere, forceEventPosCalculation)
	if scoreEvent then
		local eventPos = self.pos
		if not eventPos or forceEventPosCalculation then
			local minPos, maxPos
			-- The event position will be calculated by taking the center of the smallest box surrounding all spheres.
			for i, sphere in ipairs(self.spheres) do
				local spherePos = sphere.sphere:getPos()
				minPos = minPos and minPos:min(spherePos) or spherePos
				maxPos = maxPos and maxPos:max(spherePos) or spherePos
			end
			eventPos = minPos and ((minPos + maxPos) / 2) or Vec2()
		end
		_Vars:setC("selector", "sphereCount", #self.spheres)
		_Game.session.level:executeScoreEvent(scoreEvent, eventPos)
		_Vars:unset("selector")
	end
	for i, sphere in ipairs(self.spheres) do
		if scoreEventPerSphere then
			_Vars:setC("sphere", "color", sphere.sphere.color)
			_Game.session.level:executeScoreEvent(scoreEventPerSphere, sphere.sphere:getPos())
			_Vars:unset("sphere")
		end
		sphere.sphereGroup:destroySphere(sphere.sphereIndex)
	end
end



---Changes the color of all of the spheres contained in this Result to a given color.
---@param color integer The new color of affected spheres.
---@param particle table? The particle effect to be used for each affected sphere.
function SphereSelectorResult:changeColor(color, particle)
	for i, sphere in ipairs(self.spheres) do
		sphere.sphere:changeColor(color, particle)
	end
end



return SphereSelectorResult
