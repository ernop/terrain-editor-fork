--!strict
--[[
	OctreeFillOptimization.lua - Spatial decomposition for irregular brush shapes
	
	STATUS: EXPERIMENTAL - NOT YET SAFE FOR PRODUCTION
	
	The idea: Instead of iterating every voxel for Add/Subtract operations, we:
	1. Recursively subdivide the brush region into octants
	2. Octants fully INSIDE the brush → FillBlock (1 API call)
	3. Octants fully OUTSIDE the brush → Skip entirely
	4. Octants on the BOUNDARY → Recurse or per-voxel
	
	KNOWN ISSUES:
	- Corner-checking doesn't guarantee octant interior values
	- Thresholds need proper derivation from OperationHelper.one256th
	- Some brush shapes have sharp internal features (Spikepad cones)
	- Smooth boundary transitions may be lost
	
	TODO before production use:
	1. Use OperationHelper.one256th for air threshold
	2. For solid threshold, must verify brush SDF properties
	3. Add center-point sampling, not just corners
	4. Test thoroughly with all brush shapes
	
	ONLY works for Add/Subtract because:
	- Add: setting occupancy to 1 is the same regardless of existing value
	- Subtract: setting to 0 (Air) is the same regardless of existing value
	- Other tools need to READ existing values first
]]

local Constants = require(script.Parent.Parent.Util.Constants)
local OperationHelper = require(script.Parent.OperationHelper)

local VOXEL_SIZE = Constants.VOXEL_RESOLUTION -- 4 studs
local MIN_OCTANT_SIZE = VOXEL_SIZE * 2 -- Don't subdivide below 2x2x2 voxels (8 studs)

-- SAFETY: Use system-defined threshold for air detection
-- Values at or below this are treated as air by the terrain system
local SDF_AIR_THRESHOLD = OperationHelper.one256th -- 1/256 ≈ 0.0039

-- CAUTION: There is no standard "fully solid" threshold in the system
-- Using 1.0 is safest but means we rarely find "inside" octants
-- Using lower values risks losing smooth boundary transitions
-- This needs proper analysis of each brush shape's SDF characteristics
local SDF_SOLID_THRESHOLD = 1.0 -- Only treat as solid if EXACTLY 1.0

export type SDFFunction = (worldPos: Vector3) -> number

local OctreeFill = {}

--[[
	Check if all 8 corners of a cube are above/below thresholds
	Returns: "inside" | "outside" | "boundary"
]]
local function classifyOctant(sdfFunc: SDFFunction, center: Vector3, halfSize: number): "inside" | "outside" | "boundary"
	local allInside = true
	local allOutside = true

	-- Test all 8 corners
	for dx = -1, 1, 2 do
		for dy = -1, 1, 2 do
			for dz = -1, 1, 2 do
				local corner = center + Vector3.new(dx * halfSize, dy * halfSize, dz * halfSize)
				local sdfValue = sdfFunc(corner)

				if sdfValue < SDF_SOLID_THRESHOLD then
					allInside = false
				end
				if sdfValue > SDF_AIR_THRESHOLD then
					allOutside = false
				end

				-- Early exit if we know it's boundary
				if not allInside and not allOutside then
					return "boundary"
				end
			end
		end
	end

	if allInside then
		return "inside"
	elseif allOutside then
		return "outside"
	else
		return "boundary"
	end
end

--[[
	Recursively fill using octree decomposition
	
	@param terrain - Terrain instance
	@param sdfFunc - Function that returns brush occupancy at world position (0-1)
	@param center - Center of current octant (world coordinates)
	@param size - Size of current octant (studs)
	@param material - Material to fill with (for Add) or Air (for Subtract)
	@param boundaryVoxels - Table to collect boundary voxels for per-voxel processing
]]
local function fillOctantRecursive(
	terrain: Terrain,
	sdfFunc: SDFFunction,
	center: Vector3,
	size: number,
	material: Enum.Material,
	boundaryVoxels: { Vector3 }
)
	local halfSize = size * 0.5
	local classification = classifyOctant(sdfFunc, center, halfSize)

	if classification == "inside" then
		-- This entire octant is fully inside the brush - use FillBlock
		terrain:FillBlock(CFrame.new(center), Vector3.new(size, size, size), material)
		return
	end

	if classification == "outside" then
		-- This entire octant is fully outside the brush - skip it
		return
	end

	-- Boundary case: partially inside
	if size > MIN_OCTANT_SIZE then
		-- Subdivide into 8 smaller octants
		local quarterSize = size * 0.25
		for dx = -1, 1, 2 do
			for dy = -1, 1, 2 do
				for dz = -1, 1, 2 do
					local childCenter = center + Vector3.new(dx * quarterSize, dy * quarterSize, dz * quarterSize)
					fillOctantRecursive(terrain, sdfFunc, childCenter, halfSize, material, boundaryVoxels)
				end
			end
		end
	else
		-- Base case: collect these voxels for per-voxel processing
		-- The octant is small enough that we need individual voxel handling
		local voxelHalf = VOXEL_SIZE * 0.5
		local voxelsPerSide = math.floor(size / VOXEL_SIZE)
		local startOffset = -size * 0.5 + voxelHalf

		for vx = 0, voxelsPerSide - 1 do
			for vy = 0, voxelsPerSide - 1 do
				for vz = 0, voxelsPerSide - 1 do
					local voxelCenter = center
						+ Vector3.new(startOffset + vx * VOXEL_SIZE, startOffset + vy * VOXEL_SIZE, startOffset + vz * VOXEL_SIZE)
					-- Only include if SDF says it's inside the brush
					if sdfFunc(voxelCenter) > SDF_AIR_THRESHOLD then
						table.insert(boundaryVoxels, voxelCenter)
					end
				end
			end
		end
	end
end

--[[
	Main entry point for octree-optimized fill
	
	@param terrain - Terrain instance
	@param opSet - Operation settings (contains brush shape, size, center, etc.)
	@param sdfFunc - SDF function for the brush shape
	@param isSubtract - true for Subtract tool, false for Add tool
	
	@return boundaryVoxels - Array of Vector3 positions that need per-voxel processing
]]
function OctreeFill.fill(
	terrain: Terrain,
	opSet: any, -- OperationSet
	sdfFunc: SDFFunction,
	isSubtract: boolean
): { Vector3 }
	local centerPoint = opSet.centerPoint
	local sizeX = (opSet.cursorSizeX or opSet.cursorSize) * VOXEL_SIZE
	local sizeY = (opSet.cursorSizeY or opSet.cursorHeight or opSet.cursorSize) * VOXEL_SIZE
	local sizeZ = (opSet.cursorSizeZ or opSet.cursorSize) * VOXEL_SIZE

	-- Use the largest dimension as the octree root size (must be power of 2 ideally)
	local maxSize = math.max(sizeX, sizeY, sizeZ)
	-- Round up to nearest power of 2 for clean subdivision
	local rootSize = 2 ^ math.ceil(math.log(maxSize) / math.log(2))

	local material = isSubtract and Enum.Material.Air or opSet.material
	local boundaryVoxels: { Vector3 } = {}

	fillOctantRecursive(terrain, sdfFunc, centerPoint, rootSize, material, boundaryVoxels)

	return boundaryVoxels
end

--[[
	Create an SDF function for a brush shape
	
	This wraps calculateBrushPowerForCellRotated into a simple Vector3 -> number function
]]
function OctreeFill.createSDFForBrush(opSet: any): SDFFunction
	local centerPoint = opSet.centerPoint
	local radiusX = (opSet.cursorSizeX or opSet.cursorSize) * VOXEL_SIZE * 0.5
	local radiusY = (opSet.cursorSizeY or opSet.cursorHeight or opSet.cursorSize) * VOXEL_SIZE * 0.5
	local radiusZ = (opSet.cursorSizeZ or opSet.cursorSize) * VOXEL_SIZE * 0.5
	local brushShape = opSet.brushShape
	local selectionSize = opSet.cursorSizeX or opSet.cursorSize
	local brushRotation = opSet.brushRotation or CFrame.new()
	local hollowEnabled = opSet.hollowEnabled or false
	local wallThickness = opSet.wallThickness or 0.2

	return function(worldPos: Vector3): number
		local cellVector = worldPos - centerPoint
		local brushOccupancy, _ = OperationHelper.calculateBrushPowerForCellRotated(
			cellVector.X,
			cellVector.Y,
			cellVector.Z,
			radiusX,
			radiusY,
			radiusZ,
			brushShape,
			selectionSize,
			true, -- snap to voxel
			brushRotation,
			hollowEnabled,
			wallThickness
		)
		return brushOccupancy
	end
end

--[[
	Performance statistics for debugging
]]
function OctreeFill.getStats(totalVoxelsInRegion: number, boundaryVoxelCount: number, fillBlockCallCount: number): string
	local skippedVoxels = totalVoxelsInRegion - boundaryVoxelCount
	local percentSaved = math.floor(skippedVoxels / totalVoxelsInRegion * 100)
	return string.format(
		"Octree optimization: %d/%d voxels (%d%% saved), %d FillBlock calls",
		boundaryVoxelCount,
		totalVoxelsInRegion,
		percentSaved,
		fillBlockCallCount
	)
end

return OctreeFill
