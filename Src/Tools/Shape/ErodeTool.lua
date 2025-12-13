--!strict
--[[
	ErodeTool.lua - Gradually wear away terrain from edges
	
	The opposite of Grow. Shrinks terrain by reducing occupancy
	at surface edges, creating natural weathering effects.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local OperationHelper = require(Plugin.Src.TerrainOperations.OperationHelper)
local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

local materialAir = Enum.Material.Air
local materialWater = Enum.Material.Water

type SculptSettings = ToolDocFormat.SculptSettings

local ErodeTool = {}

-- ============================================
-- IDENTITY
-- ============================================
ErodeTool.id = "Erode"
ErodeTool.name = "Erode"
ErodeTool.category = "Shape"
ErodeTool.buttonLabel = "Erode"

-- ============================================
-- TRAITS
-- ============================================
ErodeTool.traits = {
	category = "Shape",
	executionType = "perVoxel",
	modifiesOccupancy = true,
	modifiesMaterial = true,
	hasFastPath = false,
	hasLargeBrushPath = true,
	requiresGlobalState = false,
	usesBrush = true,
	usesStrength = true,
	needsMaterial = false,
}

-- ============================================
-- DOCUMENTATION
-- ============================================
ErodeTool.docs = {
	title = "Erode",
	subtitle = "Shrink terrain inward from surfaces",
	description = "Reduces voxel occupancy at exposed terrain edges. Opposite of Grow.",
	
	sections = {
		{
			heading = "Algorithm",
			bullets = {
				"For each voxel in brush region:",
				"  Sample 6 face-neighbors",
				"  neighborMin = min occupancy of neighbors",
				"  if neighborMin < cellOcc:",
				"    delta = (cellOcc - neighborMin) × strength × brushOcc",
				"    cellOcc -= delta",
				"  if cellOcc ≤ 1/256: set to Air",
			},
		},
		{
			heading = "Behavior",
			content = "Only erodes exposed surfaces. Fully surrounded voxels (all neighbors solid) are protected. Creates natural weathering patterns.",
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Ctrl+Scroll — Adjust strength",
		"R — Lock brush position",
	},
	
	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
ErodeTool.configPanels = {
	"brushShape",
	"size",
	"strength",
	"brushRate",
	"pivot",
	"falloff",
	"planeLock",
	"spin",
}

-- ============================================
-- OPERATION
-- ============================================
function ErodeTool.execute(options: SculptSettings)
	local readMaterials = options.readMaterials
	local readOccupancies = options.readOccupancies
	local writeMaterials = options.writeMaterials
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local strength = options.strength
	local ignoreWater = options.ignoreWater
	local airFillerMaterial = options.airFillerMaterial or materialAir
	local maxOccupancy = options.maxOccupancy or 1

	-- Skip if already empty or brush influence too weak
	if cellOccupancy == 0 or brushOccupancy <= 0.5 then
		return
	end

	local desiredOccupancy = cellOccupancy
	local emptyNeighbor = false
	local neighborOccupancies = 6
	
	-- Check all 6 cardinal neighbors
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

	-- Only erode if cell is partially filled OR has an empty neighbor
	if cellOccupancy < 1 or emptyNeighbor then
		desiredOccupancy = desiredOccupancy - (neighborOccupancies / 6) * (strength + 0.1) * 0.25 * brushOccupancy * magnitudePercent
	end

	desiredOccupancy = math.min(desiredOccupancy, maxOccupancy)

	-- Apply the erosion
	if desiredOccupancy <= OperationHelper.one256th then
		writeOccupancies[voxelX][voxelY][voxelZ] = airFillerMaterial == materialWater and 1 or 0
		writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
	else
		writeOccupancies[voxelX][voxelY][voxelZ] = desiredOccupancy
	end
end

return ErodeTool

