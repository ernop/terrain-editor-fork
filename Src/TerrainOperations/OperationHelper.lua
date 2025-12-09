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
	brushRotation
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
		scaleMagnitudePercent
	)
end

-- New function supporting per-axis radii for ellipsoid/box brushes
function OperationHelper.calculateBrushPowerForCellAxisAligned(
	cellVectorX,
	cellVectorY,
	cellVectorZ,
	radiusX,
	radiusY,
	radiusZ,
	brushShape,
	selectionSize,
	scaleMagnitudePercent
)
	local brushOccupancy = 1
	local magnitudePercent = 1

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

			magnitudePercent = math.cos(math.min(1, normalizedDistance) * math.pi * 0.5)
			-- Edge falloff: 1.0 at center, 0.0 at edge (normalizedDistance = 1)
			brushOccupancy = math.max(0, math.min(1, (1 - normalizedDistance) * avgRadius / Constants.VOXEL_RESOLUTION))
			-- Clamp brushOccupancy to [0, 1] based on whether we're inside
			if normalizedDistance <= 1 then
				brushOccupancy = math.max(brushOccupancy, 0.01) -- Ensure inside voxels have some occupancy
			end
		elseif brushShape == BrushShape.Cylinder then
			-- Cylinder: X and Z define the radial cross-section, Y is height
			-- Normalize X and Z by radiusX (assuming radiusX = radiusZ for cylinder)
			local normX = cellVectorX / radiusX
			local normZ = cellVectorZ / radiusZ
			local radialDistance = math.sqrt(normX * normX + normZ * normZ)

			-- Check if within height bounds
			local normY = math.abs(cellVectorY) / radiusY
			local insideHeight = normY <= 1

			if insideHeight then
				magnitudePercent = math.cos(math.min(1, radialDistance) * math.pi * 0.5)
				brushOccupancy = math.max(0, math.min(1, (1 - radialDistance) * radiusX / Constants.VOXEL_RESOLUTION))
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

			if maxNorm <= 1 then
				-- Inside the box
				magnitudePercent = math.cos(math.min(1, maxNorm) * math.pi * 0.5)
				brushOccupancy = math.max(0, math.min(1, (1 - maxNorm) * avgRadius / Constants.VOXEL_RESOLUTION))
				brushOccupancy = math.max(brushOccupancy, 0.01)
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
				magnitudePercent = math.cos(math.min(1, 1 - edgeDist) * math.pi * 0.5)
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
				magnitudePercent = math.cos(math.min(1, 1 - edgeDist) * math.pi * 0.5)
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

			-- Only include top half (Y >= 0 in local space)
			if cellVectorY >= 0 and normalizedDistance <= 1 then
				magnitudePercent = math.cos(math.min(1, normalizedDistance) * math.pi * 0.5)
				brushOccupancy = math.max(0, math.min(1, (1 - normalizedDistance) * avgRadius / Constants.VOXEL_RESOLUTION))
				brushOccupancy = math.max(brushOccupancy, 0.01)
			else
				brushOccupancy = 0
				magnitudePercent = 0
			end
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
