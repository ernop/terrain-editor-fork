--!strict
--[[
	OccupancyOverlayTool.lua - Visualize occupancy values
	
	Non-modifying visualization tool that overlays color-coded
	occupancy values on terrain for debugging and understanding
	terrain structure.
]]

local OccupancyOverlayTool = {}

OccupancyOverlayTool.id = "OccupancyOverlay"
OccupancyOverlayTool.name = "Occupancy Overlay"
OccupancyOverlayTool.category = "Analysis"
OccupancyOverlayTool.buttonLabel = "Overlay"

-- ============================================
-- TRAITS
-- ============================================
OccupancyOverlayTool.traits = {
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
OccupancyOverlayTool.docs = {
	title = "Occupancy Overlay",
	description = "Visualize terrain occupancy values with a color gradient. Shows where terrain is solid, partial, or air.",

	sections = {
		{
			heading = "Purpose",
			content = "Debug tool for understanding terrain surface transitions. See exactly how smooth or sharp your terrain edges are.",
		},
		{
			heading = "Color Guide",
			bullets = {
				"Red = high occupancy (near 1.0, fully solid)",
				"Yellow = medium occupancy (0.5, half-filled)",
				"Green = low occupancy (near 0.0, mostly air)",
				"Transparent = air (0.0)",
			},
		},
	},

	quickTips = {
		"Useful after using Smooth tool",
		"Sharp edges have sudden color changes",
		"Smooth areas have gradual transitions",
		"Can help identify terrain seams",
	},

	relatedTools = { "VoxelInspect", "Smooth" },

	docVersion = "1.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
OccupancyOverlayTool.configPanels = {
	"occupancyOverlayPanel",
}

-- ============================================
-- EXECUTE (no-op for Analysis tools)
-- ============================================
OccupancyOverlayTool.execute = nil

return OccupancyOverlayTool
