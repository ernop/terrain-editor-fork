local OperationHelper = require(script.Parent.OperationHelper)

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
	return (n % 1000000) / 1000000  -- Returns 0 to 1
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
	
	return nxy0 + fz * (nxy1 - nxy0)  -- Returns 0 to 1
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
	
	return value / maxValue  -- Normalize to 0-1
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
		if nx > 0 and nx <= sizeX
			and ny > 0 and ny <= sizeY
			and nz > 0 and nz <= sizeZ then
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
		desiredOccupancy = desiredOccupancy
			+ neighborOccupancies * (strength + 0.1) * 0.25 * brushOccupancy * magnitudePercent
	end

	desiredOccupancy = math.min(desiredOccupancy, maxOccupancy)

	if cellMaterial == materialAir and desiredOccupancy > 0 then
		local targetMaterial = desiredMaterial
		if autoMaterial then
			targetMaterial = OperationHelper.getMaterialForAutoMaterial(readMaterials,
				voxelX, voxelY, voxelZ,
				sizeX, sizeY, sizeZ,
				cellMaterial)
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
		if nx > 0 and nx <= sizeX
			and ny > 0 and ny <= sizeY
			and nz > 0 and nz <= sizeZ then
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
		desiredOccupancy = desiredOccupancy
			- (neighborOccupancies / 6) * (strength + 0.1) * 0.25 * brushOccupancy * magnitudePercent
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

				if checkX > 0 and checkX <= sizeX
					and checkY > 0 and checkY <= sizeY
					and checkZ > 0 and checkZ <= sizeZ then
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

	local neighbourOccupancies = neighbourOccupanciesSum / (totalNeighbours > 0 and totalNeighbours
		or (cellOccupancy * 1.5 - 0.25))

	local difference = (neighbourOccupancies - cellOccupancy)
		* (strength + 0.1)
		* 0.5
		* brushOccupancy
		* magnitudePercent

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
			writeMaterials[voxelX][voxelY][voxelZ] = OperationHelper.getMaterialForAutoMaterial(readMaterials,
				voxelX, voxelY, voxelZ,
				sizeX, sizeY, sizeZ,
				cellMaterial)

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
			writeMaterials[voxelX][voxelY][voxelZ] = OperationHelper.getMaterialForAutoMaterial(
				readMaterials,
				voxelX, voxelY, voxelZ,
				sizeX, sizeY, sizeZ,
				cellMaterial
			)
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
	local stepHeight = options.stepHeight or 8  -- Height of each step in studs
	local stepSharpness = options.stepSharpness or 0.8  -- 0-1, how sharp the edges are
	
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
	local stepProgress = heightInStep / stepHeight  -- 0 at step base, 1 at top
	
	-- Determine target occupancy based on position within step
	-- riserZone: the vertical portion of the step (where we want a wall)
	-- treadZone: the horizontal portion (where we want flat ground)
	local riserWidth = (1 - stepSharpness) * 0.5 + 0.1  -- 0.1 to 0.6 of step height
	
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
			writeMaterials[voxelX][voxelY][voxelZ] = OperationHelper.getMaterialForAutoMaterial(
				readMaterials,
				voxelX, voxelY, voxelZ,
				sizeX, sizeY, sizeZ,
				cellMaterial
			)
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
	local cellVectorX = options.cellVectorX or 0  -- Offset from brush center
	local cellVectorZ = options.cellVectorZ or 0
	local cliffDirectionX = options.cliffDirectionX or 1  -- Cliff face normal direction (horizontal)
	local cliffDirectionZ = options.cliffDirectionZ or 0
	local cliffAngle = options.cliffAngle or 90  -- Target angle in degrees (90 = vertical)
	
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
	local transitionWidth = 4 / math.tan(math.max(angleRadians, 0.1))  -- Avoid division by zero
	transitionWidth = math.clamp(transitionWidth, 1, 8)  -- Keep reasonable bounds
	
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
			writeMaterials[voxelX][voxelY][voxelZ] = OperationHelper.getMaterialForAutoMaterial(
				readMaterials,
				voxelX, voxelY, voxelZ,
				sizeX, sizeY, sizeZ,
				cellMaterial
			)
		end
	end
end

return {
	grow = grow,
	erode = erode,
	smooth = smooth,
	noise = noise,
	terrace = terrace,
	cliff = cliff,
}
