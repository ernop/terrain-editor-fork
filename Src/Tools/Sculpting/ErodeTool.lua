--!strict
--[[
	ErodeTool.lua - Gradually wear away terrain from edges
	
	The opposite of Grow. Shrinks terrain by reducing occupancy
	at surface edges, creating natural weathering effects.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local OperationHelper = require(Plugin.Src.TerrainOperations.OperationHelper)

local materialAir = Enum.Material.Air
local materialWater = Enum.Material.Water

local ErodeTool = {}

-- ============================================
-- IDENTITY
-- ============================================
ErodeTool.id = "Erode"
ErodeTool.name = "Erode"
ErodeTool.category = "Sculpting"
ErodeTool.buttonLabel = "Erode"

-- ============================================
-- DOCUMENTATION
-- ============================================
ErodeTool.docs = {
	title = "Erode",
	subtitle = "Shrink terrain inward from surfaces",
	description = "Reduces voxel occupancy at exposed terrain edges. Opposite of Grow.",
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Ctrl+Scroll — Adjust strength",
		"R — Lock brush position",
	},
	
	docVersion = "2.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
ErodeTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"planeLock",
	"spin",
}

-- ============================================
-- OPERATION
-- ============================================
function ErodeTool.execute(options: any)
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

