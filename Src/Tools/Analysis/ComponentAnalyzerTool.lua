--!strict
--[[
	ComponentAnalyzerTool.lua - Find disconnected terrain islands
	
	Non-modifying analysis tool that identifies separate connected
	components in terrain, useful for finding floating islands or
	disconnected pieces.
]]

local ComponentAnalyzerTool = {}

ComponentAnalyzerTool.id = "ComponentAnalyzer"
ComponentAnalyzerTool.name = "Component Analyzer"
ComponentAnalyzerTool.category = "Analysis"
ComponentAnalyzerTool.buttonLabel = "Components"

-- ============================================
-- TRAITS
-- ============================================
ComponentAnalyzerTool.traits = {
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
ComponentAnalyzerTool.docs = {
	title = "Component Analyzer",
	description = "Find and visualize disconnected terrain islands. Identifies separate connected components in your terrain for cleanup or inspection.",

	purpose = "Identify floating terrain chunks, orphaned pieces, or verify that terrain is properly connected. Essential for polishing terrain before publishing.",

	usage = [[
1. Select the Component Analyzer tool
2. Click "Analyze" to scan terrain
3. View results:
   - Number of separate components
   - Size of each component (voxel count)
   - Bounding box of each component
4. Click on a component to highlight it
5. Use other tools to connect or remove islands]],

	tips = {
		"Run after major terrain edits",
		"Small components are often debris",
		"Use Add tool to connect islands",
		"Use Subtract to remove unwanted floating pieces",
	},

	relatedTools = { "VoxelInspect", "OccupancyOverlay" },

	version = "1.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
ComponentAnalyzerTool.configPanels = {
	"componentAnalyzerPanel",
}

-- ============================================
-- EXECUTE (no-op for Analysis tools)
-- ============================================
ComponentAnalyzerTool.execute = nil

return ComponentAnalyzerTool
