--!strict
--[[
	BridgeTool.lua - Create terrain bridges between points
	
	Generates arched or flat bridges connecting two terrain
	points, with configurable curve and width.
]]

local BridgeTool = {}

-- ============================================
-- IDENTITY
-- ============================================
BridgeTool.id = "Bridge"
BridgeTool.name = "Bridge"
BridgeTool.category = "Advanced"
BridgeTool.buttonLabel = "Bridge"

-- ============================================
-- DOCUMENTATION
-- ============================================
BridgeTool.docs = {
	title = "Bridge",
	subtitle = "Connect two points with terrain",
	
	description = "Creates terrain bridges between two points. Set start and end positions, then build the connecting structure.",
	
	sections = {
		{
			heading = "Workflow",
			bullets = {
				"**Click** — Set start point (green marker)",
				"**Click again** — Set end point (orange marker)",
				"**Build** — Generate the bridge",
				"**Clear** — Reset points",
			},
		},
		{
			heading = "Variants",
			bullets = {
				"**Arc** — Curved arch bridge",
				"**Flat** — Straight level bridge",
				"**Suspension** — Dips in middle",
				"**Natural** — Irregular, organic",
			},
		},
		{
			heading = "Algorithm",
			bullets = {
				"Generate path from start to end:",
				"  For t = 0..1 along path:",
				"    basePos = lerp(start, end, t)",
				"    height offset by variant:",
				"      Arc: sin(t×π) × arcHeight",
				"      Suspension: -sin(t×π) × dip",
				"      Natural: fbm noise offset",
				"    Apply meander: perpendicular sine waves",
				"  Sample path at intervals, fill spheres along spine",
			},
		},
		{
			heading = "Meander",
			content = "Adds lateral S-curves perpendicular to path direction. Complexity controls number of sine wave oscillations. Creates natural-looking winding paths instead of straight lines.",
		},
	},
	
	quickTips = {
		"Click twice to set endpoints",
		"Preview shows before building",
		"Meander adds natural curves",
	},
	
	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
BridgeTool.configPanels = {
	"bridge",
	"material",
}

-- ============================================
-- OPERATION
-- ============================================
function BridgeTool.execute(options: any)
	-- Bridge building is handled specially in the main module
	-- This is a placeholder for the tool registry
	local writeMaterials = options.writeMaterials
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local desiredMaterial = options.desiredMaterial
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Add terrain where brush occupancy exceeds current
	if brushOccupancy > cellOccupancy then
		writeOccupancies[voxelX][voxelY][voxelZ] = brushOccupancy
	end
	
	if brushOccupancy >= 0.5 and cellMaterial == Enum.Material.Air then
		writeMaterials[voxelX][voxelY][voxelZ] = desiredMaterial
	end
end

return BridgeTool

