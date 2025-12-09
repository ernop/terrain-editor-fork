--!strict

local Plugin = script.Parent.Parent.Parent
local OperationHelper = require(script.Parent.OperationHelper)
local Constants = require(Plugin.Src.Util.Constants)

local materialAir = Enum.Material.Air
local materialWater = Enum.Material.Water

-- ============================================================================
-- 3D Noise Functions
-- ============================================================================

-- Hash function for pseudo-random values
local function hash3D(x, y, z, seed)
	-- Large prime multipliers for good distribution
	local n = x * 374761393 + y * 668265263 + z * 1274126177 + seed * 1013904223
	n = bit32.bxor(n, bit32.rshift(n, 13))
	n = n * 1274126177
	n = bit32.bxor(n, bit32.rshift(n, 16))
	return (n % 1000000) / 1000000 -- Returns 0 to 1
end

-- Smoothstep interpolation
local function smoothstep(t)
	return t * t * (3 - 2 * t)
end

-- 3D value noise with smooth interpolation
local function noise3D(x, y, z, seed)
	local x0 = math.floor(x)
	local y0 = math.floor(y)
	local z0 = math.floor(z)

	local fx = smoothstep(x - x0)
	local fy = smoothstep(y - y0)
	local fz = smoothstep(z - z0)

	-- Sample 8 corners of the unit cube
	local n000 = hash3D(x0, y0, z0, seed)
	local n100 = hash3D(x0 + 1, y0, z0, seed)
	local n010 = hash3D(x0, y0 + 1, z0, seed)
	local n110 = hash3D(x0 + 1, y0 + 1, z0, seed)
	local n001 = hash3D(x0, y0, z0 + 1, seed)
	local n101 = hash3D(x0 + 1, y0, z0 + 1, seed)
	local n011 = hash3D(x0, y0 + 1, z0 + 1, seed)
	local n111 = hash3D(x0 + 1, y0 + 1, z0 + 1, seed)

	-- Trilinear interpolation
	local nx00 = n000 + fx * (n100 - n000)
	local nx10 = n010 + fx * (n110 - n010)
	local nx01 = n001 + fx * (n101 - n001)
	local nx11 = n011 + fx * (n111 - n011)

	local nxy0 = nx00 + fy * (nx10 - nx00)
	local nxy1 = nx01 + fy * (nx11 - nx01)

	return nxy0 + fz * (nxy1 - nxy0) -- Returns 0 to 1
end

-- Fractal Brownian Motion - multiple octaves of noise for more natural look
local function fbm3D(x, y, z, seed, octaves)
	octaves = octaves or 3
	local value = 0
	local amplitude = 1
	local frequency = 1
	local maxValue = 0

	for i = 1, octaves do
		value = value + amplitude * noise3D(x * frequency, y * frequency, z * frequency, seed + i * 100)
		maxValue = maxValue + amplitude
		amplitude = amplitude * 0.5
		frequency = frequency * 2
	end

	return value / maxValue -- Normalize to 0-1
end

local function grow(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local strength = options.strength
	local ignoreWater = options.ignoreWater
	local cellMaterial = options.cellMaterial
	local desiredMaterial = options.desiredMaterial
	local maxOccupancy = options.maxOccupancy
	local autoMaterial = options.autoMaterial

	if cellOccupancy == 1 or brushOccupancy < 0.5 then
		return
	end

	local desiredOccupancy = cellOccupancy
	local fullNeighbor = false
	local totalNeighbors = 0
	local neighborOccupancies = 0
	for i = 1, 6, 1 do
		local nx = voxelX + OperationHelper.xOffset[i]
		local ny = voxelY + OperationHelper.yOffset[i]
		local nz = voxelZ + OperationHelper.zOffset[i]
		if nx > 0 and nx <= sizeX and ny > 0 and ny <= sizeY and nz > 0 and nz <= sizeZ then
			local neighbor = readOccupancies[nx][ny][nz]
			local neighborMaterial = readMaterials[nx][ny][nz]

			if ignoreWater and neighborMaterial == materialWater then
				neighbor = 0
			end

			if neighbor >= 1 then
				fullNeighbor = true
			end

			totalNeighbors = totalNeighbors + 1
			neighborOccupancies = neighborOccupancies + neighbor
		end
	end

	if cellOccupancy > 0 or fullNeighbor then
		neighborOccupancies = totalNeighbors == 0 and 0 or neighborOccupancies / totalNeighbors
		desiredOccupancy = desiredOccupancy + neighborOccupancies * (strength + 0.1) * 0.25 * brushOccupancy * magnitudePercent
	end

	desiredOccupancy = math.min(desiredOccupancy, maxOccupancy)

	if cellMaterial == materialAir and desiredOccupancy > 0 then
		local targetMaterial = desiredMaterial
		if autoMaterial then
			targetMaterial =
				OperationHelper.getMaterialForAutoMaterial(readMaterials, voxelX, voxelY, voxelZ, sizeX, sizeY, sizeZ, cellMaterial)
		end
		writeMaterials[voxelX][voxelY][voxelZ] = targetMaterial
	end

	if desiredOccupancy ~= cellOccupancy then
		writeOccupancies[voxelX][voxelY][voxelZ] = desiredOccupancy
	end
end

local function erode(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local strength = options.strength
	local ignoreWater = options.ignoreWater
	local airFillerMaterial = options.airFillerMaterial
	local maxOccupancy = options.maxOccupancy

	if cellOccupancy == 0 or brushOccupancy <= 0.5 then
		return
	end

	local desiredOccupancy = cellOccupancy
	local emptyNeighbor = false
	local neighborOccupancies = 6
	for i = 1, 6, 1 do
		local nx = voxelX + OperationHelper.xOffset[i]
		local ny = voxelY + OperationHelper.yOffset[i]
		local nz = voxelZ + OperationHelper.zOffset[i]
		if nx > 0 and nx <= sizeX and ny > 0 and ny <= sizeY and nz > 0 and nz <= sizeZ then
			local neighbor = readOccupancies[nx][ny][nz]
			local neighborMaterial = readMaterials[nx][ny][nz]

			if ignoreWater and neighborMaterial == materialWater then
				neighbor = 0
			end

			if neighbor <= 0 then
				emptyNeighbor = true
			end

			neighborOccupancies = neighborOccupancies - neighbor
		end
	end

	if cellOccupancy < 1 or emptyNeighbor then
		desiredOccupancy = desiredOccupancy - (neighborOccupancies / 6) * (strength + 0.1) * 0.25 * brushOccupancy * magnitudePercent
	end

	desiredOccupancy = math.min(desiredOccupancy, maxOccupancy)

	if desiredOccupancy <= OperationHelper.one256th then
		writeOccupancies[voxelX][voxelY][voxelZ] = airFillerMaterial == materialWater and 1 or 0
		writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
	else
		writeOccupancies[voxelX][voxelY][voxelZ] = desiredOccupancy
	end
end

local function smooth(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local filterSize = options.filterSize
	local airFillerMaterial = options.airFillerMaterial
	local ignoreWater = options.ignoreWater

	-- Needs to be <= 2. The radius = 1 so the brushes real size is 2
	if sizeX <= 2 or sizeZ <= 2 or sizeY <= 2 then
		return
	end

	if brushOccupancy < 0.5 then
		return
	end

	local neighbourOccupanciesSum = 0
	local totalNeighbours = 0
	local hasFullNeighbour = false
	local hasEmptyNeighbour = false

	local cellStartMaterial = readMaterials[voxelX][voxelY][voxelZ]
	local cellStartsEmpty = cellStartMaterial == materialAir or cellOccupancy <= 0

	for xo = -filterSize, filterSize, filterSize do
		for yo = -filterSize, filterSize, filterSize do
			for zo = -filterSize, filterSize, filterSize do
				local checkX = voxelX + xo
				local checkY = voxelY + yo
				local checkZ = voxelZ + zo

				if checkX > 0 and checkX <= sizeX and checkY > 0 and checkY <= sizeY and checkZ > 0 and checkZ <= sizeZ then
					local occupancy = readOccupancies[checkX][checkY][checkZ]
					local distanceScale = 1 - (math.sqrt(xo * xo + yo * yo + zo * zo) / (filterSize * 2))

					local neighborMaterial = readMaterials[checkX][checkY][checkZ]
					if ignoreWater and neighborMaterial == materialWater then
						occupancy = 0
					end

					if occupancy >= 1 then
						hasFullNeighbour = true
					end

					if occupancy <= 0 then
						hasEmptyNeighbour = true
					end

					-- This is very important. It allows cells to fully diminish or fully fill by lying to the algorithm
					occupancy = occupancy * 1.5 - 0.25

					totalNeighbours = totalNeighbours + 1 * distanceScale
					neighbourOccupanciesSum = neighbourOccupanciesSum + occupancy * distanceScale
				end
			end
		end
	end

	local neighbourOccupancies = neighbourOccupanciesSum / (totalNeighbours > 0 and totalNeighbours or (cellOccupancy * 1.5 - 0.25))

	local difference = (neighbourOccupancies - cellOccupancy) * (strength + 0.1) * 0.5 * brushOccupancy * magnitudePercent

	if not hasFullNeighbour and difference > 0 then
		difference = 0
	elseif not hasEmptyNeighbour and difference < 0 then
		difference = 0
	end

	-- If this voxel won't be be changing occupancy, then we don't need to try to change its occupancy or material
	local targetOccupancy = math.max(0, math.min(1, cellOccupancy + difference))
	if targetOccupancy ~= cellOccupancy then
		if cellStartsEmpty and targetOccupancy > 0 then
			-- Cell is becoming non-empty so give it a material
			writeMaterials[voxelX][voxelY][voxelZ] =
				OperationHelper.getMaterialForAutoMaterial(readMaterials, voxelX, voxelY, voxelZ, sizeX, sizeY, sizeZ, cellMaterial)
		elseif targetOccupancy <= 0 then
			writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
		end
		-- Else oldOccupancy > 0 and targetOccupancy > 0, leave its material unchanged

		writeOccupancies[voxelX][voxelY][voxelZ] = targetOccupancy
	end
end

-- ============================================================================
-- Noise Tool
-- Adds procedural displacement to terrain surfaces (opposite of smooth)
-- ============================================================================
local function noise(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local airFillerMaterial = options.airFillerMaterial
	local ignoreWater = options.ignoreWater

	-- Noise-specific parameters
	local worldX = options.worldX or 0
	local worldY = options.worldY or 0
	local worldZ = options.worldZ or 0
	local noiseScale = options.noiseScale or 4
	local noiseIntensity = options.noiseIntensity or 0.5
	local noiseSeed = options.noiseSeed or 0

	-- Skip if brush influence is too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Determine if this voxel is near a surface
	-- Surface voxels are: partially filled OR have an empty neighbor
	local isSurface = cellOccupancy > 0.05 and cellOccupancy < 0.95

	if not isSurface and cellOccupancy > 0 then
		-- Check if any neighbor is empty (air)
		for i = 1, 6 do
			local nx = voxelX + OperationHelper.xOffset[i]
			local ny = voxelY + OperationHelper.yOffset[i]
			local nz = voxelZ + OperationHelper.zOffset[i]

			if nx > 0 and nx <= sizeX and ny > 0 and ny <= sizeY and nz > 0 and nz <= sizeZ then
				local neighborOcc = readOccupancies[nx][ny][nz]
				local neighborMat = readMaterials[nx][ny][nz]

				if ignoreWater and neighborMat == materialWater then
					neighborOcc = 0
				end

				if neighborOcc < 0.5 then
					isSurface = true
					break
				end
			end
		end
	end

	-- Only affect surface voxels - don't roughen deep solid or deep air
	if not isSurface then
		return
	end

	-- Generate noise value at this world position
	-- Scale coordinates by noiseScale (larger scale = chunkier noise)
	local noiseCoordX = worldX / noiseScale
	local noiseCoordY = worldY / noiseScale
	local noiseCoordZ = worldZ / noiseScale

	-- Use fractal noise for more natural appearance (3 octaves)
	local noiseValue = fbm3D(noiseCoordX, noiseCoordY, noiseCoordZ, noiseSeed, 3)

	-- Convert from 0-1 to -1 to +1 range
	noiseValue = noiseValue * 2 - 1

	-- Calculate displacement
	-- Factors: noise value, intensity, strength, brush falloff
	local displacement = noiseValue * noiseIntensity * (strength + 0.1) * 0.5 * brushOccupancy * magnitudePercent

	-- Apply displacement to occupancy
	local newOccupancy = math.clamp(cellOccupancy + displacement, 0, 1)

	-- Only write if there's a meaningful change
	if math.abs(newOccupancy - cellOccupancy) > 0.01 then
		writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy

		-- Handle material transitions
		if newOccupancy <= OperationHelper.one256th then
			-- Became air
			writeOccupancies[voxelX][voxelY][voxelZ] = airFillerMaterial == materialWater and 1 or 0
			writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
		elseif cellMaterial == materialAir and newOccupancy > 0 then
			-- Was air, now has material - inherit from neighbors
			writeMaterials[voxelX][voxelY][voxelZ] =
				OperationHelper.getMaterialForAutoMaterial(readMaterials, voxelX, voxelY, voxelZ, sizeX, sizeY, sizeZ, cellMaterial)
		end
	end
end

-- ============================================================================
-- Terrace Tool
-- Creates horizontal stepped layers (stairs/terraces)
-- ============================================================================
local function terrace(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local airFillerMaterial = options.airFillerMaterial

	-- Terrace-specific parameters
	local worldY = options.worldY or 0
	local stepHeight = options.stepHeight or 8 -- Height of each step in studs
	local stepSharpness = options.stepSharpness or 0.8 -- 0-1, how sharp the edges are

	-- Skip if brush influence is too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Determine if this voxel is near a surface
	local isSurface = cellOccupancy > 0.05 and cellOccupancy < 0.95

	if not isSurface and cellOccupancy > 0 then
		-- Check if any neighbor is empty
		for i = 1, 6 do
			local nx = voxelX + OperationHelper.xOffset[i]
			local ny = voxelY + OperationHelper.yOffset[i]
			local nz = voxelZ + OperationHelper.zOffset[i]

			if nx > 0 and nx <= sizeX and ny > 0 and ny <= sizeY and nz > 0 and nz <= sizeZ then
				if readOccupancies[nx][ny][nz] < 0.5 then
					isSurface = true
					break
				end
			end
		end
	end

	-- Only affect surface voxels
	if not isSurface then
		return
	end

	-- Calculate which step this Y coordinate belongs to
	-- Steps are aligned to world coordinates (not brush center)
	local stepIndex = math.floor(worldY / stepHeight)
	local stepBase = stepIndex * stepHeight
	local heightInStep = worldY - stepBase
	local stepProgress = heightInStep / stepHeight -- 0 at step base, 1 at top

	-- Determine target occupancy based on position within step
	-- riserZone: the vertical portion of the step (where we want a wall)
	-- treadZone: the horizontal portion (where we want flat ground)
	local riserWidth = (1 - stepSharpness) * 0.5 + 0.1 -- 0.1 to 0.6 of step height

	local targetOccupancy
	if stepProgress < riserWidth then
		-- In the riser (vertical wall portion)
		-- Transition from solid at bottom to air at top of riser
		targetOccupancy = 1 - (stepProgress / riserWidth)
	else
		-- In the tread (horizontal flat portion) - should be solid
		targetOccupancy = 1
	end

	-- Blend toward target based on strength and brush
	local blendFactor = (strength + 0.1) * 0.3 * brushOccupancy * magnitudePercent
	local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor
	newOccupancy = math.clamp(newOccupancy, 0, 1)

	-- Only write if there's a meaningful change
	if math.abs(newOccupancy - cellOccupancy) > 0.01 then
		writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy

		-- Handle material transitions
		if newOccupancy <= OperationHelper.one256th then
			writeOccupancies[voxelX][voxelY][voxelZ] = airFillerMaterial == materialWater and 1 or 0
			writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
		elseif cellMaterial == materialAir and newOccupancy > 0 then
			writeMaterials[voxelX][voxelY][voxelZ] =
				OperationHelper.getMaterialForAutoMaterial(readMaterials, voxelX, voxelY, voxelZ, sizeX, sizeY, sizeZ, cellMaterial)
		end
	end
end

-- ============================================================================
-- Cliff Tool
-- Forces terrain toward vertical (or steep-angle) faces
-- ============================================================================
local function cliff(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local airFillerMaterial = options.airFillerMaterial

	-- Cliff-specific parameters
	local cellVectorX = options.cellVectorX or 0 -- Offset from brush center
	local cellVectorZ = options.cellVectorZ or 0
	local cliffDirectionX = options.cliffDirectionX or 1 -- Cliff face normal direction (horizontal)
	local cliffDirectionZ = options.cliffDirectionZ or 0
	local cliffAngle = options.cliffAngle or 90 -- Target angle in degrees (90 = vertical)

	-- Skip if brush influence is too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Determine if this voxel is near a surface
	local isSurface = cellOccupancy > 0.05 and cellOccupancy < 0.95

	if not isSurface and cellOccupancy > 0 then
		for i = 1, 6 do
			local nx = voxelX + OperationHelper.xOffset[i]
			local ny = voxelY + OperationHelper.yOffset[i]
			local nz = voxelZ + OperationHelper.zOffset[i]

			if nx > 0 and nx <= sizeX and ny > 0 and ny <= sizeY and nz > 0 and nz <= sizeZ then
				if readOccupancies[nx][ny][nz] < 0.5 then
					isSurface = true
					break
				end
			end
		end
	end

	-- Only affect surface voxels
	if not isSurface then
		return
	end

	-- Calculate distance from cliff plane (plane passes through brush center)
	-- The cliff plane normal is the cliff direction (horizontal)
	-- Positive distance = in front of cliff (should be air)
	-- Negative distance = behind cliff (should be solid)
	local distFromPlane = cellVectorX * cliffDirectionX + cellVectorZ * cliffDirectionZ

	-- Width of the transition zone (in studs)
	-- Steeper angles = narrower transition
	local angleRadians = math.rad(cliffAngle)
	local transitionWidth = 4 / math.tan(math.max(angleRadians, 0.1)) -- Avoid division by zero
	transitionWidth = math.clamp(transitionWidth, 1, 8) -- Keep reasonable bounds

	local targetOccupancy
	if distFromPlane < -transitionWidth then
		-- Far behind the cliff plane - should be solid
		targetOccupancy = 1
	elseif distFromPlane > transitionWidth then
		-- Far in front of cliff plane - should be air
		targetOccupancy = 0
	else
		-- In transition zone - smooth gradient
		-- Map from [-transitionWidth, transitionWidth] to [1, 0]
		targetOccupancy = 0.5 - (distFromPlane / (transitionWidth * 2))
		targetOccupancy = math.clamp(targetOccupancy, 0, 1)
	end

	-- Blend toward target based on strength and brush
	local blendFactor = (strength + 0.1) * 0.4 * brushOccupancy * magnitudePercent
	local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor
	newOccupancy = math.clamp(newOccupancy, 0, 1)

	-- Only write if there's a meaningful change
	if math.abs(newOccupancy - cellOccupancy) > 0.01 then
		writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy

		-- Handle material transitions
		if newOccupancy <= OperationHelper.one256th then
			writeOccupancies[voxelX][voxelY][voxelZ] = airFillerMaterial == materialWater and 1 or 0
			writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
		elseif cellMaterial == materialAir and newOccupancy > 0 then
			writeMaterials[voxelX][voxelY][voxelZ] =
				OperationHelper.getMaterialForAutoMaterial(readMaterials, voxelX, voxelY, voxelZ, sizeX, sizeY, sizeZ, cellMaterial)
		end
	end
end

-- ============================================================================
-- Path Tool
-- Carves directional channels through terrain
-- ============================================================================
local function path(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local airFillerMaterial = options.airFillerMaterial

	-- Path-specific parameters
	local cellVectorX = options.cellVectorX or 0
	local cellVectorZ = options.cellVectorZ or 0
	local worldY = options.worldY or 0
	local centerY = options.centerY or 0
	local pathDirectionX = options.pathDirectionX or 0
	local pathDirectionZ = options.pathDirectionZ or 1
	local pathDepth = options.pathDepth or 6
	local pathProfile = options.pathProfile or "U"
	local pathWidth = options.pathWidth or 4

	-- Skip if brush influence is too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Calculate perpendicular distance from path centerline
	local perpX = -pathDirectionZ
	local perpZ = pathDirectionX
	local perpDist = math.abs(cellVectorX * perpX + cellVectorZ * perpZ)
	local normalizedPerp = perpDist / pathWidth

	if normalizedPerp > 1 then
		return -- Outside the path width
	end

	-- Calculate target depth based on profile
	local depthAtPosition
	if pathProfile == "V" then
		-- V-shape: deepest at center, rises linearly to edges
		depthAtPosition = pathDepth * (1 - normalizedPerp)
	elseif pathProfile == "U" then
		-- U-shape: flat bottom (60% width), then rises at edges
		local flatPortion = 0.6
		if normalizedPerp < flatPortion then
			depthAtPosition = pathDepth
		else
			local edgeProgress = (normalizedPerp - flatPortion) / (1 - flatPortion)
			depthAtPosition = pathDepth * (1 - edgeProgress)
		end
	else -- Flat
		-- Flat: full depth with steep walls
		depthAtPosition = pathDepth
	end

	-- The path "floor" is at (center Y - depthAtPosition)
	local floorY = centerY - depthAtPosition
	local targetOccupancy = cellOccupancy

	if worldY > floorY then
		-- Above the floor - should be air (erode)
		local distAboveFloor = worldY - floorY
		if distAboveFloor < Constants.VOXEL_RESOLUTION then
			targetOccupancy = math.max(0, 1 - (distAboveFloor / Constants.VOXEL_RESOLUTION))
		else
			targetOccupancy = 0
		end
	end

	-- Only erode, never add
	if targetOccupancy < cellOccupancy then
		local blendFactor = (strength + 0.1) * 0.5 * brushOccupancy * magnitudePercent
		local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor
		newOccupancy = math.clamp(newOccupancy, 0, 1)

		if math.abs(newOccupancy - cellOccupancy) > 0.01 then
			if newOccupancy <= OperationHelper.one256th then
				writeOccupancies[voxelX][voxelY][voxelZ] = airFillerMaterial == materialWater and 1 or 0
				writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
			else
				writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy
				if cellMaterial == materialAir and newOccupancy > 0 then
					writeMaterials[voxelX][voxelY][voxelZ] =
						OperationHelper.getMaterialForAutoMaterial(readMaterials, voxelX, voxelY, voxelZ, sizeX, sizeY, sizeZ, cellMaterial)
				end
			end
		end
	end
end

-- ============================================================================
-- Clone Tool
-- Copies terrain from source to target location
-- ============================================================================
local function clone(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local airFillerMaterial = options.airFillerMaterial

	-- Clone-specific parameters
	local sourceBuffer = options.sourceBuffer -- { [x][y][z] = {occupancy, material} }
	local sourceCenterX = options.sourceCenterX or 0
	local sourceCenterY = options.sourceCenterY or 0
	local sourceCenterZ = options.sourceCenterZ or 0
	local targetCenterX = options.targetCenterX or 0
	local targetCenterY = options.targetCenterY or 0
	local targetCenterZ = options.targetCenterZ or 0

	-- Skip if no source buffer or brush influence is too weak
	if not sourceBuffer or brushOccupancy < 0.5 then
		return
	end

	-- Calculate offset from target center to this voxel
	local offsetX = voxelX - targetCenterX
	local offsetY = voxelY - targetCenterY
	local offsetZ = voxelZ - targetCenterZ

	-- Look up corresponding source voxel
	local sourceX = sourceCenterX + offsetX
	local sourceY = sourceCenterY + offsetY
	local sourceZ = sourceCenterZ + offsetZ

	-- Check if source voxel exists in buffer
	if not sourceBuffer[sourceX] or not sourceBuffer[sourceX][sourceY] or not sourceBuffer[sourceX][sourceY][sourceZ] then
		return
	end

	local sourceData = sourceBuffer[sourceX][sourceY][sourceZ]
	local sourceOccupancy = sourceData.occupancy
	local sourceMaterial = sourceData.material

	-- Blend toward source
	local blendFactor = (strength + 0.1) * 0.6 * brushOccupancy * magnitudePercent
	local newOccupancy = cellOccupancy + (sourceOccupancy - cellOccupancy) * blendFactor
	newOccupancy = math.clamp(newOccupancy, 0, 1)

	if math.abs(newOccupancy - cellOccupancy) > 0.01 then
		writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy

		-- Handle material transitions
		if newOccupancy <= OperationHelper.one256th then
			writeOccupancies[voxelX][voxelY][voxelZ] = airFillerMaterial == materialWater and 1 or 0
			writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
		else
			-- Blend material toward source material
			if sourceMaterial ~= materialAir then
				writeMaterials[voxelX][voxelY][voxelZ] = sourceMaterial
			elseif cellMaterial == materialAir and newOccupancy > 0 then
				writeMaterials[voxelX][voxelY][voxelZ] =
					OperationHelper.getMaterialForAutoMaterial(readMaterials, voxelX, voxelY, voxelZ, sizeX, sizeY, sizeZ, cellMaterial)
			end
		end
	end
end

-- ============================================================================
-- Blobify Tool
-- Creates organic blob-like protrusions
-- ============================================================================
local function blobify(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local airFillerMaterial = options.airFillerMaterial

	-- Blobify-specific parameters
	local blobIntensity = options.blobIntensity or 0.5
	local blobSmoothness = options.blobSmoothness or 0.7

	-- Skip if brush influence is too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Calculate distance from brush center (normalized)
	local distFromCenter = math.sqrt((options.cellVectorX or 0) ^ 2 + (options.cellVectorY or 0) ^ 2 + (options.cellVectorZ or 0) ^ 2)
	local maxDist = math.max(sizeX, sizeY, sizeZ) * 0.5
	local normalizedDist = math.min(distFromCenter / maxDist, 1)

	-- Create blob profile: smooth falloff from center
	-- Uses smoothstep for organic feel
	local smoothDist = normalizedDist * normalizedDist * (3 - 2 * normalizedDist)
	local blobProfile = 1 - smoothDist

	-- Apply blob intensity and smoothness
	local blobAmount = blobProfile * blobIntensity * blobSmoothness

	-- Only add material (grow), never remove
	local targetOccupancy = math.min(1, cellOccupancy + blobAmount)

	if targetOccupancy > cellOccupancy then
		local blendFactor = (strength + 0.1) * 0.4 * brushOccupancy * magnitudePercent
		local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor
		newOccupancy = math.clamp(newOccupancy, 0, 1)

		if math.abs(newOccupancy - cellOccupancy) > 0.01 then
			writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy

			-- Handle material transitions
			if cellMaterial == materialAir and newOccupancy > 0 then
				writeMaterials[voxelX][voxelY][voxelZ] =
					OperationHelper.getMaterialForAutoMaterial(readMaterials, voxelX, voxelY, voxelZ, sizeX, sizeY, sizeZ, cellMaterial)
			end
		end
	end
end

-- ============================================================================
-- Slope Paint Tool
-- Automatically assigns materials based on terrain surface angle
-- ============================================================================
local function slopePaint(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local ignoreWater = options.ignoreWater

	-- Slope paint-specific parameters
	local slopeFlatMaterial = options.slopeFlatMaterial or Enum.Material.Grass
	local slopeSteepMaterial = options.slopeSteepMaterial or Enum.Material.Rock
	local slopeCliffMaterial = options.slopeCliffMaterial or Enum.Material.Slate
	local slopeThreshold1 = options.slopeThreshold1 or 30 -- Degrees: flat → steep
	local slopeThreshold2 = options.slopeThreshold2 or 60 -- Degrees: steep → cliff

	-- Skip if brush influence is too weak or cell is empty
	if brushOccupancy < 0.5 or cellOccupancy <= 0 then
		return
	end

	-- Calculate surface normal from occupancy gradients
	-- Using central differences for more accurate gradient estimation
	local gradX = 0
	local gradY = 0
	local gradZ = 0

	-- X gradient
	if voxelX > 1 and voxelX < sizeX then
		local occXMinus = readOccupancies[voxelX - 1][voxelY][voxelZ]
		local occXPlus = readOccupancies[voxelX + 1][voxelY][voxelZ]
		if ignoreWater then
			if readMaterials[voxelX - 1][voxelY][voxelZ] == materialWater then
				occXMinus = 0
			end
			if readMaterials[voxelX + 1][voxelY][voxelZ] == materialWater then
				occXPlus = 0
			end
		end
		gradX = occXPlus - occXMinus
	end

	-- Y gradient
	if voxelY > 1 and voxelY < sizeY then
		local occYMinus = readOccupancies[voxelX][voxelY - 1][voxelZ]
		local occYPlus = readOccupancies[voxelX][voxelY + 1][voxelZ]
		if ignoreWater then
			if readMaterials[voxelX][voxelY - 1][voxelZ] == materialWater then
				occYMinus = 0
			end
			if readMaterials[voxelX][voxelY + 1][voxelZ] == materialWater then
				occYPlus = 0
			end
		end
		gradY = occYPlus - occYMinus
	end

	-- Z gradient
	if voxelZ > 1 and voxelZ < sizeZ then
		local occZMinus = readOccupancies[voxelX][voxelY][voxelZ - 1]
		local occZPlus = readOccupancies[voxelX][voxelY][voxelZ + 1]
		if ignoreWater then
			if readMaterials[voxelX][voxelY][voxelZ - 1] == materialWater then
				occZMinus = 0
			end
			if readMaterials[voxelX][voxelY][voxelZ + 1] == materialWater then
				occZPlus = 0
			end
		end
		gradZ = occZPlus - occZMinus
	end

	-- Calculate magnitude and normalize
	local gradMag = math.sqrt(gradX * gradX + gradY * gradY + gradZ * gradZ)

	-- Skip if no gradient (completely flat or uniform)
	if gradMag < 0.001 then
		-- Default to flat material for uniform regions
		writeMaterials[voxelX][voxelY][voxelZ] = slopeFlatMaterial
		return
	end

	-- Surface normal points in direction of gradient (from solid toward air)
	local normalY = gradY / gradMag

	-- Calculate angle from vertical (Y axis)
	-- Perfectly flat surface has normal pointing straight up (normalY = 1, angle = 0)
	-- Vertical cliff has normal pointing sideways (normalY = 0, angle = 90)
	local slopeAngle = math.deg(math.acos(math.abs(normalY)))

	-- Select material based on slope angle
	local material
	if slopeAngle < slopeThreshold1 then
		material = slopeFlatMaterial
	elseif slopeAngle < slopeThreshold2 then
		material = slopeSteepMaterial
	else
		material = slopeCliffMaterial
	end

	writeMaterials[voxelX][voxelY][voxelZ] = material
end

-- ============================================================================
-- Megarandomize Tool (Paint Megarandomizer)
-- Applies multiple materials with weighted randomness
-- ============================================================================
local function megarandomize(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy

	-- Megarandomize-specific parameters
	local worldX = options.worldX or 0
	local worldY = options.worldY or 0
	local worldZ = options.worldZ or 0
	local clusterSize = options.clusterSize or 4
	local noiseSeed = options.noiseSeed or 0
	local materialPalette = options.materialPalette
		or {
			{ material = Enum.Material.Grass, weight = 0.6 },
			{ material = Enum.Material.Rock, weight = 0.25 },
			{ material = Enum.Material.Ground, weight = 0.15 },
		}

	-- Skip if brush influence is too weak or cell is empty
	if brushOccupancy < 0.5 or cellOccupancy <= 0 then
		return
	end

	-- Generate clustered noise value at this world position
	local noiseX = worldX / clusterSize
	local noiseZ = worldZ / clusterSize
	local noiseValue = fbm3D(noiseX, worldY / clusterSize, noiseZ, noiseSeed, 2)

	-- Normalize weights and select material based on noise
	local totalWeight = 0
	for _, entry in ipairs(materialPalette) do
		totalWeight = totalWeight + entry.weight
	end

	local cumulative = 0
	local selectedMaterial = materialPalette[1].material
	for _, entry in ipairs(materialPalette) do
		cumulative = cumulative + (entry.weight / totalWeight)
		if noiseValue < cumulative then
			selectedMaterial = entry.material
			break
		end
	end

	writeMaterials[voxelX][voxelY][voxelZ] = selectedMaterial
end

-- ============================================================================
-- Cavity Fill Tool
-- Intelligently detects and fills terrain depressions/holes
-- ============================================================================
local function cavityFill(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local ignoreWater = options.ignoreWater

	-- Cavity fill-specific parameters
	local cavitySensitivity = options.cavitySensitivity or 0.3

	-- Skip if brush influence is too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Detect if this voxel is in a depression (neighbors are higher/more filled)
	local avgNeighborOccupancy = 0
	local maxNeighborOccupancy = 0
	local count = 0

	-- Check 3x3x3 neighborhood
	for dx = -1, 1 do
		for dy = 0, 2 do -- Focus on same level and above
			for dz = -1, 1 do
				if not (dx == 0 and dy == 0 and dz == 0) then
					local nx = voxelX + dx
					local ny = voxelY + dy
					local nz = voxelZ + dz

					if nx > 0 and nx <= sizeX and ny > 0 and ny <= sizeY and nz > 0 and nz <= sizeZ then
						local neighborOcc = readOccupancies[nx][ny][nz]
						local neighborMat = readMaterials[nx][ny][nz]

						if ignoreWater and neighborMat == materialWater then
							neighborOcc = 0
						end

						avgNeighborOccupancy = avgNeighborOccupancy + neighborOcc
						maxNeighborOccupancy = math.max(maxNeighborOccupancy, neighborOcc)
						count = count + 1
					end
				end
			end
		end
	end

	if count > 0 then
		avgNeighborOccupancy = avgNeighborOccupancy / count
	end

	-- Calculate deficit (how much lower this cell is than surroundings)
	local deficit = avgNeighborOccupancy - cellOccupancy

	-- Only fill if deficit exceeds sensitivity threshold
	if deficit > cavitySensitivity then
		local fillAmount = deficit * strength * 0.5 * brushOccupancy * magnitudePercent
		local newOccupancy = math.min(1, cellOccupancy + fillAmount)

		if math.abs(newOccupancy - cellOccupancy) > 0.01 then
			writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy

			-- If was air and now has occupancy, assign material from neighbors
			if cellMaterial == materialAir and newOccupancy > 0 then
				writeMaterials[voxelX][voxelY][voxelZ] =
					OperationHelper.getMaterialForAutoMaterial(readMaterials, voxelX, voxelY, voxelZ, sizeX, sizeY, sizeZ, cellMaterial)
			end
		end
	end
end

-- ============================================================================
-- Melt Tool
-- Simulates terrain softening and flowing downward under gravity
-- ============================================================================
local function melt(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local airFillerMaterial = options.airFillerMaterial

	-- Melt-specific parameters
	local meltViscosity = options.meltViscosity or 0.5 -- 0=runny, 1=thick

	-- Skip if brush influence is too weak or cell is empty
	if brushOccupancy < 0.5 or cellOccupancy <= 0 then
		return
	end

	-- Check if cell below exists and has room for more material
	if voxelY <= 1 then
		return
	end

	local belowOcc = readOccupancies[voxelX][voxelY - 1][voxelZ]
	local belowMat = readMaterials[voxelX][voxelY - 1][voxelZ]

	-- Can flow if cell below is not completely full
	local canFlow = belowOcc < 0.99

	if canFlow then
		-- Flow amount depends on: occupancy, strength, viscosity, brush influence
		local flowRate = (1 - meltViscosity) * 0.3 -- Lower viscosity = faster flow
		local flowAmount = cellOccupancy * strength * flowRate * brushOccupancy * magnitudePercent
		flowAmount = math.min(flowAmount, cellOccupancy) -- Can't flow more than we have
		flowAmount = math.min(flowAmount, 1 - belowOcc) -- Can't overflow the cell below

		if flowAmount > 0.01 then
			-- Remove from current cell
			local newOccupancy = cellOccupancy - flowAmount
			writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy

			-- Add to cell below
			writeOccupancies[voxelX][voxelY - 1][voxelZ] = belowOcc + flowAmount

			-- Transfer material if cell below was air
			if belowMat == materialAir then
				writeMaterials[voxelX][voxelY - 1][voxelZ] = cellMaterial
			end

			-- Handle current cell becoming air
			if newOccupancy <= OperationHelper.one256th then
				writeOccupancies[voxelX][voxelY][voxelZ] = airFillerMaterial == materialWater and 1 or 0
				writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
			end
		end
	end
end

-- ============================================================================
-- Gradient Paint Tool
-- Creates smooth material transitions between two points
-- ============================================================================
local function gradientPaint(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy

	-- Gradient-specific parameters
	local worldX = options.worldX or 0
	local worldY = options.worldY or 0
	local worldZ = options.worldZ or 0
	local gradientMaterial1 = options.gradientMaterial1 or Enum.Material.Grass
	local gradientMaterial2 = options.gradientMaterial2 or Enum.Material.Rock
	local gradientStartX = options.gradientStartX or 0
	local gradientStartZ = options.gradientStartZ or 0
	local gradientEndX = options.gradientEndX or 100
	local gradientEndZ = options.gradientEndZ or 0
	local gradientNoiseAmount = options.gradientNoiseAmount or 0.1
	local noiseSeed = options.noiseSeed or 0

	-- Skip if brush influence is too weak or cell is empty
	if brushOccupancy < 0.5 or cellOccupancy <= 0 then
		return
	end

	-- Calculate gradient direction and length
	local dirX = gradientEndX - gradientStartX
	local dirZ = gradientEndZ - gradientStartZ
	local gradientLength = math.sqrt(dirX * dirX + dirZ * dirZ)

	if gradientLength < 1 then
		gradientLength = 1
	end

	-- Normalize direction
	dirX = dirX / gradientLength
	dirZ = dirZ / gradientLength

	-- Calculate position along gradient (0 = start, 1 = end)
	local relX = worldX - gradientStartX
	local relZ = worldZ - gradientStartZ
	local t = (relX * dirX + relZ * dirZ) / gradientLength

	-- Add noise for organic edge
	if gradientNoiseAmount > 0 then
		local noiseVal = noise3D(worldX / 8, worldY / 8, worldZ / 8, noiseSeed)
		t = t + (noiseVal - 0.5) * gradientNoiseAmount
	end

	-- Clamp t to 0-1 range
	t = math.clamp(t, 0, 1)

	-- Select material based on position
	local material = t < 0.5 and gradientMaterial1 or gradientMaterial2

	writeMaterials[voxelX][voxelY][voxelZ] = material
end

-- ============================================================================
-- Flood Paint Tool
-- Surface-aware flood fill for material replacement
-- This is a special tool that operates on connected regions
-- ============================================================================
local function floodPaint(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial

	-- Flood paint specific parameters
	local floodTargetMaterial = options.floodTargetMaterial or Enum.Material.Grass
	local floodSourceMaterial = options.floodSourceMaterial -- nil = any non-air

	-- Skip if brush influence is too weak or cell is empty
	if brushOccupancy < 0.5 or cellOccupancy <= 0 then
		return
	end

	-- If source material is specified, only paint matching materials
	if floodSourceMaterial then
		if cellMaterial ~= floodSourceMaterial then
			return
		end
	else
		-- Skip air
		if cellMaterial == materialAir then
			return
		end
	end

	-- Apply the new material
	writeMaterials[voxelX][voxelY][voxelZ] = floodTargetMaterial
end

-- ============================================================================
-- Stalactite Generator Tool
-- Creates hanging spike-like formations (stalactites/stalagmites)
-- ============================================================================
local function stalactite(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local airFillerMaterial = options.airFillerMaterial

	-- Stalactite-specific parameters
	local worldX = options.worldX or 0
	local worldY = options.worldY or 0
	local worldZ = options.worldZ or 0
	local centerX = options.centerX or 0
	local centerY = options.centerY or 0
	local centerZ = options.centerZ or 0
	local stalactiteDirection = options.stalactiteDirection or -1 -- -1 = down, 1 = up
	local stalactiteDensity = options.stalactiteDensity or 0.3
	local stalactiteLength = options.stalactiteLength or 10
	local stalactiteTaper = options.stalactiteTaper or 0.8
	local noiseSeed = options.noiseSeed or 0
	local desiredMaterial = options.desiredMaterial or Enum.Material.Rock

	-- Skip if brush influence is too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Horizontal distance from brush center (in local coords)
	local localX = worldX - centerX
	local localZ = worldZ - centerZ
	local horizontalDist = math.sqrt(localX * localX + localZ * localZ)

	-- Noise for stalactite placement density
	local noiseVal = hash3D(math.floor(worldX / 4), 0, math.floor(worldZ / 4), noiseSeed)

	-- Only create stalactite columns where noise exceeds density threshold
	if noiseVal > stalactiteDensity then
		return
	end

	-- Calculate stalactite length variation based on position noise
	local lengthNoise = hash3D(math.floor(worldX / 4), 1, math.floor(worldZ / 4), noiseSeed + 1)
	local thisLength = stalactiteLength * (0.4 + lengthNoise * 0.6)

	-- Vertical distance from brush center
	local localY = (worldY - centerY) * stalactiteDirection -- Flip if going up

	-- Only affect voxels below (or above for stalagmites) the brush center
	if localY > 0 then
		return -- Above brush center when pointing down (or vice versa)
	end

	local distanceDown = -localY -- Convert to positive distance from surface

	-- Check if within stalactite length
	if distanceDown > thisLength then
		return
	end

	-- Calculate radius at this height (tapers from base to tip)
	local t = distanceDown / thisLength -- 0 at base, 1 at tip
	local radiusAtHeight = (1 - t * stalactiteTaper) * 2 -- Base radius ~2 studs

	-- Add some wobble/variation to the column position
	local wobbleX = (hash3D(math.floor(worldZ / 2), math.floor(worldY / 3), noiseSeed + 2, 0) - 0.5) * 0.5
	local wobbleZ = (hash3D(math.floor(worldX / 2), math.floor(worldY / 3), noiseSeed + 3, 0) - 0.5) * 0.5

	local adjustedX = localX + wobbleX
	local adjustedZ = localZ + wobbleZ
	local adjustedDist = math.sqrt(adjustedX * adjustedX + adjustedZ * adjustedZ)

	-- Check if this voxel is within the stalactite column
	if adjustedDist > radiusAtHeight then
		return
	end

	-- Calculate occupancy based on distance from center (smooth edges)
	local edgeDist = adjustedDist / radiusAtHeight
	local targetOccupancy = math.clamp(1 - edgeDist * 0.5, 0.3, 1)

	-- Taper occupancy toward tip
	targetOccupancy = targetOccupancy * (1 - t * 0.5)

	-- Apply based on strength
	local blendFactor = (strength + 0.1) * 0.6 * brushOccupancy * magnitudePercent
	local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor

	-- Only add, never remove
	if newOccupancy > cellOccupancy then
		writeOccupancies[voxelX][voxelY][voxelZ] = math.min(1, newOccupancy)

		if cellMaterial == materialAir then
			writeMaterials[voxelX][voxelY][voxelZ] = desiredMaterial
		end
	end
end

-- ============================================================================
-- Tendril Generator Tool
-- Creates organic branching structures (roots, vines, coral)
-- ============================================================================
local function tendril(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength

	-- Tendril-specific parameters
	local worldX = options.worldX or 0
	local worldY = options.worldY or 0
	local worldZ = options.worldZ or 0
	local centerX = options.centerX or 0
	local centerY = options.centerY or 0
	local centerZ = options.centerZ or 0
	local tendrilRadius = options.tendrilRadius or 1.5
	local tendrilBranches = options.tendrilBranches or 5
	local tendrilLength = options.tendrilLength or 15
	local tendrilCurl = options.tendrilCurl or 0.5
	local noiseSeed = options.noiseSeed or 0
	local desiredMaterial = options.desiredMaterial or Enum.Material.Ground

	-- Skip if brush influence is too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Calculate distance from brush center
	local localX = worldX - centerX
	local localY = worldY - centerY
	local localZ = worldZ - centerZ
	local distFromCenter = math.sqrt(localX * localX + localY * localY + localZ * localZ)

	-- Skip if too far from brush region
	if distFromCenter > tendrilLength * 1.5 then
		return
	end

	-- Generate multiple tendril paths from center
	local closestTendrilDist = math.huge

	for branch = 1, tendrilBranches do
		-- Each branch has a unique direction based on seed + branch
		local branchSeed = noiseSeed + branch * 100

		-- Initial direction (somewhat uniform distribution)
		local phi = hash3D(branch, 0, branchSeed, 0) * math.pi * 2
		local theta = hash3D(branch, 1, branchSeed, 0) * math.pi * 0.8 + math.pi * 0.1 -- Avoid straight up/down

		local dirX = math.sin(theta) * math.cos(phi)
		local dirY = math.cos(theta) - 0.3 -- Bias downward for roots
		local dirZ = math.sin(theta) * math.sin(phi)

		-- Normalize
		local dirLen = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
		dirX, dirY, dirZ = dirX / dirLen, dirY / dirLen, dirZ / dirLen

		-- Trace along the tendril path
		local steps = math.floor(tendrilLength / 2)
		local px, py, pz = centerX, centerY, centerZ
		local currentRadius = tendrilRadius

		for step = 1, steps do
			-- Move along the path
			local stepLen = 2
			px = px + dirX * stepLen
			py = py + dirY * stepLen
			pz = pz + dirZ * stepLen

			-- Calculate distance from this voxel to this point on the tendril
			local dx = worldX - px
			local dy = worldY - py
			local dz = worldZ - pz
			local distToPath = math.sqrt(dx * dx + dy * dy + dz * dz)

			-- Track closest distance
			if distToPath < closestTendrilDist then
				closestTendrilDist = distToPath
			end

			-- Add curl/twist to direction
			local curlNoise = hash3D(math.floor(px), math.floor(py), math.floor(pz), branchSeed + step)
			local curlAngle = (curlNoise - 0.5) * tendrilCurl * 2

			-- Rotate direction slightly
			local cosA = math.cos(curlAngle)
			local sinA = math.sin(curlAngle)
			local newDirX = dirX * cosA - dirZ * sinA
			local newDirZ = dirX * sinA + dirZ * cosA
			dirX = newDirX
			dirZ = newDirZ

			-- Taper radius
			currentRadius = currentRadius * 0.95

			-- Stop if radius too small
			if currentRadius < 0.3 then
				break
			end
		end
	end

	-- Check if this voxel is close to any tendril
	if closestTendrilDist > tendrilRadius * 2 then
		return
	end

	-- Calculate occupancy based on distance from tendril
	local distRatio = closestTendrilDist / (tendrilRadius * 2)
	local targetOccupancy = math.clamp(1 - distRatio, 0, 1)

	-- Apply based on strength
	local blendFactor = (strength + 0.1) * 0.5 * brushOccupancy * magnitudePercent
	local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor

	-- Only add, never remove
	if newOccupancy > cellOccupancy + 0.01 then
		writeOccupancies[voxelX][voxelY][voxelZ] = math.min(1, newOccupancy)

		if cellMaterial == materialAir then
			writeMaterials[voxelX][voxelY][voxelZ] = desiredMaterial
		end
	end
end

-- ============================================================================
-- Symmetry Tool
-- Applies symmetric transformations (mirror, radial) within brush region
-- ============================================================================
local function symmetry(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial

	-- Symmetry-specific parameters
	local symmetryType = options.symmetryType or "MirrorX" -- MirrorX, MirrorZ, Radial4, Radial6, Radial8
	local symmetrySegments = options.symmetrySegments or 4
	local centerX = options.centerX or sizeX / 2
	local centerY = options.centerY or sizeY / 2
	local centerZ = options.centerZ or sizeZ / 2

	-- Skip if brush influence is too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Calculate position relative to center (in voxel coords)
	local relX = voxelX - centerX
	local relY = voxelY - centerY
	local relZ = voxelZ - centerZ

	-- Determine if this is in the "source" sector
	-- For mirrors: one half is source, other is target
	-- For radial: first segment is source, others are targets

	local isSource = false
	local sourceX, sourceY, sourceZ = voxelX, voxelY, voxelZ

	if symmetryType == "MirrorX" then
		-- Mirror across YZ plane (X axis flip)
		if relX >= 0 then
			isSource = true
		else
			-- Map to mirrored position
			sourceX = centerX + math.abs(relX)
		end
	elseif symmetryType == "MirrorZ" then
		-- Mirror across XY plane (Z axis flip)
		if relZ >= 0 then
			isSource = true
		else
			-- Map to mirrored position
			sourceZ = centerZ + math.abs(relZ)
		end
	elseif symmetryType == "MirrorXZ" then
		-- Mirror across both axes (4-way)
		local inFirstQuadrant = relX >= 0 and relZ >= 0
		if inFirstQuadrant then
			isSource = true
		else
			sourceX = centerX + math.abs(relX)
			sourceZ = centerZ + math.abs(relZ)
		end
	else
		-- Radial symmetry
		local angle = math.atan2(relZ, relX)
		if angle < 0 then
			angle = angle + math.pi * 2
		end

		local segmentAngle = (math.pi * 2) / symmetrySegments
		local segmentIndex = math.floor(angle / segmentAngle)

		if segmentIndex == 0 then
			isSource = true
		else
			-- Rotate back to first segment
			local rotationAngle = -segmentIndex * segmentAngle
			local cosA = math.cos(rotationAngle)
			local sinA = math.sin(rotationAngle)

			local rotX = relX * cosA - relZ * sinA
			local rotZ = relX * sinA + relZ * cosA

			sourceX = centerX + rotX
			sourceZ = centerZ + rotZ
		end
	end

	if isSource then
		-- Source voxels are unchanged
		return
	end

	-- Round to nearest voxel
	sourceX = math.floor(sourceX + 0.5)
	sourceY = math.floor(sourceY + 0.5)
	sourceZ = math.floor(sourceZ + 0.5)

	-- Bounds check
	if sourceX < 1 or sourceX > sizeX or sourceY < 1 or sourceY > sizeY or sourceZ < 1 or sourceZ > sizeZ then
		return
	end

	-- Copy from source to target
	local sourceOcc = readOccupancies[sourceX][sourceY][sourceZ]
	local sourceMat = readMaterials[sourceX][sourceY][sourceZ]

	writeOccupancies[voxelX][voxelY][voxelZ] = sourceOcc
	writeMaterials[voxelX][voxelY][voxelZ] = sourceMat
end

-- ============================================================================
-- Variation Grid Tool
-- Creates a grid pattern with variations (noise-based tiling effect)
-- ============================================================================
local function variationGrid(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength

	-- Variation grid parameters
	local worldX = options.worldX or 0
	local worldY = options.worldY or 0
	local worldZ = options.worldZ or 0
	local gridCellSize = options.gridCellSize or 8
	local gridVariation = options.gridVariation or 0.3
	local noiseSeed = options.noiseSeed or 0
	local desiredMaterial = options.desiredMaterial or Enum.Material.Rock

	-- Skip if brush influence is too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Calculate grid cell coordinates
	local cellX = math.floor(worldX / gridCellSize)
	local cellZ = math.floor(worldZ / gridCellSize)

	-- Position within cell (0-1)
	local localX = (worldX % gridCellSize) / gridCellSize
	local localZ = (worldZ % gridCellSize) / gridCellSize

	-- Hash for this grid cell (determines cell-specific variation)
	local cellHash = hash3D(cellX, cellZ, noiseSeed, 0)
	local cellHashY = hash3D(cellX, cellZ, noiseSeed + 1, 0)

	-- Height variation per cell
	local heightVariation = (cellHash - 0.5) * gridVariation * gridCellSize
	local targetOccupancy = 0

	-- Create raised squares with variation
	local edgeMargin = 0.15 -- How far from edge to start falloff
	local distFromEdge = math.min(localX, 1 - localX, localZ, 1 - localZ)

	if distFromEdge < edgeMargin then
		-- Edge zone - smooth falloff
		targetOccupancy = distFromEdge / edgeMargin
	else
		-- Inside zone - full height
		targetOccupancy = 1
	end

	-- Apply height variation
	local adjustedY = worldY - heightVariation
	if adjustedY > gridCellSize * 0.3 then
		targetOccupancy = 0 -- Above the grid cell's height
	end

	-- Only add terrain, don't remove
	if targetOccupancy > cellOccupancy then
		local blendFactor = strength * 0.5 * brushOccupancy * magnitudePercent
		local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor

		if math.abs(newOccupancy - cellOccupancy) > 0.01 then
			writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy

			if cellMaterial == materialAir and newOccupancy > 0 then
				writeMaterials[voxelX][voxelY][voxelZ] = desiredMaterial
			end
		end
	end
end

-- ============================================================================
-- Growth Simulation Tool
-- Simulates organic terrain growth/expansion from existing terrain
-- ============================================================================
local function growthSim(options)
	local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
	local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local ignoreWater = options.ignoreWater

	-- Growth simulation parameters
	local growthRate = options.growthRate or 0.3
	local growthBias = options.growthBias or 0 -- -1=down, 0=uniform, 1=up
	local growthPattern = options.growthPattern or "organic" -- organic, crystalline, cellular
	local worldX = options.worldX or 0
	local worldY = options.worldY or 0
	local worldZ = options.worldZ or 0
	local noiseSeed = options.noiseSeed or 0

	-- Skip if brush influence is too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Skip if cell is already full
	if cellOccupancy >= 1 then
		return
	end

	-- Check if any neighbor is filled (growth source)
	local hasFilledNeighbor = false
	local neighborSum = 0
	local neighborMaterials = {}
	local neighborCount = 0

	for i = 1, 6 do
		local nx = voxelX + OperationHelper.xOffset[i]
		local ny = voxelY + OperationHelper.yOffset[i]
		local nz = voxelZ + OperationHelper.zOffset[i]

		if nx > 0 and nx <= sizeX and ny > 0 and ny <= sizeY and nz > 0 and nz <= sizeZ then
			local neighborOcc = readOccupancies[nx][ny][nz]
			local neighborMat = readMaterials[nx][ny][nz]

			if ignoreWater and neighborMat == materialWater then
				neighborOcc = 0
			end

			if neighborOcc > 0.5 then
				hasFilledNeighbor = true
				neighborSum = neighborSum + neighborOcc
				neighborCount = neighborCount + 1
				table.insert(neighborMaterials, neighborMat)
			end
		end
	end

	if not hasFilledNeighbor then
		return -- No growth source
	end

	-- Calculate growth amount based on pattern
	local growthAmount = 0

	if growthPattern == "organic" then
		-- Perlin noise based - smooth, flowing growth
		local noiseVal = fbm3D(worldX / 8, worldY / 8, worldZ / 8, noiseSeed, 2)
		growthAmount = neighborSum / 6 * growthRate * noiseVal * 2
	elseif growthPattern == "crystalline" then
		-- Angular, geometric growth
		local angleNoise = hash3D(math.floor(worldX / 4), math.floor(worldY / 4), math.floor(worldZ / 4), noiseSeed)
		if angleNoise > 0.6 then
			growthAmount = neighborSum / 6 * growthRate
		end
	elseif growthPattern == "cellular" then
		-- Round, blob-like growth
		local threshold = 0.3 + (neighborCount / 6) * 0.4
		local noise = hash3D(voxelX, voxelY, voxelZ, noiseSeed)
		if noise < threshold then
			growthAmount = neighborSum / 6 * growthRate
		end
	end

	-- Apply directional bias
	if growthBias ~= 0 then
		-- Check if growing up or down
		local aboveOcc = voxelY < sizeY and readOccupancies[voxelX][voxelY + 1][voxelZ] or 0
		local belowOcc = voxelY > 1 and readOccupancies[voxelX][voxelY - 1][voxelZ] or 1

		if growthBias > 0 then
			-- Upward bias - grow more if below is filled
			if belowOcc > 0.5 then
				growthAmount = growthAmount * (1 + growthBias)
			end
		else
			-- Downward bias - grow more if above is filled
			if aboveOcc > 0.5 then
				growthAmount = growthAmount * (1 - growthBias)
			end
		end
	end

	-- Apply growth
	if growthAmount > 0.01 then
		local targetOccupancy = math.min(1, cellOccupancy + growthAmount * strength * brushOccupancy * magnitudePercent)

		if targetOccupancy > cellOccupancy + 0.01 then
			writeOccupancies[voxelX][voxelY][voxelZ] = targetOccupancy

			-- Inherit material from neighbors
			if cellMaterial == materialAir and #neighborMaterials > 0 then
				-- Pick most common neighbor material
				writeMaterials[voxelX][voxelY][voxelZ] = neighborMaterials[1]
			end
		end
	end
end

-- Add to exports
return {
	grow = grow,
	erode = erode,
	smooth = smooth,
	noise = noise,
	terrace = terrace,
	cliff = cliff,
	path = path,
	clone = clone,
	blobify = blobify,
	slopePaint = slopePaint,
	megarandomize = megarandomize,
	cavityFill = cavityFill,
	melt = melt,
	gradientPaint = gradientPaint,
	floodPaint = floodPaint,
	stalactite = stalactite,
	tendril = tendril,
	symmetry = symmetry,
	variationGrid = variationGrid,
	growthSim = growthSim,
}
