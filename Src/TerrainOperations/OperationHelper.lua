--!strict

local Plugin = script.Parent.Parent.Parent

local Constants = require(Plugin.Src.Util.Constants)
local TerrainEnums = require(Plugin.Src.Util.TerrainEnums)
local BrushShape = TerrainEnums.BrushShape

local materialAir = Enum.Material.Air
local materialWater = Enum.Material.Water

local OperationHelper = {}

OperationHelper.xOffset = { 1, -1, 0, 0, 0, 0 }
OperationHelper.yOffset = { 0, 0, 1, -1, 0, 0 }
OperationHelper.zOffset = { 0, 0, 0, 0, 1, -1 }

-- This should later be replaced with 0 once smooth terrain doesn't approximate 1/256 to 0.
-- This is causing small occupancies to become air
OperationHelper.one256th = 1 / 256

-- ============================================================================
-- FALLOFF CURVES
-- These control how brush strength fades from center (d=0) to edge (d=1)
-- Each function takes normalized distance d [0,1] and returns strength [0,1]
-- ============================================================================
local FalloffFunctions = {}

-- Cosine falloff (original): cos(d * π/2) - smooth S-curve
function FalloffFunctions.Cosine(d)
	return math.cos(math.min(1, d) * math.pi * 0.5)
end

-- Linear falloff: 1 - d, predictable even gradient
function FalloffFunctions.Linear(d)
	return math.max(0, 1 - d)
end

-- Plateau falloff: flat full strength in center (~60%), then sharp edge falloff
function FalloffFunctions.Plateau(d)
	if d < 0.6 then
		return 1.0
	end
	local t = (d - 0.6) / 0.4 -- Remap 0.6-1.0 to 0-1
	return 1 - t * t * (3 - 2 * t) -- Smoothstep for the edge
end

-- Gaussian falloff: e^(-d² * 3), very soft organic falloff
function FalloffFunctions.Gaussian(d)
	return math.exp(-d * d * 3)
end

-- Quadratic falloff: (1-d)², falls off fast from center
function FalloffFunctions.Quadratic(d)
	local t = math.max(0, 1 - d)
	return t * t
end

-- Sharp falloff: 1 - d³, strong center, steep edge
function FalloffFunctions.Sharp(d)
	return math.max(0, 1 - d * d * d)
end

-- Helper to get falloff function by name (with fallback to Cosine)
local function getFalloffFunction(falloffType)
	return FalloffFunctions[falloffType] or FalloffFunctions.Cosine
end

-- Export for testing/introspection
OperationHelper.FalloffFunctions = FalloffFunctions

function OperationHelper.clampDownToVoxel(p)
	return math.floor(p / Constants.VOXEL_RESOLUTION) * Constants.VOXEL_RESOLUTION
end

function OperationHelper.clampUpToVoxel(p)
	return math.ceil(p / Constants.VOXEL_RESOLUTION) * Constants.VOXEL_RESOLUTION
end

-- This function is to be modified at a later point in time to match more different planes
function OperationHelper.getDesiredOccupancy(planePoint, planeNormal, worldVectorX, worldVectorZ, minBoundsY)
	local voxelY = ((planePoint.y - minBoundsY) / Constants.VOXEL_RESOLUTION) + 0.5
	local flooredVoxelY = math.floor(voxelY)
	local desiredOccupancy = voxelY - flooredVoxelY

	return flooredVoxelY, desiredOccupancy
end

function OperationHelper.getWaterHeightAndAirFillerMaterial(readMaterials)
	local airFillerMaterial = materialAir
	local waterHeight = 0

	for _, vx in ipairs(readMaterials) do
		for y, vy in ipairs(vx) do
			for _, vz in ipairs(vy) do
				if vz == materialWater then
					airFillerMaterial = materialWater
					if y > waterHeight then
						waterHeight = y
					end
				end
			end
		end
	end

	return waterHeight, airFillerMaterial
end

-- Original function for backward compatibility
function OperationHelper.calculateBrushPowerForCell(
	cellVectorX,
	cellVectorY,
	cellVectorZ,
	selectionSize,
	brushShape,
	radiusOfRegion,
	scaleMagnitudePercent
)
	-- Call the new function with uniform radii
	return OperationHelper.calculateBrushPowerForCellAxisAligned(
		cellVectorX,
		cellVectorY,
		cellVectorZ,
		radiusOfRegion,
		radiusOfRegion,
		radiusOfRegion,
		brushShape,
		selectionSize,
		scaleMagnitudePercent
	)
end

-- New function supporting per-axis radii and rotation for ellipsoid/box brushes
-- brushRotation: CFrame representing the brush orientation (or nil for no rotation)
-- falloffType: string key for falloff function ("Cosine", "Linear", "Plateau", etc.)
-- falloffExtent: how far falloff extends beyond brush edge (0 = none, 1 = 100% of brush radius)
function OperationHelper.calculateBrushPowerForCellRotated(
	cellVectorX,
	cellVectorY,
	cellVectorZ,
	radiusX,
	radiusY,
	radiusZ,
	brushShape,
	selectionSize,
	scaleMagnitudePercent,
	brushRotation,
	hollowEnabled,
	wallThickness,
	falloffType,
	falloffExtent
)
	-- Transform world-space cell offset into brush-local space if rotation is provided
	local localX, localY, localZ = cellVectorX, cellVectorY, cellVectorZ
	if brushRotation and brushRotation ~= CFrame.new() then
		-- Inverse rotate the cell vector to get brush-local coordinates
		local localVector = brushRotation:Inverse() * Vector3.new(cellVectorX, cellVectorY, cellVectorZ)
		localX = localVector.X
		localY = localVector.Y
		localZ = localVector.Z
	end

	-- Use the axis-aligned calculation with local coordinates
	return OperationHelper.calculateBrushPowerForCellAxisAligned(
		localX,
		localY,
		localZ,
		radiusX,
		radiusY,
		radiusZ,
		brushShape,
		selectionSize,
		scaleMagnitudePercent,
		hollowEnabled,
		wallThickness,
		falloffType,
		falloffExtent
	)
end

-- New function supporting per-axis radii for ellipsoid/box brushes
-- falloffType: string key for falloff function ("Cosine", "Linear", "Plateau", etc.)
-- falloffExtent: how far falloff extends beyond brush edge (0 = none, 1 = 100% of brush radius)
function OperationHelper.calculateBrushPowerForCellAxisAligned(
	cellVectorX,
	cellVectorY,
	cellVectorZ,
	radiusX,
	radiusY,
	radiusZ,
	brushShape,
	selectionSize,
	scaleMagnitudePercent,
	hollowEnabled,
	wallThickness,
	falloffType,
	falloffExtent
)
	local brushOccupancy = 1
	local magnitudePercent = 1

	-- Default hollow parameters if not provided
	hollowEnabled = hollowEnabled or false
	wallThickness = wallThickness or 0.2
	falloffExtent = falloffExtent or 0

	-- Get the falloff function for this operation
	local falloff = getFalloffFunction(falloffType)

	-- Falloff extent scales the effective region for the falloff curve
	-- 0 = falloff only within brush (original behavior)
	-- 1 = falloff extends to 2x the brush radius
	local falloffMultiplier = 1 + falloffExtent
	local inverseFalloffMultiplier = 1 / falloffMultiplier

	-- Use the average radius for edge falloff calculation
	local avgRadius = (radiusX + radiusY + radiusZ) / 3

	if selectionSize > 2 then
		if brushShape == BrushShape.Sphere then
			-- For ellipsoid: normalize each axis by its radius, then compute distance in normalized space
			-- This makes the brush an ellipsoid that stretches with the axis sizes
			local normX = cellVectorX / radiusX
			local normY = cellVectorY / radiusY
			local normZ = cellVectorZ / radiusZ
			local normalizedDistance = math.sqrt(normX * normX + normY * normY + normZ * normZ)

			-- Scale distance for falloff curve (extends effective range when falloffExtent > 0)
			local scaledDistance = normalizedDistance * inverseFalloffMultiplier
			magnitudePercent = falloff(scaledDistance)

			-- Edge falloff and occupancy - extend to include falloff region
			if normalizedDistance <= falloffMultiplier then
				brushOccupancy = math.max(0, math.min(1, (falloffMultiplier - normalizedDistance) * avgRadius / Constants.VOXEL_RESOLUTION))
				if normalizedDistance <= 1 then
					brushOccupancy = math.max(brushOccupancy, 0.01) -- Ensure inside voxels have some occupancy
				end
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.Cylinder then
			-- Cylinder: X and Z define the radial cross-section, Y is height
			-- Normalize X and Z by radiusX (assuming radiusX = radiusZ for cylinder)
			local normX = cellVectorX / radiusX
			local normZ = cellVectorZ / radiusZ
			local radialDistance = math.sqrt(normX * normX + normZ * normZ)

			-- Check if within height bounds (extended for falloff)
			local normY = math.abs(cellVectorY) / radiusY
			local insideHeight = normY <= falloffMultiplier

			if insideHeight and radialDistance <= falloffMultiplier then
				local scaledDistance = radialDistance * inverseFalloffMultiplier
				magnitudePercent = falloff(scaledDistance)
				brushOccupancy = math.max(0, math.min(1, (falloffMultiplier - radialDistance) * radiusX / Constants.VOXEL_RESOLUTION))
				if radialDistance <= 1 then
					brushOccupancy = math.max(brushOccupancy, 0.01)
				end
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.Cube then
			-- Box: each axis is independent, use max of normalized distances
			local normX = math.abs(cellVectorX) / radiusX
			local normY = math.abs(cellVectorY) / radiusY
			local normZ = math.abs(cellVectorZ) / radiusZ
			local maxNorm = math.max(normX, normY, normZ)

			if maxNorm <= falloffMultiplier then
				-- Inside the box or falloff region
				local scaledDistance = maxNorm * inverseFalloffMultiplier
				magnitudePercent = falloff(scaledDistance)
				brushOccupancy = math.max(0, math.min(1, (falloffMultiplier - maxNorm) * avgRadius / Constants.VOXEL_RESOLUTION))
				if maxNorm <= 1 then
					brushOccupancy = math.max(brushOccupancy, 0.01)
				end
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.Wedge then
			-- Wedge: ramps from bottom-back to top-front
			-- The wedge occupies space where: Y <= (radiusY) * (1 - Z/radiusZ)
			-- Normalized: normY <= 1 - normZ (for positive Z side)
			local normX = math.abs(cellVectorX) / radiusX
			local normY = (cellVectorY + radiusY) / (2 * radiusY) -- 0 at bottom, 1 at top
			local normZ = (cellVectorZ + radiusZ) / (2 * radiusZ) -- 0 at back, 1 at front

			-- Wedge condition: height decreases as we go forward (Z increases)
			-- At back (normZ=0), full height allowed (normY can be 0-1)
			-- At front (normZ=1), no height allowed (normY must be 0)
			local maxAllowedY = 1 - normZ

			if normX <= 1 and normY >= 0 and normY <= maxAllowedY and normZ >= 0 and normZ <= 1 then
				local edgeDist = math.min(1 - normX, normY, maxAllowedY - normY, normZ, 1 - normZ)
				magnitudePercent = falloff(1 - edgeDist)
				brushOccupancy = math.max(0.01, math.min(1, edgeDist * avgRadius / Constants.VOXEL_RESOLUTION))
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.CornerWedge then
			-- CornerWedge: triangular corner piece
			-- Occupies space where: Y <= radiusY * (1 - max(X, Z) / radius)
			local normX = (cellVectorX + radiusX) / (2 * radiusX) -- 0 to 1
			local normY = (cellVectorY + radiusY) / (2 * radiusY) -- 0 at bottom, 1 at top
			local normZ = (cellVectorZ + radiusZ) / (2 * radiusZ) -- 0 to 1

			-- Corner wedge: height decreases toward the corner (high X and Z)
			local maxAllowedY = 1 - math.max(normX, normZ)

			if normX >= 0 and normX <= 1 and normY >= 0 and normY <= maxAllowedY and normZ >= 0 and normZ <= 1 then
				local edgeDist = math.min(normX, 1 - normX, normY, maxAllowedY - normY, normZ, 1 - normZ)
				magnitudePercent = falloff(1 - edgeDist)
				brushOccupancy = math.max(0.01, math.min(1, edgeDist * avgRadius / Constants.VOXEL_RESOLUTION))
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.Dome then
			-- Dome: half-sphere (top half only)
			-- Only include voxels where Y >= 0 (above center)
			local normX = cellVectorX / radiusX
			local normY = cellVectorY / radiusY
			local normZ = cellVectorZ / radiusZ
			local normalizedDistance = math.sqrt(normX * normX + normY * normY + normZ * normZ)

			-- Only include top half (Y >= 0 in local space), extended for falloff
			if cellVectorY >= 0 and normalizedDistance <= falloffMultiplier then
				local scaledDistance = normalizedDistance * inverseFalloffMultiplier
				magnitudePercent = falloff(scaledDistance)
				brushOccupancy = math.max(0, math.min(1, (falloffMultiplier - normalizedDistance) * avgRadius / Constants.VOXEL_RESOLUTION))
				if normalizedDistance <= 1 then
					brushOccupancy = math.max(brushOccupancy, 0.01)
				end
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end

		-- ========================================================================
		-- CREATIVE SHAPES
		-- ========================================================================
		elseif brushShape == BrushShape.Torus then
			-- Torus (donut shape)
			-- radiusX = major radius (distance from center to tube center)
			-- radiusY = minor radius (tube thickness)
			local majorRadius = radiusX
			local minorRadius = radiusY

			-- Distance from Y axis in XZ plane
			local distFromAxis = math.sqrt(cellVectorX * cellVectorX + cellVectorZ * cellVectorZ)
			-- Distance from the ring (tube center)
			local distFromRing = distFromAxis - majorRadius
			-- 3D distance from tube surface
			local tubeDistance = math.sqrt(distFromRing * distFromRing + cellVectorY * cellVectorY)
			local normalizedTubeDistance = tubeDistance / minorRadius

			if normalizedTubeDistance <= falloffMultiplier then
				local scaledDistance = normalizedTubeDistance * inverseFalloffMultiplier
				magnitudePercent = falloff(scaledDistance)
				brushOccupancy = math.max(0.01, math.min(1, (1 - normalizedTubeDistance) * minorRadius / Constants.VOXEL_RESOLUTION))
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.Ring then
			-- Ring (flat washer shape - thin torus)
			-- radiusX = outer radius, radiusY = ring thickness (very thin)
			local outerRadius = radiusX
			local thickness = radiusY * 0.3 -- Make it thin
			local innerRadius = outerRadius * 0.6 -- Hollow center

			-- Distance from Y axis in XZ plane
			local distFromAxis = math.sqrt(cellVectorX * cellVectorX + cellVectorZ * cellVectorZ)
			local withinRadii = distFromAxis >= innerRadius and distFromAxis <= outerRadius
			local withinHeight = math.abs(cellVectorY) <= thickness

			if withinRadii and withinHeight then
				-- Edge falloff
				local radialPos = (distFromAxis - innerRadius) / (outerRadius - innerRadius)
				local edgeDist = math.min(radialPos, 1 - radialPos, (thickness - math.abs(cellVectorY)) / thickness)
				magnitudePercent = falloff(1 - edgeDist)
				brushOccupancy = math.max(0.01, math.min(1, edgeDist * avgRadius / Constants.VOXEL_RESOLUTION))
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.ZigZag then
			-- ZigZag (Z-shaped profile when viewed from side)
			-- Three horizontal bars connected diagonally
			local normX = math.abs(cellVectorX) / radiusX
			local normY = (cellVectorY + radiusY) / (2 * radiusY) -- 0 to 1
			local normZ = (cellVectorZ + radiusZ) / (2 * radiusZ) -- 0 to 1

			-- Z-shape: 3 horizontal segments at different heights
			-- Bottom bar (Y=0-0.2), Middle diagonal, Top bar (Y=0.8-1.0)
			local barThickness = 0.25
			local inShape = false

			if normX <= 1 and normZ >= 0 and normZ <= 1 then
				-- Bottom bar (full width at bottom)
				if normY >= 0 and normY <= barThickness and normZ >= 0.5 then
					inShape = true
				-- Top bar (full width at top)
				elseif normY >= (1 - barThickness) and normY <= 1 and normZ <= 0.5 then
					inShape = true
				-- Middle diagonal connector
				elseif normY > barThickness and normY < (1 - barThickness) then
					local expectedZ = 1 - normY -- Diagonal from (Z=1,Y=0) to (Z=0,Y=1)
					if math.abs(normZ - expectedZ) <= barThickness then
						inShape = true
					end
				end
			end

			if inShape then
				magnitudePercent = 0.8
				brushOccupancy = 0.8
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.Sheet then
			-- Sheet (curved paper - partial cylinder surface)
			-- radiusX = curve radius, radiusY = sheet height, radiusZ = sheet thickness
			local curveRadius = radiusX
			local sheetHeight = radiusY
			local sheetThickness = radiusZ * 0.15 -- Very thin

			-- Distance from the curve axis (along Y)
			local distFromAxis = math.sqrt(cellVectorX * cellVectorX + cellVectorZ * cellVectorZ)
			-- Check if on the curved surface (within thickness of the radius)
			local onSurface = math.abs(distFromAxis - curveRadius) <= sheetThickness
			-- Check height bounds
			local withinHeight = math.abs(cellVectorY) <= sheetHeight
			-- Only front half of the cylinder (positive Z or use angle)
			local angle = math.atan2(cellVectorX, cellVectorZ)
			local withinArc = math.abs(angle) <= math.pi * 0.6 -- ~108 degree arc

			if onSurface and withinHeight and withinArc then
				local surfaceDist = math.abs(distFromAxis - curveRadius) / sheetThickness
				magnitudePercent = falloff(surfaceDist)
				brushOccupancy = math.max(0.01, math.min(1, (1 - surfaceDist)))
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.Grid then
			-- Grid (3D checkerboard pattern)
			-- Creates an 8x8x8 grid where every other cell is filled
			-- Each cell is (totalSize/8) in each dimension
			local gridSize = 8
			local cellSize = (radiusX * 2) / gridSize -- Size of each grid cell

			-- Find which grid cell this voxel is in
			local gridX = math.floor((cellVectorX + radiusX) / cellSize)
			local gridY = math.floor((cellVectorY + radiusY) / cellSize)
			local gridZ = math.floor((cellVectorZ + radiusZ) / cellSize)

			-- Checkerboard pattern: fill if sum of coordinates is even
			local isFilledCell = ((gridX + gridY + gridZ) % 2) == 0

			-- Check bounds
			local inBounds = math.abs(cellVectorX) <= radiusX and math.abs(cellVectorY) <= radiusY and math.abs(cellVectorZ) <= radiusZ

			if isFilledCell and inBounds then
				magnitudePercent = 1
				brushOccupancy = 1
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.Stick then
			-- Stick (long thin rod)
			-- radiusX = stick thickness, radiusY = stick length
			local stickRadius = radiusX * 0.15 -- Very thin
			local stickLength = radiusY

			-- Distance from Y axis
			local distFromAxis = math.sqrt(cellVectorX * cellVectorX + cellVectorZ * cellVectorZ)
			local normalizedDist = distFromAxis / stickRadius
			local withinLength = math.abs(cellVectorY) <= stickLength

			if normalizedDist <= 1 and withinLength then
				magnitudePercent = falloff(normalizedDist)
				brushOccupancy = math.max(0.01, math.min(1, (1 - normalizedDist) * stickRadius / Constants.VOXEL_RESOLUTION))
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.Spinner then
			-- Spinner (cube that auto-rotates)
			-- The rotation is applied in the calling code via brushRotation
			-- Here we just calculate a standard box
			local normX = math.abs(cellVectorX) / radiusX
			local normY = math.abs(cellVectorY) / radiusY
			local normZ = math.abs(cellVectorZ) / radiusZ
			local maxNorm = math.max(normX, normY, normZ)

			if maxNorm <= 1 then
				magnitudePercent = falloff(maxNorm)
				brushOccupancy = math.max(0.01, math.min(1, (1 - maxNorm) * avgRadius / Constants.VOXEL_RESOLUTION))
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		elseif brushShape == BrushShape.Spikepad then
			-- Spikepad: flat base with 5x5 grid of cone spikes pointing up
			local normX = cellVectorX / radiusX -- -1 to 1 across width
			local normZ = cellVectorZ / radiusZ -- -1 to 1 across depth
			local normY = (cellVectorY + radiusY) / (2 * radiusY) -- 0 at bottom, 1 at top

			-- Check if within the XZ bounds
			if math.abs(normX) <= 1 and math.abs(normZ) <= 1 and normY >= 0 and normY <= 1 then
				-- 5x5 grid of cone spikes
				local gridSize = 5
				local spikeSpacing = 2 / gridSize -- Spacing between spike centers in normalized coords

				-- Find distance to nearest spike center
				local spikeX = math.floor((normX + 1) / spikeSpacing + 0.5) * spikeSpacing - 1
				local spikeZ = math.floor((normZ + 1) / spikeSpacing + 0.5) * spikeSpacing - 1

				-- Clamp spike centers to valid range (centers at -0.8, -0.4, 0, 0.4, 0.8)
				local maxCenter = 1 - spikeSpacing / 2
				spikeX = math.max(-maxCenter, math.min(maxCenter, spikeX))
				spikeZ = math.max(-maxCenter, math.min(maxCenter, spikeZ))

				local distToSpike = math.sqrt((normX - spikeX) ^ 2 + (normZ - spikeZ) ^ 2)
				local spikeRadius = spikeSpacing * 0.45 -- Cone base radius relative to spacing

				-- Base layer (thin platform at bottom)
				local baseHeight = 0.15 -- Bottom 15% is solid base

				if normY <= baseHeight then
					-- Solid base platform
					magnitudePercent = 1
					brushOccupancy = 1
				elseif distToSpike <= spikeRadius then
					-- Inside a cone spike
					-- Cone tapers from full at base to point at top
					local spikeProgress = (normY - baseHeight) / (1 - baseHeight) -- 0 at base, 1 at tip
					local maxRadiusAtHeight = spikeRadius * (1 - spikeProgress) -- Cone tapers linearly

					if distToSpike <= maxRadiusAtHeight then
						-- Inside the cone at this height
						local sharpness = 1 - (distToSpike / maxRadiusAtHeight) -- 1 at center, 0 at edge
						magnitudePercent = sharpness
						brushOccupancy = math.max(0.01, sharpness)
					else
						brushOccupancy = 0
						magnitudePercent = 0
					end
				else
					-- Outside cones and above base
					brushOccupancy = 0
					magnitudePercent = 0
				end
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
		end
	end

	-- Apply hollow modifier if enabled
	-- This creates a shell by zeroing out the interior of any shape
	if hollowEnabled and brushOccupancy > 0 then
		-- Calculate normalized distance for hollow effect
		-- For most shapes, we use the ellipsoid approximation
		local normX = cellVectorX / radiusX
		local normY = cellVectorY / radiusY
		local normZ = cellVectorZ / radiusZ
		local normalizedDist = math.sqrt(normX * normX + normY * normY + normZ * normZ)

		-- For box-like shapes, use max instead of sqrt for proper hollow boxes
		if
			brushShape == BrushShape.Cube
			or brushShape == BrushShape.Wedge
			or brushShape == BrushShape.CornerWedge
			or brushShape == BrushShape.ZigZag
			or brushShape == BrushShape.Spikepad
		then
			normalizedDist = math.max(math.abs(normX), math.abs(normY), math.abs(normZ))
		end

		local innerRadius = 1 - wallThickness

		if normalizedDist < innerRadius then
			-- Inside the hollow region - zero out
			brushOccupancy = 0
			magnitudePercent = 0
		else
			-- In the shell wall - adjust strength based on distance from inner surface
			local distFromInner = normalizedDist - innerRadius
			local shellStrength = math.min(1, distFromInner / (wallThickness * 0.5))
			magnitudePercent = magnitudePercent * shellStrength
		end
	end

	if scaleMagnitudePercent then
		-- When brush size is less than this, we don't change brush power
		-- If it's larger than this, then we scale brush power
		local cutoffSize = 20
		local denominator = 5

		if selectionSize > cutoffSize then
			magnitudePercent = magnitudePercent * ((selectionSize - cutoffSize) / denominator)
		end
	end

	return brushOccupancy, magnitudePercent
end

function OperationHelper.getMaterialForAutoMaterial(readMaterials, voxelX, voxelY, voxelZ, sizeX, sizeY, sizeZ, initialMaterial)
	local materialsAroundCell = {}
	for x = -1, 1, 1 do
		for y = -1, 1, 1 do
			for z = -1, 1, 1 do
				local nx = voxelX + x
				local ny = voxelY + y
				local nz = voxelZ + z
				if nx > 0 and nx <= sizeX and ny > 0 and ny <= sizeY and nz > 0 and nz <= sizeZ then
					local m = readMaterials[nx][ny][nz]
					if m ~= materialAir then
						materialsAroundCell[m] = (materialsAroundCell[m] or 0) + 1
					end
				end
			end
		end
	end

	local cellDesiredMaterial = initialMaterial
	local mostCommonNum = 0
	for mat, freq in pairs(materialsAroundCell) do
		if freq > mostCommonNum then
			mostCommonNum = freq
			cellDesiredMaterial = mat
		end
	end

	if cellDesiredMaterial ~= materialAir then
		return cellDesiredMaterial
	end

	return initialMaterial
end

return OperationHelper
