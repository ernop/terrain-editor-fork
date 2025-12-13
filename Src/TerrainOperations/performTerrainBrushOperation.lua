--!strict

local Plugin = script.Parent.Parent.Parent

local Constants = require(Plugin.Src.Util.Constants)
local TerrainEnums = require(Plugin.Src.Util.TerrainEnums)
local BrushShape = TerrainEnums.BrushShape
local FlattenMode = TerrainEnums.FlattenMode
local ToolId = TerrainEnums.ToolId

local applyPivot = require(Plugin.Src.Util.applyPivot)

local OperationHelper = require(script.Parent.OperationHelper)
local smartLargeSculptBrush = require(script.Parent.smartLargeSculptBrush)
local smartColumnSculptBrush = require(script.Parent.smartColumnSculptBrush)

-- Tool Registry for unified tool execution
local ToolRegistry = require(Plugin.Src.Tools.ToolRegistry)

-- Air and water materials are frequently referenced in terrain brush
local materialAir = Enum.Material.Air
local materialWater = Enum.Material.Water

-- Once the brush size > this, use the floodfill based large brush implementation
local USE_LARGE_BRUSH_MIN_SIZE = 32

local DEBUG_LOG_OPERATION_TIME = false

--[[
dict opSet =
	ToolId currentTool

	BrushShape brushShape
	FlattenMode flattenMode
	PivotType pivot

	Vector3 centerPoint
	Vector3 planePoint
	Vector3 planeNormal

	number cursorSizeX (new)
	number cursorSizeY (new)
	number cursorSizeZ (new)
	number cursorSize (legacy, defaults to cursorSizeX)
	number cursorHeight (legacy, defaults to cursorSizeY)
	number strength

	bool autoMaterial
	Material material

	Material sourceMaterial
	Material targetMaterial
]]

local function performOperation(terrain, opSet)
	local tool = opSet.currentTool
	local brushShape = opSet.brushShape

	-- Support both new per-axis sizing and legacy uniform sizing
	local sizeX = (opSet.cursorSizeX or opSet.cursorSize) * Constants.VOXEL_RESOLUTION
	local sizeY = (opSet.cursorSizeY or opSet.cursorHeight or opSet.cursorSize) * Constants.VOXEL_RESOLUTION
	local sizeZ = (opSet.cursorSizeZ or opSet.cursorSize) * Constants.VOXEL_RESOLUTION

	-- For legacy code compatibility
	local selectionSize = opSet.cursorSizeX or opSet.cursorSize

	-- Half-sizes (radii) for each axis
	local radiusX = sizeX * 0.5
	local radiusY = sizeY * 0.5
	local radiusZ = sizeZ * 0.5

	local centerPoint = opSet.centerPoint
	centerPoint = applyPivot(opSet.pivot, centerPoint, sizeY)

	local autoMaterial = opSet.autoMaterial
	local desiredMaterial = opSet.material
	local sourceMaterial = opSet.source
	local targetMaterial = opSet.target

	local ignoreWater = opSet.ignoreWater

	-- Get brush rotation (default to identity if not provided)
	local brushRotation = opSet.brushRotation or CFrame.new()
	local hasRotation = brushRotation ~= CFrame.new()

	-- Hollow mode
	local hollowEnabled = opSet.hollowEnabled or false
	local wallThickness = opSet.wallThickness or 0.2

	-- Falloff curve type (controls how brush strength fades from center to edge)
	local falloffType = opSet.falloffType or "Cosine"
	-- Falloff extent: how far the falloff region extends beyond the brush edge
	-- 0 = falloff only within brush, 1 = falloff extends 100% beyond brush radius
	local falloffExtent = opSet.falloffExtent or 0

	assert(terrain ~= nil, "performTerrainBrushOperation requires a terrain instance")
	assert(tool ~= nil and type(tool) == "string", "performTerrainBrushOperation requires a currentTool parameter")

	-- Get tool definition from registry
	local toolDef = ToolRegistry.getTool(tool)

	-- ============================================================================
	-- Fast Path: Check if tool has a fast path and can use it
	-- ============================================================================
	if toolDef and toolDef.canUseFastPath and toolDef.fastPath then
		if toolDef.canUseFastPath(opSet) then
			local success = toolDef.fastPath(terrain, opSet)
			if success then
				return -- Fast path succeeded, we're done
			end
			-- Fast path returned false, fall through to per-voxel processing
		end
	end

	-- Calculate bounds - for rotated brushes, we need a larger bounding box
	-- Use the max of all radii to ensure we capture the full rotated brush
	local maxRadius = math.max(radiusX, radiusY, radiusZ)
	local boundsRadius = hasRotation and maxRadius or nil

	-- Expand bounds to include falloff region (falloffExtent is 0-1, representing % of brush radius)
	local falloffExpansionX = radiusX * falloffExtent
	local falloffExpansionY = radiusY * falloffExtent
	local falloffExpansionZ = radiusZ * falloffExtent

	local minBounds = Vector3.new(
		OperationHelper.clampDownToVoxel(centerPoint.x - (boundsRadius or radiusX) - falloffExpansionX),
		OperationHelper.clampDownToVoxel(centerPoint.y - (boundsRadius or radiusY) - falloffExpansionY),
		OperationHelper.clampDownToVoxel(centerPoint.z - (boundsRadius or radiusZ) - falloffExpansionZ)
	)
	local maxBounds = Vector3.new(
		OperationHelper.clampUpToVoxel(centerPoint.x + (boundsRadius or radiusX) + falloffExpansionX),
		OperationHelper.clampUpToVoxel(centerPoint.y + (boundsRadius or radiusY) + falloffExpansionY),
		OperationHelper.clampUpToVoxel(centerPoint.z + (boundsRadius or radiusZ) + falloffExpansionZ)
	)

	local strength = opSet.strength

	local region = Region3.new(minBounds, maxBounds)
	local readMaterials, readOccupancies = terrain:ReadVoxels(region, Constants.VOXEL_RESOLUTION)

	-- As we update a voxel, we don't want to interfere with its neighbours
	-- So we want a readonly copy of all the data
	-- And a writeable copy
	local writeMaterials, writeOccupancies = terrain:ReadVoxels(region, Constants.VOXEL_RESOLUTION)

	-- Special handling for Flatten tool (uses column-based approach)
	if tool == ToolId.Flatten then
		smartColumnSculptBrush(opSet, minBounds, maxBounds, readMaterials, readOccupancies, writeMaterials, writeOccupancies)
		terrain:WriteVoxels(region, Constants.VOXEL_RESOLUTION, writeMaterials, writeOccupancies)
		return
	end

	-- Large brush optimization for specific tools
	if selectionSize > USE_LARGE_BRUSH_MIN_SIZE and (tool == ToolId.Grow or tool == ToolId.Erode or tool == ToolId.Smooth) then
		smartLargeSculptBrush(opSet, minBounds, maxBounds, readMaterials, readOccupancies, writeMaterials, writeOccupancies)
		terrain:WriteVoxels(region, Constants.VOXEL_RESOLUTION, writeMaterials, writeOccupancies)
		return
	end

	local flattenMode = opSet.flattenMode

	local centerX = centerPoint.x
	local centerY = centerPoint.y
	local centerZ = centerPoint.z

	local minBoundsX = minBounds.x
	local minBoundsY = minBounds.y
	local minBoundsZ = minBounds.z

	local airFillerMaterial = materialAir
	local waterHeight = 0
	if ignoreWater then
		waterHeight, airFillerMaterial = OperationHelper.getWaterHeightAndAirFillerMaterial(readMaterials)
	end

	local voxelCountX = #readOccupancies
	local voxelCountY = #readOccupancies[1]
	local voxelCountZ = #readOccupancies[1][1]

	-- Region dimensions for tool settings
	local regionSizeX = voxelCountX
	local regionSizeY = voxelCountY
	local regionSizeZ = voxelCountZ

	local planeNormal = opSet.planeNormal
	local planeNormalX = planeNormal.x
	local planeNormalY = planeNormal.y
	local planeNormalZ = planeNormal.z

	local planePoint = opSet.planePoint
	local planePointX = planePoint.x
	local planePointY = planePoint.y
	local planePointZ = planePoint.z

	-- Get the tool's execute function from registry
	local toolExecute = toolDef and toolDef.execute or nil

	-- Base settings that are the same for each voxel
	local sculptSettings = {
		-- Read/Write buffers
		readMaterials = readMaterials,
		readOccupancies = readOccupancies,
		writeMaterials = writeMaterials,
		writeOccupancies = writeOccupancies,

		-- Region dimensions
		sizeX = regionSizeX,
		sizeY = regionSizeY,
		sizeZ = regionSizeZ,

		-- Brush/cursor size in voxels
		cursorSizeX = opSet.cursorSizeX or opSet.cursorSize,
		cursorSizeY = opSet.cursorSizeY or opSet.cursorHeight or opSet.cursorSize,
		cursorSizeZ = opSet.cursorSizeZ or opSet.cursorSize,

		-- Operation parameters
		strength = strength,
		ignoreWater = ignoreWater,
		desiredMaterial = desiredMaterial,
		autoMaterial = autoMaterial,
		filterSize = 1,
		maxOccupancy = 1,

		-- Tool-specific parameters (pass everything from opSet)
		noiseScale = opSet.noiseScale,
		noiseIntensity = opSet.noiseIntensity,
		noiseSeed = opSet.noiseSeed,
		stepHeight = opSet.stepHeight,
		stepSharpness = opSet.stepSharpness,
		cliffAngle = opSet.cliffAngle,
		cliffDirectionX = opSet.cliffDirectionX,
		cliffDirectionZ = opSet.cliffDirectionZ,
		pathDepth = opSet.pathDepth,
		pathProfile = opSet.pathProfile,
		pathDirectionX = opSet.pathDirectionX,
		pathDirectionZ = opSet.pathDirectionZ,
		blobIntensity = opSet.blobIntensity,
		blobSmoothness = opSet.blobSmoothness,
		slopeFlatMaterial = opSet.slopeFlatMaterial,
		slopeSteepMaterial = opSet.slopeSteepMaterial,
		slopeCliffMaterial = opSet.slopeCliffMaterial,
		slopeThreshold1 = opSet.slopeThreshold1,
		slopeThreshold2 = opSet.slopeThreshold2,
		clusterSize = opSet.clusterSize,
		materialPalette = opSet.materialPalette,
		megarandomizeSeed = opSet.megarandomizeSeed,
		cavitySensitivity = opSet.cavitySensitivity,
		meltViscosity = opSet.meltViscosity,
		gradientMaterial1 = opSet.gradientMaterial1,
		gradientMaterial2 = opSet.gradientMaterial2,
		gradientStartX = opSet.gradientStartX,
		gradientStartZ = opSet.gradientStartZ,
		gradientEndX = opSet.gradientEndX,
		gradientEndZ = opSet.gradientEndZ,
		gradientNoiseAmount = opSet.gradientNoiseAmount,
		gradientSeed = opSet.gradientSeed or opSet.noiseSeed,
		floodTargetMaterial = opSet.floodTargetMaterial,
		floodSourceMaterial = opSet.floodSourceMaterial,
		stalactiteDirection = opSet.stalactiteDirection,
		stalactiteDensity = opSet.stalactiteDensity,
		stalactiteLength = opSet.stalactiteLength,
		stalactiteTaper = opSet.stalactiteTaper,
		stalactiteSeed = opSet.stalactiteSeed or opSet.noiseSeed,
		tendrilRadius = opSet.tendrilRadius,
		tendrilBranches = opSet.tendrilBranches,
		tendrilLength = opSet.tendrilLength,
		tendrilCurl = opSet.tendrilCurl,
		tendrilSeed = opSet.tendrilSeed or opSet.noiseSeed,
		symmetryType = opSet.symmetryType,
		symmetrySegments = opSet.symmetrySegments,
		gridCellSize = opSet.gridCellSize,
		gridVariation = opSet.gridVariation,
		gridSeed = opSet.gridSeed,
		growthRate = opSet.growthRate,
		growthBias = opSet.growthBias,
		growthPattern = opSet.growthPattern,
		growthSeed = opSet.growthSeed,
		cloneSourceBuffer = opSet.cloneSourceBuffer,
		cloneSourceCenter = opSet.cloneSourceCenter,
		sourceBuffer = opSet.cloneSourceBuffer, -- Legacy alias
		sourceCenterX = opSet.cloneSourceCenter and opSet.cloneSourceCenter.X or nil,
		sourceCenterY = opSet.cloneSourceCenter and opSet.cloneSourceCenter.Y or nil,
		sourceCenterZ = opSet.cloneSourceCenter and opSet.cloneSourceCenter.Z or nil,
		pathWidth = radiusX,
	}

	-- "planeDifference" is the distance from the voxel to the plane defined by planePoint and planeNormal
	for voxelX, occupanciesX in ipairs(readOccupancies) do
		local worldVectorX = minBoundsX + ((voxelX - 0.5) * Constants.VOXEL_RESOLUTION)
		local cellVectorX = worldVectorX - centerX
		local planeDifferenceX = (worldVectorX - planePointX) * planeNormalX

		for voxelY, occupanciesY in ipairs(occupanciesX) do
			local worldVectorY = minBoundsY + (voxelY - 0.5) * Constants.VOXEL_RESOLUTION
			local cellVectorY = worldVectorY - centerY
			local planeDifferenceXY = planeDifferenceX + ((worldVectorY - planePointY) * planeNormalY)

			for voxelZ, occupancy in ipairs(occupanciesY) do
				local worldVectorZ = minBoundsZ + (voxelZ - 0.5) * Constants.VOXEL_RESOLUTION
				local cellVectorZ = worldVectorZ - centerZ
				local planeDifference = planeDifferenceXY + ((worldVectorZ - planePointZ) * planeNormalZ)

				-- Calculate brush influence at this voxel
				local brushOccupancy, magnitudePercent = OperationHelper.calculateBrushPowerForCellRotated(
					cellVectorX,
					cellVectorY,
					cellVectorZ,
					radiusX,
					radiusY,
					radiusZ,
					brushShape,
					selectionSize,
					not (tool == ToolId.Smooth),
					brushRotation,
					hollowEnabled,
					wallThickness,
					falloffType
				)

				local cellOccupancy = occupancy
				local cellMaterial = readMaterials[voxelX][voxelY][voxelZ]

				if ignoreWater and cellMaterial == materialWater then
					cellMaterial = materialAir
					cellOccupancy = 0
				end

				airFillerMaterial = waterHeight >= voxelY and airFillerMaterial or materialAir

				-- Update per-voxel settings
				sculptSettings.x = voxelX
				sculptSettings.y = voxelY
				sculptSettings.z = voxelZ
				sculptSettings.brushOccupancy = brushOccupancy
				sculptSettings.magnitudePercent = magnitudePercent
				sculptSettings.cellOccupancy = cellOccupancy
				sculptSettings.cellMaterial = cellMaterial
				sculptSettings.airFillerMaterial = airFillerMaterial

				-- World coordinates
				sculptSettings.worldX = worldVectorX
				sculptSettings.worldY = worldVectorY
				sculptSettings.worldZ = worldVectorZ

				-- Center coordinates (for tools that need them)
				sculptSettings.centerX = centerX
				sculptSettings.centerY = centerY
				sculptSettings.centerZ = centerZ
				sculptSettings.centerPoint = centerPoint -- Vector3 for tools that need it

				-- Cell vectors (offset from brush center)
				sculptSettings.cellVectorX = cellVectorX
				sculptSettings.cellVectorY = cellVectorY
				sculptSettings.cellVectorZ = cellVectorZ

				-- Clone tool target center
				sculptSettings.targetCenterX = voxelX
				sculptSettings.targetCenterY = voxelY
				sculptSettings.targetCenterZ = voxelZ

				-- For Flatten tool (handles its own grow/erode logic)
				if tool == ToolId.Flatten then
					sculptSettings.maxOccupancy = math.abs(planeDifference)
					-- Flatten is handled by smartColumnSculptBrush above, this is fallback
				end

				-- Execute the tool's operation via registry
				if toolExecute then
					toolExecute(sculptSettings)
				else
					-- Fallback warning for unregistered tools
					if tool ~= ToolId.None then
						warn("[TerrainBrush] No execute function found for tool:", tool)
					end
				end
			end
		end
	end

	terrain:WriteVoxels(region, Constants.VOXEL_RESOLUTION, writeMaterials, writeOccupancies)
end

if DEBUG_LOG_OPERATION_TIME then
	return function(...)
		local startTime = tick()
		performOperation(...)
		local endTime = tick()
		print("Operation took", endTime - startTime)
	end
else
	return performOperation
end
