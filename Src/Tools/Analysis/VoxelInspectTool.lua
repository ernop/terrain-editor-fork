--!strict
--[[
	VoxelInspectTool.lua - Examine individual voxel data
	
	Non-modifying inspection tool that shows detailed information about
	the terrain voxel under the cursor.
]]

local VoxelInspectTool = {}

VoxelInspectTool.id = "VoxelInspect"
VoxelInspectTool.name = "Voxel Inspect"
VoxelInspectTool.category = "Analysis"
VoxelInspectTool.buttonLabel = "Inspect"

-- ============================================
-- TRAITS
-- ============================================
VoxelInspectTool.traits = {
	category = "Analysis",
	executionType = "uiOnly",
	modifiesOccupancy = false,
	modifiesMaterial = false,
	hasFastPath = false,
	hasLargeBrushPath = false,
	requiresGlobalState = false,
	usesBrush = false,
	usesStrength = false,
	needsMaterial = false,
}

-- ============================================
-- DOCUMENTATION
-- ============================================
VoxelInspectTool.docs = {
	title = "Voxel Inspector",
	description = "Examine terrain voxel data without modifying anything. Shows occupancy, material, and coordinates for the voxel under your cursor.",

	purpose = "Debug tool for understanding terrain structure. Useful when learning how Roblox terrain works or troubleshooting unexpected behavior.",

	usage = [[
1. Select the Voxel Inspect tool
2. Hover over terrain
3. View real-time voxel data in the info panel:
   - World position (studs)
   - Voxel coordinates (integer grid)
   - Occupancy value (0-1)
   - Material enum
   - Neighboring voxel info (optional)]],

	tips = {
		"Occupancy 0 = air, 1 = fully solid",
		"Partial occupancy creates smooth surfaces",
		"Voxel grid is 4 studs per cell",
		"Materials blend at boundaries",
	},

	relatedTools = { "ComponentAnalyzer", "OccupancyOverlay" },

	version = "1.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
VoxelInspectTool.configPanels = {
	-- Panel showing current voxel info (implemented in VoxelInspectPanel.lua)
	"voxelInspectInfo",
}

-- ============================================
-- EXECUTE (no-op for Analysis tools)
-- ============================================
-- Analysis tools don't modify terrain, so execute is nil
VoxelInspectTool.execute = nil

return VoxelInspectTool
