--!strict
--[[
	FloodPaintTool.lua - Fill connected regions with material
	
	Paints all connected terrain of the same (or any) material
	within the brush area.
]]

local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

type SculptSettings = ToolDocFormat.SculptSettings

local FloodPaintTool = {}

-- ============================================
-- IDENTITY
-- ============================================
FloodPaintTool.id = "FloodPaint"
FloodPaintTool.name = "Flood"
FloodPaintTool.category = "Material"
FloodPaintTool.buttonLabel = "Flood"

-- ============================================
-- TRAITS
-- ============================================
FloodPaintTool.traits = {
	category = "Material",
	executionType = "perVoxel",
	modifiesOccupancy = false,
	modifiesMaterial = true,
	hasFastPath = false,
	hasLargeBrushPath = false,
	requiresGlobalState = false,
	usesBrush = true,
	usesStrength = false,
	needsMaterial = true,
}

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
		{
			heading = "Algorithm",
			bullets = {
				"For each solid voxel in brush region:",
				"  if cellOcc < 0.5 or cellMaterial == Air: skip",
				"  if replaceAll:",
				"    set material = targetMaterial",
				"  elif sourceMaterial and cellMaterial == sourceMaterial:",
				"    set material = targetMaterial",
			},
		},
		{
			heading = "Behavior",
			content = 'Simple material replacement without affecting occupancy. "Replace Specific" mode useful for selective changes (e.g., convert all Grass to Sand without affecting Rock). Does not perform true flood-fill connectivity check—operates on brush region only.',
		},
	},

	quickTips = {
		"Shift+Scroll — Resize brush",
		"Use specific mode for precision",
		"R — Lock brush position",
	},

	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
FloodPaintTool.configPanels = {
	"brushShape",
	"size",
	"brushLock",
	"floodSettings",
	"material",
}

-- ============================================
-- OPERATION
-- ============================================
function FloodPaintTool.execute(options: SculptSettings)
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
