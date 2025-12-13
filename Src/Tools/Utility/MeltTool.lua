--!strict
--[[
	MeltTool.lua - Simulate melting/flowing terrain
	
	Moves terrain downward simulating gravity/melting effects.
	Higher voxels flow down to fill lower areas.
]]

local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

type SculptSettings = ToolDocFormat.SculptSettings

local MeltTool = {}

-- ============================================
-- IDENTITY
-- ============================================
MeltTool.id = "Melt"
MeltTool.name = "Melt"
MeltTool.category = "Utility"
MeltTool.buttonLabel = "Melt"

-- ============================================
-- TRAITS
-- ============================================
MeltTool.traits = {
	category = "Utility",
	executionType = "perVoxel",
	modifiesOccupancy = true,
	modifiesMaterial = false,
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
MeltTool.docs = {
	title = "Melt",
	subtitle = "Simulate terrain flowing downward",

	description = "Transfers occupancy from higher voxels to lower ones, simulating gravity or melting. Creates dripping, sagging effects.",

	sections = {
		{
			heading = "Settings",
			bullets = {
				"**Viscosity** — Flow speed (low = fast melt)",
			},
		},
		{
			heading = "Algorithm",
			bullets = {
				"For each voxel in brush region:",
				"  occBelow = occupancy of voxel at (x, y-1, z)",
				"  if occBelow < cellOcc:",
				"    availableSpace = 1 - occBelow",
				"    flowAmount = min(availableSpace, cellOcc) × (1-viscosity) × brushOcc × 0.3",
				"    cellOcc -= flowAmount",
				"Note: Single-pass approximation; true flow would need iterative simulation",
			},
		},
		{
			heading = "Behavior",
			content = 'Simplified gravity simulation. Material "wants" to flow down but is limited by viscosity and available space below. Multiple brush passes accumulate the effect. Does not truly conserve mass (voxel below receives material in its own pass).',
		},
	},

	quickTips = {
		"Shift+Scroll — Resize brush",
		"Multiple passes = more flow",
		"R — Lock brush position",
	},

	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
MeltTool.configPanels = {
	"brushShape",
	"size",
	"strength",
	"brushRate",
	"pivot",
	"spin",
	"meltViscosity",
}

-- ============================================
-- OPERATION
-- ============================================
function MeltTool.execute(options: SculptSettings)
	local writeOccupancies = options.writeOccupancies
	local readOccupancies = options.readOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local viscosity = options.meltViscosity or 0.5

	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end

	-- Get occupancy below
	local function getOcc(x, y, z)
		if x < 1 or x > sizeX or y < 1 or y > sizeY or z < 1 or z > sizeZ then
			return 1 -- Treat out of bounds as solid
		end
		return readOccupancies[x][y][z]
	end

	local occBelow = getOcc(voxelX, voxelY - 1, voxelZ)

	-- Flow calculation: material moves down if there's room below
	local flowAmount = 0
	if occBelow < cellOccupancy then
		-- How much can flow
		local availableSpace = 1 - occBelow
		local availableMaterial = cellOccupancy
		flowAmount = math.min(availableSpace, availableMaterial) * (1 - viscosity) * brushOccupancy * 0.3
	end

	-- Reduce our occupancy by flow amount
	local newOccupancy = math.max(0, cellOccupancy - flowAmount)
	writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy

	-- Note: The voxel below will receive material in its own execute call
	-- This is a simplified single-pass approach
end

return MeltTool
