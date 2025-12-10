--!strict
--[[
	Noise.lua - 3D noise functions for procedural terrain generation
	
	Shared utility used by multiple terrain tools (Noise, Megarandomize, 
	Stalactite, Tendril, Growth, etc.)
]]

local Noise = {}

-- Hash function for pseudo-random values
-- Returns 0 to 1
function Noise.hash3D(x: number, y: number, z: number, seed: number): number
	-- Large prime multipliers for good distribution
	local n = x * 374761393 + y * 668265263 + z * 1274126177 + seed * 1013904223
	n = bit32.bxor(n, bit32.rshift(n, 13))
	n = n * 1274126177
	n = bit32.bxor(n, bit32.rshift(n, 16))
	return (n % 1000000) / 1000000
end

-- Smoothstep interpolation
function Noise.smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

-- 3D value noise with smooth interpolation
-- Returns 0 to 1
function Noise.noise3D(x: number, y: number, z: number, seed: number): number
	local x0 = math.floor(x)
	local y0 = math.floor(y)
	local z0 = math.floor(z)

	local fx = Noise.smoothstep(x - x0)
	local fy = Noise.smoothstep(y - y0)
	local fz = Noise.smoothstep(z - z0)

	-- Sample 8 corners of the unit cube
	local n000 = Noise.hash3D(x0, y0, z0, seed)
	local n100 = Noise.hash3D(x0 + 1, y0, z0, seed)
	local n010 = Noise.hash3D(x0, y0 + 1, z0, seed)
	local n110 = Noise.hash3D(x0 + 1, y0 + 1, z0, seed)
	local n001 = Noise.hash3D(x0, y0, z0 + 1, seed)
	local n101 = Noise.hash3D(x0 + 1, y0, z0 + 1, seed)
	local n011 = Noise.hash3D(x0, y0 + 1, z0 + 1, seed)
	local n111 = Noise.hash3D(x0 + 1, y0 + 1, z0 + 1, seed)

	-- Trilinear interpolation
	local nx00 = n000 + fx * (n100 - n000)
	local nx10 = n010 + fx * (n110 - n010)
	local nx01 = n001 + fx * (n101 - n001)
	local nx11 = n011 + fx * (n111 - n011)

	local nxy0 = nx00 + fy * (nx10 - nx00)
	local nxy1 = nx01 + fy * (nx11 - nx01)

	return nxy0 + fz * (nxy1 - nxy0)
end

-- Fractal Brownian Motion - multiple octaves of noise for more natural look
-- Returns 0 to 1
function Noise.fbm3D(x: number, y: number, z: number, seed: number, octaves: number?): number
	octaves = octaves or 3
	local value = 0
	local amplitude = 1
	local frequency = 1
	local maxValue = 0

	for i = 1, octaves do
		value = value + amplitude * Noise.noise3D(x * frequency, y * frequency, z * frequency, seed + i * 100)
		maxValue = maxValue + amplitude
		amplitude = amplitude * 0.5
		frequency = frequency * 2
	end

	return value / maxValue
end

return Noise

