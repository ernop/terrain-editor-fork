--!strict
--[[
	FlattenTool.lua - Level terrain to a horizontal plane
	
	Creates flat surfaces by pushing terrain up or down toward
	a reference plane. Essential for creating building platforms,
	roads, and level areas.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local OperationHelper = require(Plugin.Src.TerrainOperations.OperationHelper)
local Constants = require(Plugin.Src.Util.Constants)
local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

local materialAir = Enum.Material.Air
local materialWater = Enum.Material.Water

type SculptSettings = ToolDocFormat.SculptSettings

local FlattenTool = {}

-- ============================================
-- IDENTITY
-- ============================================
FlattenTool.id = "Flatten"
FlattenTool.name = "Flatten"
FlattenTool.category = "Shape"
FlattenTool.buttonLabel = "Flatten"

-- ============================================
-- TRAITS
-- ============================================
FlattenTool.traits = {
	category = "Shape",
	executionType = "columnBased",
	modifiesOccupancy = true,
	modifiesMaterial = true,
	hasFastPath = false,
	hasLargeBrushPath = false,
	requiresGlobalState = false,
	usesBrush = true,
	usesStrength = true,
	needsMaterial = false,
}

-- ============================================
-- DOCUMENTATION
-- ============================================
FlattenTool.docs = {
	title = "Flatten",
	subtitle = "Level terrain to a reference plane",

	description = "Reduces voxel occupancy above the plane. Fills in voxels below the plane.",

	sections = {
		{
			heading = "Modes",
			bullets = {
				"**Both** — Erode above + fill below",
				"**Erode** — Only reduce above the plane",
				"**Grow** — Only fill below the plane",
			},
		},
		{
			heading = "Algorithm",
			bullets = {
				"planeY = reference plane height (Auto: first click, Manual: slider)",
				"For each voxel at worldY:",
				"  if worldY > planeY + 2: target = 0 (above plane)",
				"  if worldY < planeY - 2: target = 1 (below plane)",
				"  else: target = 0.5 - (worldY - planeY)/4 (transition)",
				"Blend toward target based on mode and strength",
			},
		},
	},

	quickTips = {
		"Shift+Scroll — Resize brush",
		"Ctrl+Scroll — Adjust strength",
		"Click sets plane height (Auto mode)",
	},

	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
FlattenTool.configPanels = {
	"brushShape",
	"size",
	"brushLock",
	"strength",
	"brushRate",
	"pivot",
	"falloff",
	"planeLock",
	"flattenMode",
	"spin",
}

-- ============================================
-- OPERATION
-- ============================================

-- Note: Flatten has special handling in performTerrainBrushOperation.lua
-- that uses smartColumnSculptBrush for optimized column-based flattening.
-- This execute function provides a fallback per-voxel implementation.

function FlattenTool.execute(options: SculptSettings)
	local readMaterials = options.readMaterials
	local readOccupancies = options.readOccupancies
	local writeMaterials = options.writeMaterials
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local ignoreWater = options.ignoreWater
	local desiredMaterial = options.desiredMaterial
	local airFillerMaterial = options.airFillerMaterial or materialAir
	local autoMaterial = options.autoMaterial

	-- Flatten mode determines which direction we allow movement
	local flattenMode = options.flattenMode or "Both"

	-- planeDifference: positive = above plane, negative = below plane
	local planeDifference = options.planeDifference or 0

	-- Skip if brush influence too weak
	if brushOccupancy < 0.5 then
		return
	end

	-- Determine if we should grow or erode based on plane difference
	local shouldErode = planeDifference > Constants.FLATTEN_PLANE_TOLERANCE and flattenMode ~= "Grow"
	local shouldGrow = planeDifference < -Constants.FLATTEN_PLANE_TOLERANCE and flattenMode ~= "Erode"

	if not shouldErode and not shouldGrow then
		return
	end

	-- Max amount we can change is limited by distance from plane
	local maxOccupancy = math.abs(planeDifference)

	if shouldErode then
		-- Erode: reduce occupancy
		if cellOccupancy == 0 then
			return
		end

		local desiredOccupancy = cellOccupancy
		local emptyNeighbor = false
		local neighborOccupancies = 6

		for i = 1, 6 do
			local nx = voxelX + OperationHelper.xOffset[i]
			local ny = voxelY + OperationHelper.yOffset[i]
			local nz = voxelZ + OperationHelper.zOffset[i]

			if nx > 0 and nx <= sizeX and ny > 0 and ny <= sizeY and nz > 0 and nz <= sizeZ then
				local neighbor = readOccupancies[nx][ny][nz]
				if ignoreWater and readMaterials[nx][ny][nz] == materialWater then
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
	elseif shouldGrow then
		-- Grow: increase occupancy
		if cellOccupancy == 1 then
			return
		end

		local desiredOccupancy = cellOccupancy
		local fullNeighbor = false
		local totalNeighbors = 0
		local neighborOccupancies = 0

		for i = 1, 6 do
			local nx = voxelX + OperationHelper.xOffset[i]
			local ny = voxelY + OperationHelper.yOffset[i]
			local nz = voxelZ + OperationHelper.zOffset[i]

			if nx > 0 and nx <= sizeX and ny > 0 and ny <= sizeY and nz > 0 and nz <= sizeZ then
				local neighbor = readOccupancies[nx][ny][nz]
				if ignoreWater and readMaterials[nx][ny][nz] == materialWater then
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
end

return FlattenTool
