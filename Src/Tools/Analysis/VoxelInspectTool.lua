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

	sections = {
		{
			heading = "Purpose",
			content = "Debug tool for understanding terrain structure. Useful when learning how Roblox terrain works or troubleshooting unexpected behavior.",
		},
		{
			heading = "Usage",
			bullets = {
				"Select the Voxel Inspect tool",
				"Hover over terrain to see real-time voxel data",
				"View world position, voxel coordinates, occupancy, material, and neighbors",
			},
		},
	},

	quickTips = {
		"Occupancy 0 = air, 1 = fully solid",
		"Partial occupancy creates smooth surfaces",
		"Voxel grid is 4 studs per cell",
		"Materials blend at boundaries",
	},

	relatedTools = { "ComponentAnalyzer", "OccupancyOverlay" },

	docVersion = "1.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
VoxelInspectTool.configPanels = {
	-- Panel showing current voxel info (implemented in AdvancedPanels.lua)
	"voxelInspectPanel",
}

-- ============================================
-- EXECUTE (no-op for Analysis tools)
-- ============================================
-- Analysis tools don't modify terrain, so execute is nil
VoxelInspectTool.execute = nil

return VoxelInspectTool
