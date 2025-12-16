--!strict
--[[
	GrowTool.lua - Expand existing terrain outward
	
	Unlike Add which creates terrain anywhere, Grow only expands 
	from existing surfaces. Creates natural, organic growth patterns.
]]

local Src = script:FindFirstAncestor("Src")
local OperationHelper = require(Src.TerrainOperations.OperationHelper)
local ToolDocFormat = require(Src.Tools.ToolDocFormat)

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
				"  Skip if already full (occ = 1) or weak brush (< 0.5)",
				"  Sample 6 face-neighbors (±X, ±Y, ±Z)",
				"  neighborAvg = sum(neighbors) / count",
				"  if cell has occ > 0 OR any neighbor is full:",
				"    delta = neighborAvg × (strength + 0.1) × 0.25 × brushOcc",
				"    cellOcc += delta",
				"  if growing into Air: set material (auto or selected)",
			},
		},
		{
			heading = "Emphasize Center",
			content = "When enabled, applies full growth strength at the brush center (mouse position) with falloff for areas further from the camera. This helps fill holes evenly—the center fills first instead of the sides growing out before the center is reached.",
		},
		{
			heading = "Behavior",
			content = "Expands from existing edges using neighbor averaging. Interior voxels (already at 1.0) unchanged. Requires at least one solid neighbor or existing partial fill. AutoMaterial copies from nearby terrain.",
		},
	},

	quickTips = {
		"Shift+Scroll — Resize brush",
		"Ctrl+Scroll — Adjust strength",
		"L — Lock brush position",
		"Emphasize Center — Helps fill holes from front to back",
	},

	docVersion = "2.3",
}

-- ============================================
-- CONFIGURATION
-- ============================================
GrowTool.configPanels = {
	"brushShape",
	"brushSize",
	"brushLock",
	"strength",
	"brushRate",
	"pivot",
	"falloff",
	"planeLock",
	"spin",
	"emphasizeBrushCenter",
	"autoMaterial",
	"material",
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

	-- Emphasize brush center: depth falloff along view direction
	local emphasizeBrushCenter = options.emphasizeBrushCenter
	local cameraPosition = options.cameraPosition
	local centerPoint = options.centerPoint
	local worldX = options.worldX
	local worldY = options.worldY
	local worldZ = options.worldZ

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
		local growthDelta = neighborOccupancies * (strength + 0.1) * 0.25 * brushOccupancy * magnitudePercent

		-- Apply depth-based falloff when emphasizeBrushCenter is enabled
		if emphasizeBrushCenter and cameraPosition and centerPoint then
			-- Calculate view direction from camera to brush center
			local viewDir = (centerPoint - cameraPosition)
			local viewDirMagnitude = viewDir.Magnitude
			if viewDirMagnitude > 0.001 then
				viewDir = viewDir / viewDirMagnitude -- Normalize

				-- Calculate this voxel's world position
				local voxelPos = Vector3.new(worldX, worldY, worldZ)

				-- Calculate depth: how far this voxel is from brush center along view direction
				-- Positive = further from camera (behind brush center)
				-- Negative = closer to camera (in front of brush center)
				local depthOffset = (voxelPos - centerPoint):Dot(viewDir)

				-- Apply falloff for voxels behind the brush center
				-- Use the larger brush dimension as the falloff range
				local cursorSizeX = options.cursorSizeX or 8
				local cursorSizeY = options.cursorSizeY or 8
				local cursorSizeZ = options.cursorSizeZ or 8
				local maxDepthRange = math.max(cursorSizeX, cursorSizeY, cursorSizeZ) * 2 -- studs

				if depthOffset > 0 then
					-- Voxel is behind brush center (further from camera)
					-- Apply falloff: 1.0 at center, 0.0 at maxDepthRange
					local depthFalloff = 1 - math.min(depthOffset / maxDepthRange, 1)
					-- Use squared falloff for a more gradual curve
					depthFalloff = depthFalloff * depthFalloff
					growthDelta = growthDelta * depthFalloff
				end
				-- Voxels in front of brush center (depthOffset <= 0) get full strength
			end
		end

		desiredOccupancy = desiredOccupancy + growthDelta
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
