-- Copyright 2018-2021 zorg
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with
-- or without fee is hereby granted, provided that the above copyright notice and this
-- permission notice appear in all copies.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD
-- TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS.
-- IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
-- CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA
-- OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
-- ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.



-- Advanced Source Library
-- Processing Thread
-- by zorg § ISC @ 2018-2023



--[[
Internal Variables
- ProcThread Class:
	- instances -> Table needed to keep track of all active sources.
		- Keys should be gapless integers so we can quickly iterate over them
		- Times the table is modified:
			- Add new element -> goes to end, that's fine
			- Del one element -> can be any element, shifting table or better yet, replacing with
			  the last should be fine; this shouldn't change id-s though.
		- Times the table is accessed:
			- Thread update loop    -> goes over all elements, should be fast.
			- Instance method calls -> goes by id number, should be relatively fast.
			- love.audio.pause      -> requests id-s that were stopped by this event.
		Verdict: An int-keyed gapless table w/ an inverse lookup table seems like the best choice.

- ProcThread Instances:
	See the constructor function definition.
	The methods may throw 4 kinds of errors resulting from:
	- nil checks,
	- type checks,
	- range checks,
	- enumeration checks.
--]]



-- Needed löve modules in this thread.
require('love.thread')
require('love.sound')
require('love.audio')
require('love.timer')
require('love.math')



-- The thread itself, needed so we can have one unique processing thread.
local procThread

-- Shared inbound communication channel to this thread.
local toProc = ...

-- List of ASource objects; keys are contiguous integers, however, they aren't unique indices.
-- We also define a reverse-lookup table: keys are the unique indices, vals are the above keys.
local ASourceList = {} -- number:table
local ASourceIMap = {} -- number:number



-- Enumerations (Not stored in instances, no need for reverse lookup tables.)
local PitchUnit     = {['ratio']        = true, ['semitones'] = true}
local TimeUnit      = {['seconds']      = true, ['samples']   = true}
local BufferUnit    = {['milliseconds'] = true, ['samples']   = true} -- Also used for Frame size.
local VarianceUnit  = {['milliseconds'] = true, ['samples']   = true, ['percentage'] = true}



-- Monkeypatching into the math library (of this thread only).
local math = math
math.sgn   = function(x) return x<0.0 and -1.0 or 1.0 end
math.clamp = function(x,min,max) return math.max(math.min(x, max), min) end
local invSqrtTwo = 1.0 / math.sqrt(2.0)
local halfpi     = math.pi / 2.0

-- Default panning laws and reverse-lookup table.
local PanLawFunc = {
	[0] = function(pan) return                    1.0  - pan,                           pan end,
	[1] = function(pan) return math.cos(math.pi / 2.0 * pan), math.sin(math.pi / 2.0 * pan) end
	-- [2] is locally stored as functions in each instance separately.
}
local PanLawList = {[0] = 'gain', 'power'}
local PanLawIMap = {}; for i=0,#PanLawList do PanLawIMap[PanLawList[i]] = i end

-- Interpolation method list and reverse-lookup table.
local ItplMethodList  = {[0] = 'nearest', 'linear', 'cubic', 'sinc'}
local ItplMethodIMap = {}; for i=0,#ItplMethodList do ItplMethodIMap[ItplMethodList[i]] = i end

-- Sinc function needed for the related interpolation functionality.
local function lanczos_window(x,a)
	if x == 0 then
		return 1 -- division by zero protection.
	elseif x >= -a and x < a then
		return (a * math.sin(math.pi * x) * math.sin(math.pi * x / a)) / (math.pi ^ 2 * x ^ 2)
	else
		return 0 -- brickwall edges outside the region we're using.
	end
end

-- TSM buffer mixing method list and reverse-lookup table.
-- Technically these are also interpolation methods, but 2 input ones only, and an automatic mode.
local MixMethodList = {[0] = 'auto', 'linear', 'sqroot', 'cosine'}
local MixMethodIMap = {}; for i=0,#MixMethodList do MixMethodIMap[MixMethodList[i]] = i end

-- Buffer variance distribution method list and reverse-lookup table.
local VarDistType = {[0] = 'uniform', 'normal'}
local VarDistIMap = {}; for i=0,#VarDistType do VarDistIMap[VarDistType[i]] = i end



----------------------------------------------------------------------------------------------------

-- Helper functions that need to be called to recalculate multiple internals from varied methods.

-- Makes pitch shifting and time stretching possible.
local function calculateTSMCoefficients(instance)
	-- Set offsets
	instance.innerOffset = instance.resampleRatio 
	                     * instance.pitchShift    * math.sgn(instance.timeStretch)
	instance.outerOffset = instance.resampleRatio *
	                     ( instance.timeStretch   * math.sgn(instance.resampleRatio)
	                     - instance.pitchShift    * math.sgn(instance.timeStretch))
	-- Me avoiding responsibilities :c
	instance.frameAdvance = instance.timeStretch  * math.abs(instance.resampleRatio)
end

-- Pre-calculates how stereo sources should have their panning set.
local function calculatePanningCoefficients(instance)
	instance.panL, instance.panR = instance.panLawFunc(instance.panning)
end

-- Pre-calculates values needed for uniformly random buffer resizing.
local function calculateFrameCoefficients(instance)
	local lLimit = math.floor( 1 * 0.001 * instance.samplingRate + 0.5) --  1 ms
	local uLimit = math.floor(10         * instance.samplingRate + 0.5) -- 10 s
	instance.minFrameSize = math.max(lLimit, instance.frameSize - instance.frameVariance)
	instance.maxFrameSize = math.min(uLimit, instance.frameSize + instance.frameVariance)
end



----------------------------------------------------------------------------------------------------

-- TODO: Placeholder until we implement the full push-style version with all processing included.
local Queue = function(instance, ...)
	instance.source:queue(...)
	-- No play call here; vanilla QSources didn't automatically play either.
	return true
end



----------------------------------------------------------------------------------------------------

-- Defining processing functions that fill the internal buffer with generated samplepoints.

local Process = {}



Process.static = function(instance)
	-- Localize length of the input SoundData for less table accesses and function calls.
	-- This is only used for wrapping in the sampling functions (getSample).
	local N = instance.data:getSampleCount()

	-- Copy samplepoints to buffer.
	for b = 0, instance.bufferSize - 1 do

		-- The current frame offset.
		local frameOffset    = instance.playbackOffset
		-- Calculate the offset of the frame we want to mix with the current one.
		local mixFrameOffset = instance.curFrameSize * instance.outerOffset
		-- The above two don't need to be wrapped due to them only being used in one location only.

		-- TSM frames aren't aligned to the buffer's size, so we keep track of that separately.
		local i = instance._frameIndex

		-- Normalized linear weight applied to the two samplepoints we're mixing each time.
		local mix = i / (instance.curFrameSize - 1)
		-- Fix potential NaN issue if curFrameSize is 1.
		mix = mix == mix and mix or 0

		-- Current fractional samplepoint offset into the input SoundData.
		local smpOffset    = frameOffset --+ i * instance.innerOffset
		-- Calculate the offset of the samplepoint we want to mix with the current one.
		local mixSmpOffset = smpOffset --+ mixFrameOffset
		-- The above two also don't need to be wrapped.

		-- If we left the SoundData's region, and looping is off...
		if not instance.looping then

			smpOffset    = frameOffset + i * instance.innerOffset
			mixSmpOffset = smpOffset + mixFrameOffset

			if smpOffset < 0 or smpOffset >= N then

				-- Fill the rest of the buffer with silence,
				for j = b, instance.bufferSize - 1 do
					for ch=1, instance.channelCount do
						instance.buffer:setSample(j, ch, 0.0)
					end
				end

				-- Stop the instance.
				instance:stop()

				-- Reset TSM frame index
				instance._frameIndex = 0

				-- Break out early of the for loop.
				break
			end

		else--if instance.looping then

			local disjunct = instance.loopRegionB < instance.loopRegionA

			-- Initial playback or seeking was performed.
			if not instance.loopRegionEntered then

				-- Check if we're inside any loop regions now, if so, set the above parameter.
				if not disjunct then
					if smpOffset >= instance.loopRegionA and smpOffset <= instance.loopRegionB then
						instance.loopRegionEntered = true
					end

				else--if disjunct then
					--if smpOffset <= instance.loopRegionB or smpOffset >= instance.loopRegionA then
					if (smpOffset >=   0 and smpOffset <= instance.loopRegionB) or
					   (smpOffset <= N-1 and smpOffset >= instance.loopRegionA) then
						instance.loopRegionEntered = true
					end
				end
			end

			-- If we're in the loop, make sure we don't leave it with neither of the two pointers.
			if instance.loopRegionEntered then

				-- Adjust both offsets to adhere to loop region bounds as well as SoundData length.
				local loopRegionSize
				if not disjunct then

					-- One contiguous region between A and B.
					-- Minimal region size is 1 samplepoints.
					loopRegionSize = instance.loopRegionB - instance.loopRegionA + 1

				else--if disjunct then

					-- Two separate regions between 0 and B, and A and N-1 respectively.
					-- Minimal region size is 2 samplepoints. (if it was 1, it would be conjunct...)
					loopRegionSize = (1 + instance.loopRegionB) + (N - instance.loopRegionA)

				end

				-- One algorithm to rule them all
				-- ...mathed out by Vörnicus, thank you once again~
				
				smpOffset    = (((smpOffset - instance.loopRegionA) % N
				             + i            * instance.innerOffset) % loopRegionSize
				             +                instance.loopRegionA) % N

				mixSmpOffset = (((smpOffset - instance.loopRegionA) % N 
				             +                      mixFrameOffset) % loopRegionSize
				             +                instance.loopRegionA) % N

			else

				smpOffset    = frameOffset + i * instance.innerOffset
				mixSmpOffset = smpOffset + mixFrameOffset

			end
		end

		-- Currently, outerOffset can't change inside this function, so we hoist automatic TSM
		-- buffer mixing method selection out of the inner loops to here.
		local mixMethod = instance.mixMethodIdx
		-- Automatic mode: if outerOffset is effectively 0.0, use linear, otherwise use cosine.
		-- Note: Linear mode is inadequate, we still need to adjust the volume to be lower.
		if mixMethod == 0 then
			-- Epsilon chosen so that for most sensible values of the TSM parameters, zero will
			-- result in the right combinations, meaning we're just doing resampling.
			-- 2^-32 is good enough for more than 8 decimal digits of precision.
			if math.abs(instance.outerOffset) < 2^-32 then
				mixMethod = 0
			else
				mixMethod = 3
			end
		end

		-- Unroll loops based on input channel count.
		if instance.channelCount == 1 then
			local A, B = 0.0, 0.0

			-- Using interpolation, calculate the two samplepoints for each input channel.
			local itplMethodIdx = instance.itplMethodIdx
			if     itplMethodIdx == 0 then
				-- 0th order hold / nearest-neighbour
				A = instance.data:getSample(math.floor(smpOffset    + 0.5) % N)

				B = instance.data:getSample(math.floor(mixSmpOffset + 0.5) % N)

			elseif itplMethodIdx == 1 then
				-- 1st order / linear
				local int,frac

				int  = math.floor(smpOffset)
				frac = smpOffset - int
				A = instance.data:getSample( int      % N) * (1.0 - frac) +
				    instance.data:getSample((int + 1) % N) *        frac

				int  = math.floor(mixSmpOffset)
				frac = mixSmpOffset - int
				B = instance.data:getSample( int      % N) * (1.0 - frac) +
				    instance.data:getSample((int + 1) % N) *        frac

			elseif itplMethodIdx == 2 then
				-- 3rd order / cubic hermite spline
				local int, frac

				-- https://blog.demofox.org/2015/08/08/cubic-hermite-interpolation/ but simplified.
				local x, y, z, w
				local X, Y, Z, W

				int  = math.floor(smpOffset)
				frac = smpOffset - int
				x = instance.data:getSample(math.floor(smpOffset - 1) % N)
				y = instance.data:getSample(math.floor(smpOffset    ) % N)
				z = instance.data:getSample(math.floor(smpOffset + 1) % N)
				w = instance.data:getSample(math.floor(smpOffset + 2) % N)
				X = -(x * 0.5) + (y * 1.5) - (z * 1.5) + w * 0.5
				Y =  (x      ) - (y * 2.5) + (z * 2.0) - w * 0.5
				Z = -(x * 0.5)             + (z * 0.5)
				W =               y
				A = X * frac^3 + Y * frac^2 + Z * frac + W

				int  = math.floor(mixSmpOffset)
				frac = mixSmpOffset - int
				x = instance.data:getSample(math.floor(mixSmpOffset - 1) % N)
				y = instance.data:getSample(math.floor(mixSmpOffset    ) % N)
				z = instance.data:getSample(math.floor(mixSmpOffset + 1) % N)
				w = instance.data:getSample(math.floor(mixSmpOffset + 2) % N)
				X = -(x * 0.5) + (y * 1.5) - (z * 1.5) + w * 0.5
				Y =  (x      ) - (y * 2.5) + (z * 2.0) - w * 0.5
				Z = -(x * 0.5)             + (z * 0.5)
				W =               y
				B = X * frac^3 + Y * frac^2 + Z * frac + W

			else--if itplMethodIdx == 3 then
				-- 16-tap / sinc (lanczos)
				local taps  = 16
				local offset, result
				
				result = 0.0
				offset = smpOffset % N
				for t = -taps+1, taps do
					local i = math.floor(smpOffset + t) % N
					result = result + instance.data:getSample(i) *
					         lanczos_window(offset - i, taps)
				end
				A = result

				result = 0.0
				offset = mixSmpOffset % N
				for t = -taps+1, taps do
					local i = math.floor(mixSmpOffset + t) % N
					result = result + instance.data:getSample(i) *
					         lanczos_window(offset - i, taps)
				end
				B = result
			end

			-- Apply attenuation to result in a linear or cosine mix through the buffer.
			if mixMethod == 0 then
				A = A * (1.0 - mix)
				B = B *        mix
				A = A * invSqrtTwo
				B = B * invSqrtTwo
			elseif mixMethod == 1 then
				A = A * (1.0 - mix)
				B = B *        mix
			elseif mixMethod == 2 then
				A = A * math.sqrt(1.0 - mix)
				B = B * math.sqrt(      mix)
				A = A * invSqrtTwo
				B = B * invSqrtTwo
			else--if mixMethod == 3 then
				A = A * math.cos(       mix  * halfpi)
				B = B * math.cos((1.0 - mix) * halfpi)
				A = A * invSqrtTwo
				B = B * invSqrtTwo
			end

			if instance.outputAurality == 1 then

				-- Mix the values by simple summing.
				local O = A+B

				-- Set the samplepoint value(s) with clamping for safety.
				instance.buffer:setSample(b, math.clamp(O, -1.0, 1.0))

			else--if instance.outputAurality == 2 then

				-- Mix the values by simple summing.
				local L, R = A+B, A+B

				-- Apply stereo separation.
				local M = (L + R) * 0.5
				local S = (L - R) * 0.5
				-- New range in [0.0,2.0] which is perfect for the implementation here.
				local separation = instance.separation + 1.0

				L = M * (2.0 - separation) + S * separation
				R = M * (2.0 - separation) - S * separation

				-- Apply panning.
				L = L * instance.panL
				R = R * instance.panR

				-- Set the samplepoint value(s) with clamping for safety.
				instance.buffer:setSample(b, 1, math.clamp(L, -1.0, 1.0))
				instance.buffer:setSample(b, 2, math.clamp(R, -1.0, 1.0))

			end

		else--if instance.channelCount == 2 then
			local AL, BL = 0.0, 0.0
			local AR, BR = 0.0, 0.0

			-- Using interpolation, calculate the two samplepoints for each input channel.
			local itplMethodIdx = instance.itplMethodIdx
			if     itplMethodIdx == 0 then
				-- 0th order hold / nearest-neighbour
				AL = instance.data:getSample(math.floor(smpOffset    + 0.5) % N, 1)
				AR = instance.data:getSample(math.floor(smpOffset    + 0.5) % N, 2)

				BL = instance.data:getSample(math.floor(mixSmpOffset + 0.5) % N, 1)
				BR = instance.data:getSample(math.floor(mixSmpOffset + 0.5) % N, 2)

			elseif itplMethodIdx == 1 then
				-- 1st order / linear
				local int,frac

				int  = math.floor(smpOffset)
				frac = smpOffset - int
				AL = instance.data:getSample( int      % N, 1) * (1.0 - frac) +
				     instance.data:getSample((int + 1) % N, 1) *        frac
				AR = instance.data:getSample( int      % N, 2) * (1.0 - frac) +
				     instance.data:getSample((int + 1) % N, 2) *        frac

				int  = math.floor(mixSmpOffset)
				frac = mixSmpOffset - int
				BL = instance.data:getSample( int      % N, 1) * (1.0 - frac) +
				     instance.data:getSample((int + 1) % N, 1) *        frac
				BR = instance.data:getSample( int      % N, 2) * (1.0 - frac) +
				     instance.data:getSample((int + 1) % N, 2) *        frac

			elseif itplMethodIdx == 2 then
				-- 3rd order / cubic hermite spline
				local int, frac

				-- https://blog.demofox.org/2015/08/08/cubic-hermite-interpolation/ but simplified.
				local x, y, z, w
				local X, Y, Z, W

				int  = math.floor(smpOffset)
				frac = smpOffset - int
				x = instance.data:getSample(math.floor(smpOffset - 1) % N, 1)
				y = instance.data:getSample(math.floor(smpOffset    ) % N, 1)
				z = instance.data:getSample(math.floor(smpOffset + 1) % N, 1)
				w = instance.data:getSample(math.floor(smpOffset + 2) % N, 1)
				X = -(x * 0.5) + (y * 1.5) - (z * 1.5) + w * 0.5
				Y =  (x      ) - (y * 2.5) + (z * 2.0) - w * 0.5
				Z = -(x * 0.5)             + (z * 0.5)
				W =               y
				AL = X * frac^3 + Y * frac^2 + Z * frac + W
				x = instance.data:getSample(math.floor(smpOffset - 1) % N, 2)
				y = instance.data:getSample(math.floor(smpOffset    ) % N, 2)
				z = instance.data:getSample(math.floor(smpOffset + 1) % N, 2)
				w = instance.data:getSample(math.floor(smpOffset + 2) % N, 2)
				X = -(x * 0.5) + (y * 1.5) - (z * 1.5) + w * 0.5
				Y =  (x      ) - (y * 2.5) + (z * 2.0) - w * 0.5
				Z = -(x * 0.5)             + (z * 0.5)
				W =               y
				AR = X * frac^3 + Y * frac^2 + Z * frac + W

				int  = math.floor(mixSmpOffset)
				frac = mixSmpOffset - int
				x = instance.data:getSample(math.floor(mixSmpOffset - 1) % N, 1)
				y = instance.data:getSample(math.floor(mixSmpOffset    ) % N, 1)
				z = instance.data:getSample(math.floor(mixSmpOffset + 1) % N, 1)
				w = instance.data:getSample(math.floor(mixSmpOffset + 2) % N, 1)
				X = -(x * 0.5) + (y * 1.5) - (z * 1.5) + w * 0.5
				Y =  (x      ) - (y * 2.5) + (z * 2.0) - w * 0.5
				Z = -(x * 0.5)             + (z * 0.5)
				W =               y
				BL = X * frac^3 + Y * frac^2 + Z * frac + W
				x = instance.data:getSample(math.floor(mixSmpOffset - 1) % N, 2)
				y = instance.data:getSample(math.floor(mixSmpOffset    ) % N, 2)
				z = instance.data:getSample(math.floor(mixSmpOffset + 1) % N, 2)
				w = instance.data:getSample(math.floor(mixSmpOffset + 2) % N, 2)
				X = -(x * 0.5) + (y * 1.5) - (z * 1.5) + w * 0.5
				Y =  (x      ) - (y * 2.5) + (z * 2.0) - w * 0.5
				Z = -(x * 0.5)             + (z * 0.5)
				W =               y
				BR = X * frac^3 + Y * frac^2 + Z * frac + W

			else--if itplMethodIdx == 3 then
				-- 16-tap / sinc (lanczos)
				local taps  = 16
				local offset, resultL, resultR
				
				resultL, resultR = 0.0, 0.0
				offset = smpOffset % N
				for t = -taps+1, taps do
					local i = math.floor(smpOffset + t) % N
					resultL = resultL + instance.data:getSample(i, 1) *
					          lanczos_window(offset - i, taps)
					resultR = resultR + instance.data:getSample(i, 2) *
					          lanczos_window(offset - i, taps)
				end
				AL, AR = resultL, resultR

				resultL, resultR = 0.0, 0.0
				offset = mixSmpOffset % N
				for t = -taps+1, taps do
					local i = math.floor(mixSmpOffset + t) % N
					resultL = resultL + instance.data:getSample(i, 1) *
					          lanczos_window(offset - i, taps)
					resultR = resultR + instance.data:getSample(i, 2) *
					          lanczos_window(offset - i, taps)
				end
				BL, BR = resultL, resultR
			end

			-- Apply attenuation to result in a linear or cosine mix through the buffer.
			if mixMethod == 0 then
				AL, AR = AL * (1.0 - mix), AR * (1.0 - mix)
				BL, BR = BL * (      mix), BR * (      mix)
				AL, AR = AL * invSqrtTwo, AR * invSqrtTwo
				BL, BR = BL * invSqrtTwo, BR * invSqrtTwo
			elseif mixMethod == 1 then
				AL, AR = AL * (1.0 - mix), AR * (1.0 - mix)
				BL, BR = BL * (      mix), BR * (      mix)
			elseif mixMethod == 2 then
				AL, AR = AL * math.sqrt(1.0 - mix), AR * math.sqrt(1.0 - mix)
				BL, BR = BL * math.sqrt(      mix), BR * math.sqrt(      mix)
				AL, AR = AL * invSqrtTwo, AR * invSqrtTwo
				BL, BR = BL * invSqrtTwo, BR * invSqrtTwo
			else--if mixMethod == 3 then
				AL, AR = AL * math.cos(       mix  * halfpi), AR * math.cos(       mix  * halfpi)
				BL, BR = BL * math.cos((1.0 - mix) * halfpi), BR * math.cos((1.0 - mix) * halfpi)
				AL, AR = AL * invSqrtTwo, AR * invSqrtTwo
				BL, BR = BL * invSqrtTwo, BR * invSqrtTwo
			end

			-- Mix the values by simple summing.
			local L, R = AL+BL, AR+BR

			-- Apply stereo separation.
			local M = (L + R) * 0.5
			local S = (L - R) * 0.5
			-- New range in [0.0,2.0] which is perfect for the implementation here.
			local separation = instance.separation + 1.0
			
			L = M * (2.0 - separation) + S * separation
			R = M * (2.0 - separation) - S * separation

			-- Apply panning.
			L = L * instance.panL
			R = R * instance.panR

			if instance.outputAurality == 1 then
				-- Downmix to mono.
				local O = (L+R) * 0.5
				-- Set the samplepoint value(s) with clamping for safety.
				instance.buffer:setSample(b, math.clamp(O, -1.0, 1.0))
			else--if instance.outputAurality == 2 then
				-- Set the samplepoint value(s) with clamping for safety.
				instance.buffer:setSample(b, 1, math.clamp(L, -1.0, 1.0))
				instance.buffer:setSample(b, 2, math.clamp(R, -1.0, 1.0))
			end
		end

		-- Increase TSM frame index.
		instance._frameIndex = instance._frameIndex + 1

		-- If we are at the last one, calculate next frame offsets.
		if instance._frameIndex > instance.curFrameSize - 1 then

			-- Reset index.
			instance._frameIndex = 0

			-- Calculate next frame offset.
			local nextPlaybackOffset = instance.playbackOffset + instance.curFrameSize
				                     * instance.frameAdvance

			-- Apply loop region bounding, if applicable.
			if instance.looping then

				local disjunct = instance.loopRegionB < instance.loopRegionA

				-- If we're in the loop, make sure we don't leave it with neither of the two pointers.
				if instance.loopRegionEntered then

					-- Adjust both offsets to adhere to loop region bounds as well as SoundData length.
					local loopRegionSize
					if not disjunct then
						-- One contiguous region between A and B.
						loopRegionSize = instance.loopRegionB - instance.loopRegionA + 1

					else--if disjunct then
						-- Two separate regions between 0 and B, and A and N-1 respectively.
						loopRegionSize = (1 + instance.loopRegionB) + (N - instance.loopRegionA)
					end

					-- One algorithm to rule them all
					-- ...mathed out by Vörnicus, thank you once again~

					nextPlaybackOffset = (
						((instance.playbackOffset - instance.loopRegionA) % N
						+ instance.curFrameSize   * instance.frameAdvance)
						% loopRegionSize          + instance.loopRegionA) % N
				end
			end

			-- Set instance's offset to what it should be, with wrapping by the input SoundData's size.
			instance.playbackOffset = nextPlaybackOffset % N

			-- If needed, recalculate TSM coefficients; needs to be done here to avoid mid-frame
			-- changes which would result in glitches.
			if instance._recalcTSMCoefficients then
				calculateTSMCoefficients(instance)
				instance._recalcTSMCoefficients = false
			end

			-- Randomize frame size.
			if instance.frameVarianceDistributionIdx == 0 then
				instance.curFrameSize = love.math.random(
					instance.minFrameSize,
					instance.maxFrameSize)
			else
				local avgFrameSize    = (instance.minFrameSize + instance.maxFrameSize) / 2.0
				local normal          = love.math.randomNormal(avgFrameSize / 2.0, avgFrameSize)
				instance.curFrameSize = math.floor(math.clamp(
					normal, instance.minFrameSize, instance.maxFrameSize))
			end
		end
	end

	-- Queue up the buffer we just calculated, and ensure it gets played even if the
	-- Source object has already underrun, and hence stopped.
	instance.source:queue(
		instance.buffer, instance.bufferSize * (instance.bitDepth/8) * instance.outputAurality)
	instance.source:play()
end



Process.stream = function()
	-- Not Yet Implemented.
end



Process.queue = function()
	-- Not Yet Implemented.
end



----------------------------------------------------------------------------------------------------

-- Class

local ASource = {}



----------------------------------------------------------------------------------------------------

-- Metatable

local mtASource = {__index = ASource}



----------------------------------------------------------------------------------------------------

-- Constructor (not part of the class)

local function new(a,b,c,d,e)
	-- Decode parameters.
	local sourcetype
	if type(a) == 'nil' then
		error("ASource constructor: Missing 1st parameter; it can be one of the following:\n" ..
			"string, File, FileData, Decoder, SoundData; use number for a queue-type instance.")

	elseif type(a) == 'number' then
		-- Queueable type.
		if type(b) ~= 'number' then
			error(("ASource constructor: 2nd parameter must be a number; " ..
				"got %s instead."):format(type(b)))
		end
		if type(c) ~= 'number' then
			error(("ASource constructor: 3rd parameter must be a number; " ..
				"got %s instead."):format(type(c)))
		end
		if type(d) ~= 'number' then
			error(("ASource constructor: 4th parameter must be a number; " ..
				"got %s instead."):format(type(d)))
		end
		if not ({[8] = true, [16] = true})[b] then
			error(("ASource constructor: 2nd parameter must be either 8 or 16; " ..
				"got %f instead."):format(b))
		end
		if not ({[1] = true, [2] = true})[c] then
			error(("ASource constructor: 3rd parameter must be either 1 or 2; " ..
				"got %f instead."):format(c))
		end
		sourcetype = 'queue'

	elseif 	           type(a) == 'string'      or
		   a.type and a:type() == 'File'        or
		   a.type and a:type() == 'DroppedFile' or
		   a.type and a:type() == 'FileData'    or
		   a.type and a:type() == 'Decoder'     then
		-- Static/stream types (excluding static ones from a SoundData object).
		if type(b) ~= 'string' then
			error(("ASource constructor: 2nd parameter must be a string; " ..
				"got %s instead."):format(type(b)))
		end
		if not ({static = true, stream = true})[b] then
			error(("ASource constructor: 2nd parameter must be either `static` or `stream`; " ..
				"got %s instead."):format(tostring(b)))
		end
		sourcetype = b

	elseif a.type and a:type() == 'SoundData' then
		-- Can only be static type.
		sourcetype = 'static'

	else
		error(("ASource constructor: 1st parameter was %s; must be one of the following:\n" ..
			"string, File, FileData, Decoder, SoundData, number."):format(tostring(a)))
	end



	-- /!\ ONLY STATIC TYPE SUPPORTED CURRENTLY.
	if sourcetype ~= 'static' then
		error("Can't yet create streaming or queue type sources!")
	end



	-- The instance we're constructing.
	local instance = {}

	-- Load in initial data.
	if sourcetype == 'queue' then
		-- We only have format parameters.
		instance.data           = false
		instance.samplingRate   = a
		instance.bitDepth       = b
		instance.channelCount   = c
		instance.OALBufferCount = d
	else
		if sourcetype == 'static' then
			if              type(a) == 'string'      or
				a.type and a:type() == 'File'        or
				a.type and a:type() == 'DroppedFile' or
				a.type and a:type() == 'FileData'
			then
				-- Load from given path, file object reference, or memory-mapped file data object.
				-- This might not work for File and/or FileData, but it will by inserting
				-- a Decoder in-between. Source says this already does that, however.
				instance.data = love.sound.newSoundData(a)
			elseif a.type and a:type() == 'Decoder'
			then
				-- We create a new SoundData from the given Decoder object; fully decoded.
				instance.data = love.sound.newSoundData(a)
			elseif a.type and a:type() == 'SoundData'
			then
				-- We set the data to the provided object.
				instance.data = a
			end
		else--if sourcetype == 'stream' then
			if              type(a) == 'string'      or
				a.type and a:type() == 'File'        or
				a.type and a:type() == 'DroppedFile' or
				a.type and a:type() == 'FileData'
			then
				-- Load from given path, file object reference, or memory-mapped file data object.
				-- Initial decoder object will return default sized SoundData objects.
				instance.data = love.sound.newDecoder(a)
			elseif a.type and a:type() == 'Decoder'
			then
				-- We store the provided Decoder object.
				instance.data = a
			end
		end

		-- Fill out format parameters.
		instance.samplingRate = instance.data:getSampleRate()
		instance.bitDepth     = instance.data:getBitDepth()
		instance.channelCount = instance.data:getChannelCount()

		-- Check for optional OAL buffer count parameter; nil for default value otherwise.
		instance.OALBufferCount = nil
		if              type(a) == 'string'      or
			a.type and a:type() == 'File'        or
			a.type and a:type() == 'DroppedFile' or
			a.type and a:type() == 'FileData'    or
			a.type and a:type() == 'Decoder'
		then
			if type(c) == 'number' then
				instance.OALBufferCount = c
			elseif type(c) ~= 'nil' then
				error(("3rd, optional parameter expected to be a number between 1 and 64; " ..
					"got %s instead."):format(type(c)))
			end
		elseif a.type and a:type() == 'SoundData'
		then
			if type(b) == 'number' then
				instance.OALBufferCount = b
			elseif type(b) ~= 'nil' then
				error(("2nd, optional parameter expected to be a number between 1 and 64; " ..
					"got %s instead."):format(type(b)))
			end
		end
	end

	-- Check for optional output aurality param.; default is input aurality, a.k.a. channel count.
	instance.outputAurality = instance.channelCount
	if sourcetype == 'queue' then
		instance.outputAurality = type(e) == 'number' and e
	else
		if              type(a) == 'string'      or
			a.type and a:type() == 'File'        or
			a.type and a:type() == 'DroppedFile' or
			a.type and a:type() == 'FileData'    or
			a.type and a:type() == 'Decoder'
		then
			if type(d) == 'number' then
				instance.outputAurality = d
			elseif type(d) ~= 'nil' then
				error(("4th, optional parameter expected to be a number, either 1 or 2; " ..
					"got %s instead."):format(type(d)))
			end
		elseif a.type and a:type() == 'SoundData'
		then
			if type(c) == 'number' then
				instance.outputAurality = c
			elseif type(c) ~= 'nil' then
				error(("3rd, optional parameter expected to be a number, either 1 or 2; " ..
					"got %s instead."):format(type(c)))
			end
		end
	end

	-- Set up fields not coming from the constructor arguments.
	do
		-- The type of this instance.
		instance.type = sourcetype

		-- Size of the buffer used for processing.
		instance.bufferSize    = 50 * 0.001 * instance.samplingRate

		-- Size of the frame we use for applying effects onto the data, without variance.
		instance.frameSize     = 35 * 0.001 * instance.samplingRate
		-- The amount of frame size variance centered on the above value, in smp-s.
		instance.frameVariance = 17 * 0.001 * instance.samplingRate
		-- The random distribution to use for varying the buffer's size.
		instance.frameVarianceDistributionIdx = 1
		-- The pre-calculated min, max and currently applied frame size, for performance reasons.
		instance.minFrameSize  = nil
		instance.maxFrameSize  = nil
		calculateFrameCoefficients(instance)
		-- The variable holding the final TSM frame size that gets used.
		instance.curFrameSize  =  instance.frameSize
		-- Store the current point in the TSM frame we're at, due to this not being aligned with
		-- the used buffer size.
		instance._frameIndex   = 0

		-- The playback state; stopped by default.
		instance.playing = false
		-- The playback pointer in smp-s that is used as an offset into the data; can be fractional.
		instance.playbackOffset = 0.0

		-- Whether the playback should loop.
		instance.looping = false
		-- The start and end points in smp-s that define the loop region; can be disjunct by having
		-- the endpoint before the startpoint. Points are inclusive.
		-- By default, the loop region is either the entirety of the given input, or the frame size
		-- for queue-type sources. 
		instance.loopRegionA = 0
		instance.loopRegionB = 0
		-- Helper variable to guarantee playback not being initially locked between the loop region.
		-- False by default, stopping and redefining the loop region resets the field to false.
		-- If no loop region is defined, then this turns true instantly when starting playback.
		instance.loopRegionEntered = false

		-- The indice of the interpolation method used when rendering data into the buffer.
		-- Default is 1 for linear.
		instance.itplMethodIdx = 1

		-- The indice of the TSM mixing method used. Default is 0 for automatic mode.
		-- Reasoning: For smaller buffer sizes, cosine interpolation does introduce some modulation
		-- noise due to nonlinearity, however, for all situations where pitch shift and time stretch
		-- are not related (i.e. it's just a change in resampling), cosine gets rid of audible
		-- amplitude fluctuations, which may be better; auto mode sets the method used automatically
		-- based on the above.
		instance.mixMethodIdx = 0

		-- Resampling ratio; the simple way of combined speed and pitch modification.
		instance.resampleRatio = 1.0
		-- Time stretching; Uses Time-Scale Modification as the method.
		instance.timeStretch   = 1.0
		-- Pitch shifting; stored both as a ratio, and in semitones for accuracy.
		instance.pitchShift    = 1.0
		instance.pitchShiftSt  = 0
		-- The pre-calculated playback rate coefficients, for performance reasons.
		-- The rate of smp advancement in one frame and the rate of frame advancement, respectively.
		instance.innerOffset = nil
		instance.outerOffset = nil
		instance.frameAdvance = nil -- Me avoiding responsibilities :c
		calculateTSMCoefficients(instance)
		-- Flag to know we need to recalculate the coefficients
		-- Note: Easier to only do this at Frame borders vs. mathing out what this does mid-frame.
		instance._recalcTSMCoefficients = false

		-- The panning law string and the function in use.
		instance.panLaw     = 0
		instance.panLawFunc = PanLawFunc[instance.panLaw]

		-- Panning value; operates on input so even with mono output, this has an impact.
		-- Can go from 0.0 to 1.0; default is 0.5 for centered.
		instance.panning = 0.5
		-- The pre-calculated left and right panning coefficients, for performance reasons.
		instance.panL = nil
		instance.panR = nil
		calculatePanningCoefficients(instance)

		-- Stereo separation value; operates on input so even with mono output, this has an impact.
		-- Can go from -100% to 100%, from mid ch. downmix to original to side ch. downmix.
		instance.separation = 0.0
	end

	-- Create internal buffer; format adheres to output.
	instance.buffer = love.sound.newSoundData(
		instance.bufferSize,
		instance.samplingRate,
		instance.bitDepth,
		instance.outputAurality
	)

	-- Create internal queueable source; format adheres to output.
	instance.source = love.audio.newQueueableSource(
		instance.samplingRate,
		instance.bitDepth,
		instance.outputAurality,
		instance.OALBufferCount
	)

	-- Set default loop region's end point.
	if instance.type == 'queue' then
		instance.loopRegionB = instance.frameSize - 1
	elseif instance.type == 'static' then
		instance.loopRegionB = instance.data:getSampleCount() - 1
	else--if instance.type == 'stream' then
		instance.loopRegionB = instance.data:getDuration() * instance.samplingRate - 1
	end

	-- Set up method calls.
	setmetatable(instance, mtASource)

	-- Make the instance have an unique id, and add instance to the internal tables.
	local id = #ASourceList + 1
	instance.id = id
	ASourceList[id] = instance
	ASourceIMap[id] = id

	-- Return the id number so a proxy instance can be constructed on the caller thread.
	return id
end



----------------------------------------------------------------------------------------------------

-- Copy-constructor

function ASource.clone(instance)
	local clone = {}

	-- Shallow-copy over all parameters as an initial step.
	for k,v in pairs(instance) do
		clone[k] = v
	end

	-- Set the playback state to stopped, which also resets the pointer to the start.
	-- Due to reverse playback support, the start point is dependent on the playback direction.
	clone._isPlaying = false
	if     clone.type == 'static' then
		clone.pointer = clone.timeStretch >= 0 and 0 or math.max(0, clone.data:getSampleCount()-1)
	elseif clone.type == 'stream' then
		-- Not Yet Implemented.
	else--if clone.type == 'queue' then
		-- Not Yet Implemented.
	end

	-- Data source object: SoundData gets referenced by the shallow-copy above;
	--                     Decoder gets cloned, Queue has none.
	if clone.type == 'stream' then
		-- This should work even if the Decoder was created from a DroppedFile.
		clone.data = instance.data:clone()
	end

	-- Buffer object: Create an unique one.
	clone.buffer = love.sound.newSoundData(
		clone.bufferSize,
		clone.samplingRate,
		clone.bitDepth,
		clone.channelCount
	)

	-- Internal QSource object: Clone it.
	-- BUG: Cloning a queueable source doesn't give back a functioning one; temporary fix.
	--clone.source = instance.source:clone()
	clone.source = love.audio.newQueueableSource(
		clone.samplingRate,
		clone.bitDepth,
		clone.outputAurality,
		clone.OALBufferCount
	)
	-- Due to the above duct tape, we also need to manually copy over QSource internals that aren't
	-- touched by the library:
	local fxlist = instance.source:getActiveEffects()
	for i,name in ipairs(fxlist) do
		local filtersettings = instance.source:getEffect(name)
		if filtersettings then
			clone.source:setEffect(name, filtersettings)
		else
			clone.source:setEffect(name, true)
		end
	end
	clone.source:setFilter(               instance.source:getFilter())
	clone.source:setAirAbsorption(        instance.source:getAirAbsorption())
	clone.source:setAttenuationDistances( instance.source:getAttenuationDistances())
	clone.source:setCone(                 instance.source:getCone())
	clone.source:setDirection(            instance.source:getDirection())
	clone.source:setPosition(             instance.source:getPosition())
	clone.source:setRolloff(              instance.source:getRolloff())
	clone.source:setVelocity(             instance.source:getVelocity())
	clone.source:setRelative(             instance.source:isRelative())
	clone.source:setVolumeLimits(         instance.source:getVolumeLimits())
	clone.source:setVolume(               instance.source:getVolume())

	-- Make sure all library-specific internals are configured correctly.
	calculateTSMCoefficients(clone)
	calculatePanningCoefficients(clone)
	calculateFrameCoefficients(clone)

	-- Set instance metatable.
	setmetatable(clone, mtASource)

	-- Make clone have an unique id, and add instance to the internal tables.
	local id = #ASourceList + 1
	clone.id = id
	ASourceList[id] = clone
	ASourceIMap[id] = id

	-- Return the id number so a proxy instance can be constructed on the caller thread.
	return id
end



----------------------------------------------------------------------------------------------------

-- Base class overrides (Object)

function ASource.type(instance)
	return 'ASource'
end

function ASource.typeOf(instance, type)
	if type == 'ASource' or type == 'Source' or type == 'Object' then
		return true
	end
	return false
end

function ASource.release(instance)
	-- Clean up the whole instance itself.
	local id = instance.id
	if instance.data then instance.data:release() end
	instance.buffer:release()
	instance.source:release()
	for k,v in pairs(instance) do k = nil end

	-- Remove the instance from both tables we do book-keeping in.
	local this = ASourceList[ASourceIMap[id]]
	local last = ASourceList[#ASourceList]
	if this == last then
		-- There's only one instance, or we're deleting the last one in the list.
		ASourceList[ASourceIMap[id]] = nil
	else
		-- Remove the instance, move the last one in the list to the removed one's position.
		-- Also update the indice mapping table as well.
		local lastid = ASourceList[#ASourceList].id
		ASourceList[ASourceIMap[id]] = ASourceList[#ASourceList]
		ASourceList[#ASourceList]    = nil
		ASourceIMap[lastid]          = ASourceIMap[id]
	end
	ASourceIMap[id] = nil
end



----------------------------------------------------------------------------------------------------

-- Internally used across threads

function ASource.getInternalSource(instance)
	return instance.source
end



----------------------------------------------------------------------------------------------------

-- Deprecations

function ASource.setPitch(instance)
	error("Function deprecated by Advanced Source Library; " ..
		"for the same functionality, use setResamplingRatio instead.")
end

function ASource.getPitch(instance)
	error("Function deprecated by Advanced Source Library; " ..
		"for the same functionality, use getResamplingRatio instead.")
end



----------------------------------------------------------------------------------------------------

-- Queue related

function ASource.queue(instance, ...)
	if instance.type ~= 'queue' then
		error("Cannot call queue on a non-queueable ASource instance.")
	end

	return Queue(instance, ...)
end



----------------------------------------------------------------------------------------------------

-- Format related

function ASource.getType(instance)
	return instance.type
end

function ASource.getSampleRate(instance)
	return instance.samplingRate
end

function ASource.getBitDepth(instance)
	return instance.bitDepth
end

function ASource.getChannelCount(instance)
	-- The user needs the output format, not the input, so we return that instead.
	return instance.outputAurality --instance.channelCount
end



----------------------------------------------------------------------------------------------------

-- Buffer related (Warning: Don't resize the buffer each frame, that might tank performance.)

function ASource.getBufferSize(instance, unit)
	unit = unit or 'milliseconds'

	if not BufferUnit[unit] then
		error(("1st parameter must be `milliseconds`, `samples` or left empty; " ..
			"got %s instead."):format(tostring(unit)))
	end

	if unit == 'samples' then
		return instance.bufferSize
	else--if unit == 'milliseconds' then
		return instance.bufferSize / instance.samplingRate * 1000
	end
end

function ASource.setBufferSize(instance, size, unit)
	unit = unit or 'milliseconds'

	if not BufferUnit[unit] then
		error(("2nd parameter must be `milliseconds`, `samples` or left empty; " ..
			"got %s instead."):format(tostring(unit)))
	end

	if not size then
		error("Missing 1st parameter, must be a non-negative number.")
	end
	if type(size) ~= 'number' then
		error(("1st parameter must be a non-negative number; " ..
			"got %s instead."):format(tostring(size)))
	end

	local min, max
	if unit == 'samples' then
		min =  1 * 0.001 * instance.samplingRate --  1 ms
		max = 10         * instance.samplingRate -- 10 s
	else--if unit = 'milliseconds' then
		min =  1        --  1 ms
		max = 10 * 1000 -- 10 s
	end
	if size < min or size > max then
		error(("1st parameter out of range; " ..
			"min/given/max: %f < [%f] < %f (%s)."):format(min, size, max, unit))
	end

	if unit == 'samples' then
		instance.bufferSize = size
	else--if unit = 'milliseconds' then
		instance.bufferSize = math.floor(size * 0.001 * instance.samplingRate + 0.5)
	end

	-- Recreate internal buffer.
	-- Note: We can assume that this call never happens mid-processing, so we never lose
	--       previous buffer contents, no copying necessary.
	instance.buffer:release()
	instance.buffer = love.sound.newSoundData(
		instance.bufferSize,
		instance.samplingRate,
		instance.bitDepth,
		instance.outputAurality
	)
end



----------------------------------------------------------------------------------------------------

-- TSM Frame related

function ASource.getFrameSize(instance, unit)
	unit = unit or 'milliseconds'

	if not BufferUnit[unit] then
		error(("1st parameter must be `milliseconds`, `samples` or left empty; " ..
			"got %s instead."):format(tostring(unit)))
	end

	if unit == 'samples' then
		return instance.frameSize,
		       instance.curFrameSize
	else--if unit == 'milliseconds' then
		return instance.frameSize    / instance.samplingRate * 1000,
		       instance.curFrameSize / instance.samplingRate * 1000
	end
end

function ASource.setFrameSize(instance, size, unit)
	unit = unit or 'milliseconds'

	if not BufferUnit[unit] then
		error(("2nd parameter must be `milliseconds`, `samples` or left empty; " ..
			"got %s instead."):format(tostring(unit)))
	end

	if not size then
		error("Missing 1st parameter, must be a non-negative number.")
	end
	if type(size) ~= 'number' then
		error(("1st parameter must be a non-negative number; " ..
			"got %s instead."):format(tostring(size)))
	end

	local min, max
	if unit == 'samples' then
		min =  1 * 0.001 * instance.samplingRate --  1 ms
		max = 10         * instance.samplingRate -- 10 s
	else--if unit = 'milliseconds' then
		min =  1        --  1 ms
		max = 10 * 1000 -- 10 s
	end
	if size < min or size > max then
		error(("1st parameter out of range; " ..
			"min/given/max: %f < [%f] < %f (%s)."):format(min, size, max, unit))
	end

	if unit == 'samples' then
		instance.frameSize = size
	else--if unit = 'milliseconds' then
		instance.frameSize = math.floor(size * 0.001 * instance.samplingRate + 0.5)
	end

	calculateFrameCoefficients(instance)
end

function ASource.getFrameVariance(instance, unit)
	unit = unit or 'milliseconds'

	if not VarianceUnit[unit] then
		error(("1st parameter must be `milliseconds`, `samples`, `percentage` or left empty; " ..
			"got %s instead."):format(tostring(unit)))
	end

	if unit == 'samples' then
		return instance.frameVariance
	elseif unit == 'milliseconds' then
		return instance.frameVariance / instance.samplingRate * 1000
	else--if unit == 'percentage' then
		return instance.frameVariance / instance.frameSize
	end
end

function ASource.setFrameVariance(instance, variance, unit)
	unit = unit or 'milliseconds'

	if not VarianceUnit[unit] then
		error(("2nd parameter must be `milliseconds`, `samples`, `percentage` or left empty; " ..
			"got %s instead."):format(tostring(unit)))
	end

	if not variance then
		error("Missing 1st parameter, must be a non-negative number.")
	end
	if type(variance) ~= 'number' then
		error(("1st parameter must be a non-negative number; " ..
			"got %s instead."):format(tostring(variance)))
	end
	if variance < 0 then
		error(("1st parameter must be a non-negative number; " ..
			"got %f instead."):format(variance))
	end

	if unit == 'percentage' and variance > 1.0 then
		error(("1st parameter as a percentage can't be more than 100%; " ..
			"got %f%% (%f) instead."):format(math.floor(variance*100), variance))
	end

	if unit == 'samples' then
		instance.frameVariance = variance
	elseif unit == 'milliseconds' then
		instance.frameVariance = math.floor(variance * 0.001 * instance.samplingRate + 0.5)
	else --if unit == 'percentage' then
		instance.frameVariance = math.floor(instance.frameSize * variance + 0.5)
	end

	calculateFrameCoefficients(instance)
end

function ASource.getFrameVarianceDistribution(instance)
	return VarDistType[instance.frameVarianceDistributionIdx]
end

function ASource.setFrameVarianceDistribution(instance, distribution)
	if not VarDistIMap[distribution] then
		error(("1st parameter is not a supported buffer variance distribution; got %s.\n" ..
			"Supported: `uniform`, `normal`"):format(tostring(distribution)))
	end
	instance.frameVarianceDistributionIdx = VarDistIMap[distribution]

	--calculateFrameCoefficients(instance)
end



----------------------------------------------------------------------------------------------------

-- Playback state related

function ASource.isPlaying(instance)
	return instance.playing
end

function ASource.play(instance)
	instance.playing = true
	return true
end

--[[
function ASource.isPaused(instance)
	if instance.playing then
		return false
	end

	if instance.timeStretch >= 0 then
		if instance:tell() == 0 then
			return false
		end
	else--if instance.timeStretch < 0 then
		local limit

		if instance.type == 'static' then
			limit = math.max(0, instance.data:getSampleCount() - 1)
		else--if instance.type == 'stream' then
			limit = math.max(0, instance.data:getDuration() * instance.samplingRate - 1)
		end

		if instance:tell() == limit then
			return false
		end
	end

	return true
end
--]]

function ASource.pause(instance)
	instance.playing = false
	return true
end

--[[
function ASource.isStopped(instance)
	if instance.playing then
		return false
	end

	if instance.timeStretch >= 0 then
		if instance:tell() ~= 0 then
			return false
		end
	else--if instance.timeStretch < 0 then
		local limit

		if instance.type == 'static' then
			limit = math.max(0, instance.data:getSampleCount() - 1)
		else--if instance.type == 'stream' then
			limit = math.max(0, instance.data:getDuration() * instance.samplingRate - 1)
		end

		if instance:tell() ~= limit then
			return false
		end
	end

	return true
end
--]]

function ASource.stop(instance)
	instance:pause()
	instance:rewind()
	return true
end



function ASource.tell(instance, unit)
	unit = unit or 'seconds'

	if not TimeUnit[unit] then
		error(("1st parameter must be `seconds`, `samples` or left empty; " ..
			"got %s instead."):format(tostring(unit)))
	end

	if instance.type == 'queue' then
		-- Tell the source object.
		return instance.source:tell(unit)

	else
		if unit == 'samples' then
			return instance.playbackOffset
		else
			return instance.playbackOffset / instance.samplingRate
		end
	end
end

function ASource.seek(instance, position, unit)
	unit = unit or 'seconds'

	if not TimeUnit[unit] then
		error(("2nd parameter must be `seconds`, `samples` or left empty; " ..
			"got %s instead."):format(tostring(unit)))
	end

	if not position then
		error("Missing 1st parameter, must be a non-negative number.")
	end
	if type(position) ~= 'number' then
		error(("1st parameter must be a non-negative number; " ..
			"got %s instead."):format(tostring(position)))
	end
	if position < 0 then
		error(("1st parameter must be a non-negative number; " ..
			"got %f instead."):format(position))
	end

	if instance.type == 'queue' then
		-- Seek the source object.
		instance.source:seek(position, unit)

	else
		if unit == 'samples' then
			local limit

			if instance.type == 'static' then
				limit = instance.data:getSampleCount()
			else--if instance.type == 'stream' then
				limit = instance.data:getDuration() * instance.samplingRate
			end

			if position >= limit then
				error(("1st parameter outside of data range; " ..
					"%f > %f."):format(position, limit))
			end

			instance.playbackOffset = position

		else--if unit == 'seconds' then
			local limit

			if instance.type == 'static' then
				limit = instance.data:getDuration()
			else--if instance.type == 'stream' then
				limit = instance.data:getDuration()
			end

			if position >= limit then
				error(("1st parameter outside of data range; " ..
					"%f > %f."):format(position, limit))
			end

			instance.playbackOffset = position * instance.samplingRate
		end

		-- Seeking resets initial loop state.
		instance.loopRegionEntered = false
	end
end

function ASource.getDuration(instance, unit)
	unit = unit or 'seconds'

	if not TimeUnit[unit] then
		error(("1st parameter must be `seconds`, `samples` or left empty; " ..
			"got %s instead."):format(tostring(unit)))
	end

	if instance.type == 'queue' then
		-- Get the duration of the source object.
		return instance.source:getDuration(unit)
	else
		if unit == 'samples' then
			if instance.type == 'static' then
				return instance.data:getSampleCount()
			else--if instance.type == 'stream' then
				return instance.data:getDuration() * instance.samplingRate
			end
		else--if unit == 'seconds' then
			if instance.type == 'static' then
				return instance.data:getDuration()
			else--if instance.type == 'stream' then
				return instance.data:getDuration()
			end
		end
	end
end

function ASource.rewind(instance)
	if instance.type == 'queue' then
		-- Rewind the source object.
		instance.source:seek(0)
	else
		-- Use the seek method.
		if instance.timeStretch >= 0 then
			instance:seek(0, 'samples')
		else
			if instance.type == 'static' then
				instance:seek(math.max(0,
					instance.data:getSampleCount() - 1), 'samples')
			else--if instance.type == 'stream' then
				instance:seek(math.max(0,
					instance.data:getDuration() * instance.samplingRate - 1), 'samples')
			end
		end
	end
	return true
end



----------------------------------------------------------------------------------------------------

-- Looping related

function ASource.isLooping(instance)
	-- Löve also just returns false for queue-type Sources as well.
	return instance.looping
end

function ASource.setLooping(instance, state)
	if instance.type == 'queue' then
		error("Can't set looping behaviour on queue-type Sources.")
	end

	if type(state) ~= 'boolean' then
		error(("1st parameter must be boolean; " ..
			"got %s instead."):format(type(state)))
	end

	instance.looping = state

	-- Setting loop state resets initial loop state.
	instance.loopRegionEntered = false
end

function ASource.getLoopPoints(instance)
	-- Let's just return the default values even with queue-type Sources.
	return instance.loopRegionA, instance.loopRegionB
end

function ASource.setLoopPoints(instance, pointA, pointB)
	if instance.type == 'queue' then
		error("Can't set looping region on queue-type Sources.")
	end

	if (pointA == nil) and (pointB == nil) then
		error("At least one of the endpoints of the looping region must be given.")
	end

	local limit
	if instance.type == 'static' then
		limit = instance.data:getSampleCount()
	else--if instance.type == 'stream' then
		limit = instance.data:getDuration() * instance.samplingRate
	end

	if pointA ~= nil then
		if (type(pointA) ~= 'number' or pointA < 0) then
			error(("1st parameter must be a non-negative number; " ..
				"got %s of type %s instead."):format(pointA, type(pointA)))
		end

		if pointA >= limit then
			error(("1st parameter must be less than the length of the data; " ..
				"%f > %f."):format(pointA, limit))
		end

		instance.loopRegionA = pointA
	end
	if pointB ~= nil then
		if (type(pointB) ~= 'number' or pointB < 0) then
			error(("2nd parameter must be a non-negative number; " ..
				"got %s of type %s instead."):format(pointB, type(pointB)))
		end

		if pointB >= limit then
			error(("2nd parameter must be less than the length of the data; " ..
				"%f > %f."):format(pointB, limit))
		end

		instance.loopRegionB = pointB
	end

	-- Setting loop state resets initial loop state.
	instance.loopRegionEntered = false
end



----------------------------------------------------------------------------------------------------

-- Interpolation related

function ASource.getInterpolationMethod(instance)
	return ItplMethodList[instance.itplMethodIdx]
end

function ASource.setInterpolationMethod(instance, method)
	if not ItplMethodIMap[method] then
		error(("1st parameter not a supported interpolation method; got %s.\n" ..
			"Supported: `nearest`, `linear`, `cubic`, `sinc`."):format(tostring(method)))
	end
	instance.itplMethodIdx = ItplMethodIMap[method]
end



----------------------------------------------------------------------------------------------------

-- TSM related (TSM buffer mixing also uses interpolation)

function ASource.getMixMethod(instance)
	return MixMethodList[instance.mixMethodIdx]
end

function ASource.setMixMethod(instance, method)
	if not MixMethodIMap[method] then
		error(("1st parameter not a supported mixing method; got %s.\n" ..
			"Supported: `auto`, `linear`, `sqroot`, 'cosine'."):format(tostring(method)))
	end
	instance.mixMethodIdx = MixMethodIMap[method]
end

function ASource.getResamplingRatio(instance)
	return instance.resampleRatio
end

function ASource.setResamplingRatio(instance, ratio)
	if not ratio then
		error("Missing 1st parameter, must be a number.")
	end
	if type(ratio) ~= 'number' then
		error(("1st parameter must be a number; " ..
			"got %s instead."):format(tostring(ratio)))
	end

	instance.resampleRatio = ratio

	instance._recalcTSMCoefficients = true
end

function ASource.getTimeStretch(instance)
	return instance.timeStretch
end

function ASource.setTimeStretch(instance, ratio)
	if not ratio then
		error("Missing 1st parameter, must be a number.")
	end
	if type(ratio) ~= 'number' then
		error(("1st parameter must be a number; " ..
			"got %s instead."):format(tostring(ratio)))
	end

	instance.timeStretch = ratio

	instance._recalcTSMCoefficients = true
end

function ASource.getPitchShift(instance, unit)
	unit = unit or 'ratio'

	if not PitchUnit[unit] then
		error(("1st parameter must be `ratio`, `semitones` or left empty; " ..
			"got %s instead."):format(tostring(unit)))
	end

	if unit == 'ratio' then
		return instance.pitchShift
	else--if unit == 'semitones' then
		return instance.pitchShiftSt
	end
end

function ASource.setPitchShift(instance, amount, unit)
	unit = unit or 'ratio'

	if not PitchUnit[unit] then
		error(("2nd parameter must be `ratio`, `semitones` or left empty; " ..
			"got %s instead."):format(tostring(unit)))
	end

	if not amount then
		error("Missing 1st parameter, must be a number.")
	end
	if type(amount) ~= 'number' then
		error(("1st parameter must be a number; " ..
			"got %s instead."):format(tostring(amount)))
	end

	if unit == 'ratio' then
		if amount <= 0 then
			error(("1st parameter must be a positive number as a ratio; " ..
				"got %f instead."):format(amount))
		end
		instance.pitchShift   = amount
		instance.pitchShiftSt = (math.log(amount)/math.log(2))*12
	else--if unit == 'semitones' then
		instance.pitchShift   = 2^(amount/12)
		instance.pitchShiftSt = amount
	end

	instance._recalcTSMCoefficients = true
end



----------------------------------------------------------------------------------------------------

-- Panning & stereo separation related

function ASource.getPanLaw(instance)
	-- Returning the custom function one might have defined is not supported. It's "custom".
	if instance.panLaw == 2 then
		return 'custom'
	end
	return PanLawList[instance.panLaw]
end

function ASource.setPanLaw(instance, law)
	if not law then
		error("Missing 1st parameter, must be `gain`, `power` or a function " ..
			"with one input and two output parameters: [0,1]->[0,1],[0,1].")
	end

	if type(law) == 'string' then
		if not PanLawIMap[law] then
			error(("1st parameter as a string must be `gain` or `power`; " ..
			"got %s instead."):format(law))
		end

		instance.panLaw     = PanLawIMap[law]
		instance.panLawFunc = PanLawFunc[PanLawIMap[law]]

	elseif type(law) == 'function' then
		-- Minimal testing done on the given function.
		for i,v in ipairs{0.00, 0.25, 0.33, 0.50, 0.67, 1.00} do
			local ok, l,r = pcall(law, v)
			if not ok then
				error(("The given pan law function is errorenous: %s"):format(l))
			end
			if type(l) ~= 'number' or type(r) ~= 'number' then
				error(("The given pan law function must return two numbers; " ..
					"got %s and %s instead."):format(type(l), type(r)))
			end
			if l < 0.0 or l > 1.0 or r < 0.0 or r > 1.0 then
				error(("The given pan law function's return values must be in [0.0,1.0]; " ..
					"got %f and %f instead."):format(l, r))
			end

			instance.panLaw     = PanLawIMap['custom']
			instance.panLawFunc = law
		end

	else
		error(("1st parameter must be a string or a function; " ..
			"got %s instead."):format(type(law)))
	end

	calculatePanningCoefficients(instance)
end

function ASource.getPanning(instance)
	return instance.panning
end

function ASource.setPanning(instance, pan)
	if not pan then
		error("Missing 1st parameter, must be a number between 0 and 1 inclusive.")
	end
	if type(pan) ~= 'number' then
		error(("1st parameter must be a number between 0 and 1 inclusive; " ..
			"got %s instead."):format(tostring(pan)))
	end
	if pan < 0 or pan > 1 then
		error(("1st parameter must be a number between 0 and 1 inclusive; " ..
			"got %f instead."):format(pan))
	end

	instance.panning = pan

	calculatePanningCoefficients(instance)
end

function ASource.getStereoSeparation(instance)
	return instance.separation
end

function ASource.setStereoSeparation(instance, sep)
	if not sep then
		error("Missing 1st parameter, must be a number between -1 and 1 inclusive.")
	end
	if type(sep) ~= 'number' then
		error(("1st parameter must be a number between -1 and 1 inclusive; " ..
			"got %s instead."):format(tostring(sep)))
	end
	if sep < -1.0 or sep > 1.0 then
		error(("1st parameter must be a number between -1 and 1 inclusive; " ..
			"got %f instead."):format(sep))
	end

	instance.separation = sep
end



----------------------------------------------------------------------------------------------------

-- Methods that aren't modified; instead of overcomplicated metatable stuff, just have them here.

function ASource.getFreeBufferCount(instance, ...)
	return instance.source:getFreeBufferCount(...)
end

function ASource.getEffect(instance, ...)
	return instance.source:getEffect(...)
end
function ASource.setEffect(instance, ...)
	return instance.source:setEffect(...)
end
function ASource.getFilter(instance, ...)
	return instance.source:getFilter(...)
end
function ASource.setFilter(instance, ...)
	return instance.source:setFilter(...)
end
function ASource.getActiveEffects(instance, ...)
	return instance.source:getActiveEffects(...)
end

function ASource.getAirAbsorption(instance, ...)
	return instance.source:getAirAbsorption(...)
end
function ASource.setAirAbsorption(instance, ...)
	return instance.source:setAirAbsorption(...)
end
function ASource.getAttenuationDistances(instance, ...)
	return instance.source:getAttenuationDistances(...)
end
function ASource.setAttenuationDistances(instance, ...)
	return instance.source:setAttenuationDistances(...)
end
function ASource.getCone(instance, ...)
	return instance.source:getCone(...)
end
function ASource.setCone(instance, ...)
	return instance.source:setCone(...)
end
function ASource.getDirection(instance, ...)
	return instance.source:getDirection(...)
end
function ASource.setDirection(instance, ...)
	return instance.source:setDirection(...)
end
function ASource.getPosition(instance, ...)
	return instance.source:getPosition(...)
end
function ASource.setPosition(instance, ...)
	return instance.source:setPosition(...)
end
function ASource.getRolloff(instance, ...)
	return instance.source:getRolloff(...)
end
function ASource.setRolloff(instance, ...)
	return instance.source:setRolloff(...)
end
function ASource.getVelocity(instance, ...)
	return instance.source:getVelocity(...)
end
function ASource.setVelocity(instance, ...)
	return instance.source:setVelocity(...)
end
function ASource.isRelative(instance, ...)
	return instance.source:isRelative(...)
end
function ASource.setRelative(instance, ...)
	return instance.source:setRelative(...)
end
function ASource.getVolumeLimits(instance, ...)
	return instance.source:getVolumeLimits(...)
end
function ASource.setVolumeLimits(instance, ...)
	return instance.source:setVolumeLimits(...)
end

function ASource.getVolume(instance, ...)
	return instance.source:getVolume(...)
end
function ASource.setVolume(instance, ...)
	return instance.source:setVolume(...)
end


----------------------------------------------------------------------------------------------------

-- Main thread loop

while true do
	-- Handle messages in inbound queue. Atomic operations in the other threads should guarantee 
	-- the ordering of inbound messages.
	local msg = toProc:pop()

	if     msg == 'procThread!' then
		-- Initialization of this thread successful, next value is the reference to it.
		procThread = toProc:pop()
	
	elseif msg == 'procThread?' then
		-- This thread already initialized, send back its reference;
		-- Next value in queue is the channel to the querying thread.
		local ch = toProc:pop()
		ch:push(procThread)

	elseif msg == 'pauseall' then
		-- Support love.audio.pause call variant, with return values.
		local ch = toProc:pop()
		local idList = {}
		for i=1, #ASourceList do
			if ASourceList[i]:isPlaying() then
				ASourceList[i]:pause()
				table.insert(idList, ASourceList[i].id)
			end
		end
		ch:performAtomic(function(ch)
			ch:push(#idList)
			if #idList > 0 then
				for i=1, #idList do
					ch:push(idList[i])
				end
			end
		end)

	elseif msg == 'stopall' then
		-- Support love.audio.stop call variant.
		local ch = toProc:pop()
		for i=1, #ASourceList do ASourceList[i]:stop() end
		ch:push(true)

	elseif msg == 'new' then
		-- Construct a new ASource using parameters popped from the inbound queue,
		-- then send back the instance's id so a proxy instance can be constructed there.
		local ch, a, b, c, d, e, id
		ch = toProc:pop()
		a  = toProc:pop()
		b  = toProc:pop()
		c  = toProc:pop()
		d  = toProc:pop()
		e  = toProc:pop()

		id = new(a, b, c, d, e)

		ch:push(id)

	elseif ASource[msg] then
		-- Redefined methods and ones we "reverse-inherit" from the internally used QSource.
		-- <methodName> (above), <ch>, <id>, <paramCount>, [<parameter1>, ..., <parameterN>]
		local ch = toProc:pop()
		local id = toProc:pop()
		local paramCount = toProc:pop()
		local parameters = {}
		if paramCount > 0 then
			for i=1, paramCount do
				parameters[i] = toProc:pop()
			end
		end

		-- setPanLaw is the only method that potentially supports as parameter a function,
		-- we need to parse that here so it's not a dumped string anymore.
		if msg == 'setPanLaw' and not PanLawIMap[parameters[1]] then
			local success, _ = loadstring(parameters[1])
			if success then parameters[1] = success end
		end

		-- Get instance based on id.
		local instance = ASourceList[ASourceIMap[id]]
		
		-- Execute.
		local result = {instance[msg](instance, unpack(parameters))}

		-- Return results to the querying thread.
		-- <methodName>, <retvalCount>, [<retval1>, ..., <retvalN>]
		ch:performAtomic(function(ch)
			ch:push(#result)
			if #result > 0 then
				for i=1, #result do
					ch:push(result[i])
				end
			end
		end)
	end

	-- Update active instances.
	for i = 1, #ASourceList do
		local instance = ASourceList[i]

		-- If instance is not in the playing state, then skip queueing more data, since we don't
		-- want to have silent sources occupying any active source slots.
		if instance.playing then

			-- If there is at least one empty internal buffer, do work.
			-- Cheap bugfix for now, refactoring will deal with this later.
			if instance.source:getFreeBufferCount() > 0 then

				-- Process data.
				Process[instance.type](instance)
			end
		end
	end

	-- Don't hog a core.
	love.timer.sleep(0.001)
end