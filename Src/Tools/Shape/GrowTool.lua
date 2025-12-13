--!strict
--[[
	GrowTool.lua - Expand existing terrain outward
	
	Unlike Add which creates terrain anywhere, Grow only expands 
	from existing surfaces. Creates natural, organic growth patterns.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local OperationHelper = require(Plugin.Src.TerrainOperations.OperationHelper)
local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

local materialAir = Enum.Material.Air
local materialWater = Enum.Material.Water

type SculptSettings = ToolDocFormat.SculptSettings

local GrowTool = {}

-- ============================================
-- IDENTITY
-- ============================================
GrowTool.id = "Grow"
GrowTool.name = "Grow"
GrowTool.category = "Shape"
GrowTool.buttonLabel = "Grow"

-- ============================================
-- TRAITS
-- ============================================
GrowTool.traits = {
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
GrowTool.docs = {
	title = "Grow",
	subtitle = "Expand terrain outward from surfaces",
	description = "Increases voxel occupancy near existing terrain edges. Only affects voxels adjacent to solid terrain.",

	sections = {
		{
			heading = "Algorithm",
			bullets = {
				"For each voxel in brush region:",
				"  Sample 6 face-neighbors (±X, ±Y, ±Z)",
				"  neighborMax = max occupancy of neighbors",
				"  if neighborMax > cellOcc:",
				"    delta = (neighborMax - cellOcc) × strength × brushOcc",
				"    cellOcc += delta",
				"Material propagates from highest-occupancy neighbor",
			},
		},
		{
			heading = "Behavior",
			content = "Only expands from existing edges. Interior voxels (already at 1.0) and isolated air (no solid neighbors) are unchanged. Creates smooth, organic expansion.",
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
GrowTool.configPanels = {
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
function GrowTool.execute(options: SculptSettings)
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
	local cellMaterial = options.cellMaterial
	local desiredMaterial = options.desiredMaterial
	local maxOccupancy = options.maxOccupancy or 1
	local autoMaterial = options.autoMaterial

	-- Skip if already full or brush influence too weak
	if cellOccupancy == 1 or brushOccupancy < 0.5 then
		return
	end

	local desiredOccupancy = cellOccupancy
	local fullNeighbor = false
	local totalNeighbors = 0
	local neighborOccupancies = 0

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

			if neighbor >= 1 then
				fullNeighbor = true
			end

			totalNeighbors = totalNeighbors + 1
			neighborOccupancies = neighborOccupancies + neighbor
		end
	end

	-- Only grow if cell has some occupancy OR has a full neighbor
	if cellOccupancy > 0 or fullNeighbor then
		neighborOccupancies = totalNeighbors == 0 and 0 or neighborOccupancies / totalNeighbors
		desiredOccupancy = desiredOccupancy + neighborOccupancies * (strength + 0.1) * 0.25 * brushOccupancy * magnitudePercent
	end

	desiredOccupancy = math.min(desiredOccupancy, maxOccupancy)

	-- Set material if growing into air
	if cellMaterial == materialAir and desiredOccupancy > 0 then
		local targetMaterial = desiredMaterial
		if autoMaterial then
			targetMaterial =
				OperationHelper.getMaterialForAutoMaterial(readMaterials, voxelX, voxelY, voxelZ, sizeX, sizeY, sizeZ, cellMaterial)
		end
		writeMaterials[voxelX][voxelY][voxelZ] = targetMaterial
	end

	-- Update occupancy if changed
	if desiredOccupancy ~= cellOccupancy then
		writeOccupancies[voxelX][voxelY][voxelZ] = desiredOccupancy
	end
end

return GrowTool
