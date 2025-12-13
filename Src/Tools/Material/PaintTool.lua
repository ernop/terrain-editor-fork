--!strict
--[[
	PaintTool.lua - Change terrain material without affecting shape
	
	The essential material painting tool. Changes the material of
	existing terrain without modifying its shape or occupancy.
]]

local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

local materialAir = Enum.Material.Air

type SculptSettings = ToolDocFormat.SculptSettings

local PaintTool = {}

-- ============================================
-- IDENTITY
-- ============================================
PaintTool.id = "Paint"
PaintTool.name = "Paint"
PaintTool.category = "Material"
PaintTool.buttonLabel = "Paint"

-- ============================================
-- TRAITS
-- ============================================
PaintTool.traits = {
	category = "Material",
	executionType = "perVoxel",
	modifiesOccupancy = false,
	modifiesMaterial = true,
	hasFastPath = false,
	hasLargeBrushPath = false,
	requiresGlobalState = false,
	usesBrush = true,
	usesStrength = true,
	needsMaterial = true,
}

-- ============================================
-- DOCUMENTATION
-- ============================================
PaintTool.docs = {
	title = "Paint",
	subtitle = "Change terrain material without affecting shape",
	description = "Applies the selected material to existing terrain. Shape is preserved.",
	
	sections = {
		{
			heading = "Algorithm",
			bullets = {
				"For each voxel in brush region:",
				"  if cellOcc < 0.5 or cellMaterial == Air: skip",
				"  if brushOcc > threshold:",
				"    set material = selectedMaterial",
				"Occupancy unchanged—only material is modified",
			},
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"R — Lock brush position",
	},
	
	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
PaintTool.configPanels = {
	"brushShape",
	"size",
	"strength",
	"brushRate",
	"spin",
	"material",
}

-- ============================================
-- OPERATION
-- ============================================
function PaintTool.execute(options: SculptSettings)
	local writeMaterials = options.writeMaterials
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local desiredMaterial = options.desiredMaterial
	
	-- Only paint solid terrain
	if brushOccupancy > 0 and cellOccupancy > 0 then
		writeMaterials[voxelX][voxelY][voxelZ] = desiredMaterial
	end
end

return PaintTool

