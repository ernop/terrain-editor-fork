--!strict
--[[
	FloodPaintTool.lua - Fill connected regions with material
	
	Paints all connected terrain of the same (or any) material
	within the brush area.
]]

local FloodPaintTool = {}

-- ============================================
-- IDENTITY
-- ============================================
FloodPaintTool.id = "FloodPaint"
FloodPaintTool.name = "Flood"
FloodPaintTool.category = "Painting"
FloodPaintTool.buttonLabel = "Flood"

-- ============================================
-- DOCUMENTATION
-- ============================================
FloodPaintTool.docs = {
	title = "Flood",
	subtitle = "Fill area with material",
	
	description = "Replaces material within the brush area. Can replace all materials or only a specific source material.",
	
	sections = {
		{
			heading = "Modes",
			bullets = {
				"**Replace All** — Paint over any material",
				"**Replace Specific** — Only replace chosen material",
			},
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Use specific mode for precision",
		"R — Lock brush position",
	},
	
	docVersion = "2.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
FloodPaintTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"flood",
	"material",
}

-- ============================================
-- OPERATION
-- ============================================
function FloodPaintTool.execute(options: any)
	local writeMaterials = options.writeMaterials
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local targetMaterial = options.floodTargetMaterial or options.desiredMaterial
	local sourceMaterial = options.floodSourceMaterial
	local replaceAll = options.floodReplaceAll
	
	-- Only paint solid terrain
	if cellOccupancy < 0.5 or cellMaterial == Enum.Material.Air then
		return
	end
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Check if we should replace this material
	if replaceAll then
		writeMaterials[voxelX][voxelY][voxelZ] = targetMaterial
	elseif sourceMaterial and cellMaterial == sourceMaterial then
		writeMaterials[voxelX][voxelY][voxelZ] = targetMaterial
	end
end

return FloodPaintTool

