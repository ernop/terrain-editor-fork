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
local SculptOperations = require(script.Parent.SculptOperations)

-- Air and water materials are frequently referenced in terrain brush
local materialAir = Enum.Material.Air
local materialWater = Enum.Material.Water

-- Patched: removed LastUsedModificationMethod (Roblox-internal property)

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

	assert(terrain ~= nil, "performTerrainBrushOperation requires a terrain instance")
	assert(tool ~= nil and type(tool) == "string", "performTerrainBrushOperation requires a currentTool parameter")

	-- Calculate bounds - for rotated brushes, we need a larger bounding box
	-- Use the max of all radii to ensure we capture the full rotated brush
	local maxRadius = math.max(radiusX, radiusY, radiusZ)
	local boundsRadius = hasRotation and maxRadius or nil

	local minBounds = Vector3.new(
		OperationHelper.clampDownToVoxel(centerPoint.x - (boundsRadius or radiusX)),
		OperationHelper.clampDownToVoxel(centerPoint.y - (boundsRadius or radiusY)),
		OperationHelper.clampDownToVoxel(centerPoint.z - (boundsRadius or radiusZ))
	)
	local maxBounds = Vector3.new(
		OperationHelper.clampUpToVoxel(centerPoint.x + (boundsRadius or radiusX)),
		OperationHelper.clampUpToVoxel(centerPoint.y + (boundsRadius or radiusY)),
		OperationHelper.clampUpToVoxel(centerPoint.z + (boundsRadius or radiusZ))
	)

	-- LastUsedModificationMethod is a Roblox-internal property, skip it
	-- (Original code tried to set terrain.LastUsedModificationMethod here)

	-- Might be able to do a quick operation through an API call
	-- Note: Quick path works for shapes that support rotated CFrame
	local isUniformSize = (sizeX == sizeY) and (sizeY == sizeZ)
	if (tool == ToolId.Add or (tool == ToolId.Subtract and not ignoreWater)) and not autoMaterial then
		if tool == ToolId.Subtract then
			desiredMaterial = materialAir
		end

		-- Build the rotated CFrame for fill operations
		local fillCFrame = CFrame.new(centerPoint) * brushRotation

		if brushShape == BrushShape.Sphere and isUniformSize and not hasRotation then
			-- Only use FillBall for uniform, non-rotated spheres
			terrain:FillBall(centerPoint, radiusX, desiredMaterial)
			return
		elseif brushShape == BrushShape.Cube then
			-- FillBlock supports rotation via CFrame
			terrain:FillBlock(fillCFrame, Vector3.new(sizeX, sizeY, sizeZ), desiredMaterial)
			return
		elseif brushShape == BrushShape.Cylinder then
			-- Cylinder at Base Size 1 doesn't actually add anything into workspace
			-- To combat this we will use a ballfill instead. At this size the user will see no difference
			if (maxBounds - minBounds).x <= 2 * Constants.VOXEL_RESOLUTION then
				terrain:FillBall(centerPoint, radiusX, desiredMaterial)
				return
			end

			-- FillCylinder: height is sizeY, radius is radiusX (assuming X=Z for cylinder)
			-- Apply rotation to the cylinder CFrame
			terrain:FillCylinder(fillCFrame, sizeY, radiusX, desiredMaterial)
			return
		elseif brushShape == BrushShape.Wedge then
			-- FillWedge: supports rotation via CFrame
			terrain:FillWedge(fillCFrame, Vector3.new(sizeX, sizeY, sizeZ), desiredMaterial)
			return
		end

		-- Shapes that need per-voxel processing:
		-- - Non-uniform/rotated spheres (ellipsoids)
		-- - CornerWedge, Dome (no native API)
		-- - All creative shapes (Torus, Ring, ZigZag, Sheet, Grid, Stick, Spinner)
		if brushShape == BrushShape.Sphere and (not isUniformSize or hasRotation) then
			-- Fall through to main loop for ellipsoid/rotated sphere
		elseif brushShape == BrushShape.CornerWedge or brushShape == BrushShape.Dome then
			-- Fall through to main loop for custom shapes
		elseif brushShape == BrushShape.Torus or brushShape == BrushShape.Ring 
			or brushShape == BrushShape.ZigZag or brushShape == BrushShape.Sheet
			or brushShape == BrushShape.Grid or brushShape == BrushShape.Stick
			or brushShape == BrushShape.Spinner then
			-- Fall through to main loop for creative shapes (all per-voxel)
		else
			-- Unknown shape
			warn("Unknown brush shape in performTerrainBrushOperation: " .. tostring(brushShape))
			return
		end
	end

	local strength = opSet.strength

	local region = Region3.new(minBounds, maxBounds)
	local readMaterials, readOccupancies = terrain:ReadVoxels(region, Constants.VOXEL_RESOLUTION)

	-- As we update a voxel, we don't want to interfere with its neighbours
	-- So we want a readonly copy of all the data
	-- And a writeable copy
	local writeMaterials, writeOccupancies = terrain:ReadVoxels(region, Constants.VOXEL_RESOLUTION)

	if tool == ToolId.Flatten then
		smartColumnSculptBrush(opSet, minBounds, maxBounds, readMaterials, readOccupancies, writeMaterials, writeOccupancies)
		terrain:WriteVoxels(region, Constants.VOXEL_RESOLUTION, writeMaterials, writeOccupancies)
		return
	elseif
		selectionSize > USE_LARGE_BRUSH_MIN_SIZE
		and (tool == ToolId.Grow or tool == ToolId.Erode or tool == ToolId.Flatten or tool == ToolId.Smooth)
	then
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

	local maxBoundsX = maxBounds.x

	local airFillerMaterial = materialAir
	local waterHeight = 0
	if ignoreWater then
		waterHeight, airFillerMaterial = OperationHelper.getWaterHeightAndAirFillerMaterial(readMaterials)
	end

	local voxelCountX = table.getn(readOccupancies)
	local voxelCountY = table.getn(readOccupancies[1])
	local voxelCountZ = table.getn(readOccupancies[1][1])

	-- For legacy compatibility in sculptSettings
	local sizeX = voxelCountX
	local sizeY = voxelCountY
	local sizeZ = voxelCountZ

	local planeNormal = opSet.planeNormal
	local planeNormalX = planeNormal.x
	local planeNormalY = planeNormal.y
	local planeNormalZ = planeNormal.z

	local planePoint = opSet.planePoint
	local planePointX = planePoint.x
	local planePointY = planePoint.y
	local planePointZ = planePoint.z

	-- Many of the sculpt settings are the same for each voxel, so precreate the table
	-- Then for each voxel, set the voxel-specific properties
	local sculptSettings = {
		readMaterials = readMaterials,
		readOccupancies = readOccupancies,
		writeMaterials = writeMaterials,
		writeOccupancies = writeOccupancies,
		sizeX = sizeX,
		sizeY = sizeY,
		sizeZ = sizeZ,
		strength = strength,
		ignoreWater = ignoreWater,
		desiredMaterial = desiredMaterial,
		autoMaterial = autoMaterial,
		filterSize = 1,
		maxOccupancy = 1,
	}

	-- "planeDifference" is the distance from the voxel to the plane defined by planePoint and planeNormal
	-- Calculated as (voxelPosition - planePoint):Dot(planeNormal)
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

				-- Use per-axis radii and rotation for brush power calculation
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
					wallThickness
				)

				local cellOccupancy = occupancy
				local cellMaterial = readMaterials[voxelX][voxelY][voxelZ]

				if ignoreWater and cellMaterial == materialWater then
					cellMaterial = materialAir
					cellOccupancy = 0
				end

				airFillerMaterial = waterHeight >= voxelY and airFillerMaterial or materialAir

				sculptSettings.x = voxelX
				sculptSettings.y = voxelY
				sculptSettings.z = voxelZ
				sculptSettings.brushOccupancy = brushOccupancy
				sculptSettings.magnitudePercent = magnitudePercent
				sculptSettings.cellOccupancy = cellOccupancy
				sculptSettings.cellMaterial = cellMaterial
				sculptSettings.airFillerMaterial = airFillerMaterial

				if tool == ToolId.Add then
					if brushOccupancy > cellOccupancy then
						writeOccupancies[voxelX][voxelY][voxelZ] = brushOccupancy
					end
					if brushOccupancy >= 0.5 and cellMaterial == materialAir then
						local targetMaterial = desiredMaterial
						if autoMaterial then
							targetMaterial = OperationHelper.getMaterialForAutoMaterial(
								readMaterials,
								voxelX,
								voxelY,
								voxelZ,
								sizeX,
								sizeY,
								sizeZ,
								cellMaterial
							)
						end
						writeMaterials[voxelX][voxelY][voxelZ] = targetMaterial
					end
				elseif tool == ToolId.Subtract then
					if cellMaterial ~= materialAir then
						local desiredOccupancy = 1 - brushOccupancy
						if desiredOccupancy < cellOccupancy then
							if desiredOccupancy <= OperationHelper.one256th then
								writeOccupancies[voxelX][voxelY][voxelZ] = airFillerMaterial == materialWater and 1 or 0
								writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
							else
								writeOccupancies[voxelX][voxelY][voxelZ] = desiredOccupancy
							end
						end
					end
				elseif tool == ToolId.Grow then
					SculptOperations.grow(sculptSettings)
				elseif tool == ToolId.Erode then
					SculptOperations.erode(sculptSettings)
				elseif tool == ToolId.Flatten then
					sculptSettings.maxOccupancy = math.abs(planeDifference)
					if planeDifference > Constants.FLATTEN_PLANE_TOLERANCE and flattenMode ~= FlattenMode.Grow then
						SculptOperations.erode(sculptSettings)
					elseif planeDifference < -Constants.FLATTEN_PLANE_TOLERANCE and flattenMode ~= FlattenMode.Erode then
						SculptOperations.grow(sculptSettings)
					end
				elseif tool == ToolId.Paint then
					if brushOccupancy > 0 and cellOccupancy > 0 then
						writeMaterials[voxelX][voxelY][voxelZ] = desiredMaterial
					end
				elseif tool == ToolId.Replace then
					--Using cellMaterial and cellOccupancy creates quirky behaviour with Air Material
					local rawMaterial = readMaterials[voxelX][voxelY][voxelZ]
					if brushOccupancy > 0 and rawMaterial == sourceMaterial then
						writeMaterials[voxelX][voxelY][voxelZ] = targetMaterial
						if rawMaterial == materialAir then
							writeOccupancies[voxelX][voxelY][voxelZ] = brushOccupancy
						end
					end
				elseif tool == ToolId.Smooth then
					SculptOperations.smooth(sculptSettings)
				elseif tool == ToolId.Noise then
					-- Pass world coordinates for noise sampling
					sculptSettings.worldX = worldVectorX
					sculptSettings.worldY = worldVectorY
					sculptSettings.worldZ = worldVectorZ
					sculptSettings.noiseScale = opSet.noiseScale
					sculptSettings.noiseIntensity = opSet.noiseIntensity
					sculptSettings.noiseSeed = opSet.noiseSeed
					SculptOperations.noise(sculptSettings)
				elseif tool == ToolId.Terrace then
					-- Pass world Y coordinate and terrace parameters
					sculptSettings.worldY = worldVectorY
					sculptSettings.stepHeight = opSet.stepHeight
					sculptSettings.stepSharpness = opSet.stepSharpness
					SculptOperations.terrace(sculptSettings)
				elseif tool == ToolId.Cliff then
					-- Pass cell offset from center and cliff parameters
					sculptSettings.cellVectorX = cellVectorX
					sculptSettings.cellVectorZ = cellVectorZ
					sculptSettings.cliffAngle = opSet.cliffAngle
					sculptSettings.cliffDirectionX = opSet.cliffDirectionX
					sculptSettings.cliffDirectionZ = opSet.cliffDirectionZ
					SculptOperations.cliff(sculptSettings)
				elseif tool == ToolId.Path then
					-- Pass cell offset, world position, and path parameters
					sculptSettings.cellVectorX = cellVectorX
					sculptSettings.cellVectorZ = cellVectorZ
					sculptSettings.worldY = worldVectorY
					sculptSettings.centerY = centerPoint.Y
					sculptSettings.pathDirectionX = opSet.pathDirectionX
					sculptSettings.pathDirectionZ = opSet.pathDirectionZ
					sculptSettings.pathDepth = opSet.pathDepth
					sculptSettings.pathProfile = opSet.pathProfile
					-- pathWidth is the half-width (radius) of the path in studs
					sculptSettings.pathWidth = radiusX
					SculptOperations.path(sculptSettings)
				elseif tool == ToolId.Clone then
					-- Pass clone source buffer and centers
					if opSet.cloneSourceBuffer and opSet.cloneSourceCenter then
						sculptSettings.sourceBuffer = opSet.cloneSourceBuffer
						sculptSettings.sourceCenterX = opSet.cloneSourceCenter.X
						sculptSettings.sourceCenterY = opSet.cloneSourceCenter.Y
						sculptSettings.sourceCenterZ = opSet.cloneSourceCenter.Z
						-- Target center is the current voxel position in the region
						sculptSettings.targetCenterX = voxelX
						sculptSettings.targetCenterY = voxelY
						sculptSettings.targetCenterZ = voxelZ
						SculptOperations.clone(sculptSettings)
					end
				elseif tool == ToolId.Blobify then
					-- Pass cell offset and blob parameters
					sculptSettings.cellVectorX = cellVectorX
					sculptSettings.cellVectorY = cellVectorY
					sculptSettings.cellVectorZ = cellVectorZ
					sculptSettings.blobIntensity = opSet.blobIntensity
					sculptSettings.blobSmoothness = opSet.blobSmoothness
					SculptOperations.blobify(sculptSettings)
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
