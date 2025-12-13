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

	purpose = "Debug tool for understanding terrain surface transitions. See exactly how smooth or sharp your terrain edges are.",

	usage = [[
1. Select the Occupancy Overlay tool
2. Toggle overlay on
3. View color-coded terrain:
   - Red = high occupancy (near 1.0)
   - Yellow = medium occupancy (0.5)
   - Green = low occupancy (near 0.0)
   - Transparent = air (0.0)
4. Adjust visualization range as needed
5. Toggle off when done]],

	tips = {
		"Useful after using Smooth tool",
		"Sharp edges have sudden color changes",
		"Smooth areas have gradual transitions",
		"Can help identify terrain seams",
	},

	relatedTools = { "VoxelInspect", "Smooth" },

	version = "1.0",
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
