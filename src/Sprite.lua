local class = require "com/class"
local Sprite = class:derive("Sprite")

local SpriteImage = require("src/SpriteImage")

function Sprite:new(path, variables)
	local data = game.resourceBank:getLegacySprite(path)
	
	self.subsprites = {}
	for i, subsprite in ipairs(data) do
		if subsprite.type == "image" then
			self.subsprites[i] = SpriteImage(subsprite, variables)
		elseif subsprite.type == "sprite" then
			self.subsprites[i] = Sprite(parseString(subsprite.path, variables), variables)
		else
			print("WARNING: In sprite " .. path .. ": unknown subsprite type " .. subsprite.type)
		end
	end
	
	self.time = 0
end

function Sprite:update(dt)
	self.time = self.time + dt
	for i, subsprite in ipairs(self.subsprites) do
		subsprite:update(dt)
	end
end

function Sprite:draw(pos, variables)
	for i, subsprite in ipairs(self.subsprites) do
		subsprite:draw(pos, variables)
	end
end

return Sprite