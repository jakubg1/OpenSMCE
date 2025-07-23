local class = require "com.class"

---@class Profiler
---@overload fun(name):Profiler
local Profiler = class:derive("Profiler")

local Vec2 = require("src.Essentials.Vector2")



function Profiler:new(name)
	self.COLORS = {
		{1, 0, 0},
		{1, 0.5, 0},
		{1, 1, 0},
		{0.5, 1, 0},
		{0, 1, 0},
		{0, 1, 0.5},
		{0, 1, 1},
		{0, 0.5, 1},
		{0, 0, 1},
		{0.5, 0, 1},
		{1, 0, 1},
		{1, 0, 0.5}
	}
	self.name = name
	self.x, self.y = 0, 0
	self.w, self.h = 300, 240
	self.minValue = 0
	self.maxValue = 1/15
	self.lagThreshold = 1/15
	self.bars = {
		{value = 1/60, label = "0.017 (1/60)", color = {0, 1, 0}},
		{value = 1/30, label = "0.033 (1/30)", color = {1, 1, 0}},
		{value = 1/20, label = "0.050 (1/20)", color = {1, 0.5, 0}},
		{value = 1/15, label = "0.067 (1/15)", color = {1, 0, 0}}
	}
	self.recordCount = 300
	self.showMinMaxAvg = true
	self.showPercentage = false
	self.percentageMode = false

	self.times = {}
	self.currentCheckpoints = {}
	self.currentTime = nil
	self.lagCount = 0
end

function Profiler:start()
	self.currentCheckpoints = {}
	self.currentTime = love.timer.getTime()
end

function Profiler:checkpoint(n)
	if not self.currentTime then
		return
	end
	local t = love.timer.getTime()
	local td = t - self.currentTime
	if n and self.currentCheckpoints[n] then
		self.currentCheckpoints[n] = self.currentCheckpoints[n] + td
	else
		table.insert(self.currentCheckpoints, td)
	end
	self.currentTime = t
end

function Profiler:stop()
	if not self.currentTime then
		return
	end
	self:checkpoint()
	-- Sum all checkpoints' times.
	local ttot = 0
	for i, t in ipairs(self.currentCheckpoints) do
		ttot = ttot + t
	end
	-- If total frame time exceeds 1/15th of a second, increment the lag frame counter.
	if ttot > self.lagThreshold then
		self.lagCount = self.lagCount + 1
	end
	-- Remove oldest entries.
	if #self.times == self.recordCount then
		table.remove(self.times, 1)
	end
	-- Add a new list of checkpoints.
	table.insert(self.times, self.currentCheckpoints)
	-- Reset checkpoints.
	self.currentCheckpoints = {}
	self.currentTime = nil
end

function Profiler:putValue(value)
	-- Remove oldest entries.
	if #self.times == self.recordCount then
		table.remove(self.times, 1)
	end
	-- Add a new value.
	table.insert(self.times, {value})
end

function Profiler:getYForValue(value)
	local p = _Utils.mapc(0, 1, self.minValue, self.maxValue, value)
	return self.y - (self.h - 40) * p
end

function Profiler:getColor(n)
	return self.COLORS[(n - 1) % #self.COLORS + 1]
end

function Profiler:draw()
	-- Counting
	local total = 0
	local max = nil
	local min = nil

	-- Background
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.rectangle("fill", self.x, self.y - self.h, self.w, self.h)

	-- Graph
	local recordWidth = self.w / self.recordCount
	for i, tc in ipairs(self.times) do
		local ttot = 0
		if self.percentageMode then
			for j, t in ipairs(tc) do
				ttot = ttot + t
			end

			local htot = 0
			for j, t in ipairs(tc) do
				local h = t / ttot * self.h - 40
				htot = htot + h
				love.graphics.setColor(self:getColor(j))
				love.graphics.rectangle("fill", self.x + (i - 1) * recordWidth, self.y - htot, recordWidth, h)
			end
		else
			for j, t in ipairs(tc) do
				local y1 = self:getYForValue(ttot)
				ttot = ttot + t
				local y2 = self:getYForValue(ttot)
				love.graphics.setColor(self:getColor(j))
				love.graphics.rectangle("fill", self.x + (i - 1) * recordWidth, y1, recordWidth, y2 - y1)
			end
		end

		total = total + ttot
		max = math.max(max or ttot, ttot)
		min = math.min(min or ttot, ttot)
	end

	-- Text
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(string.format("%s [%s]", self.name, self.lagCount), self.x, self.y - self.h + 8)
	if self.showMinMaxAvg then
		if #self.times > 0 then
			love.graphics.print(string.format("average: %.0f ms", total / #self.times * 1000), self.x, self.y - self.h + 24)
		end
		if min then
			love.graphics.print(string.format("min: %.0f ms", min * 1000), self.x + 100, self.y - self.h + 24)
		end
		if max then
			love.graphics.print(string.format("max: %.0f ms", max * 1000), self.x + 200, self.y - self.h + 24)
		end
	end

	-- Lines
	if not self.percentageMode then
		love.graphics.setLineWidth(1)
		for i, bar in ipairs(self.bars) do
			local y = self:getYForValue(bar.value)
			love.graphics.setColor(bar.color)
			love.graphics.line(self.x, y, self.x + self.w, y)
			love.graphics.print(bar.label, self.x, y - 16)
		end
	end

	-- Percentage
	if self.showPercentage and #self.times > 0 then
		local tc = self.times[#self.times]
		local ttot = 0
		for i, t in ipairs(tc) do
			ttot = ttot + t
		end

		local htot = 0
		for i, t in ipairs(tc) do
			local h = t / ttot * 200
			htot = htot + h
			love.graphics.setColor(self:getColor(i))
			love.graphics.rectangle("fill", self.x, self.y - htot, 10, h)
		end
	end
end

return Profiler
