--!strict
--[[
	SymmetryTool.lua - Paint with radial symmetry
	
	Duplicates brush strokes around a center axis,
	creating symmetrical patterns.
]]

local SymmetryTool = {}

-- ============================================
-- IDENTITY
-- ============================================
SymmetryTool.id = "Symmetry"
SymmetryTool.name = "Symmetry"
SymmetryTool.category = "Advanced"
SymmetryTool.buttonLabel = "Symmetry"

-- ============================================
-- DOCUMENTATION
-- ============================================
SymmetryTool.docs = {
	title = "Symmetry",
	subtitle = "Paint with radial duplication",
	
	description = "Mirrors brush strokes around a central axis. Creates symmetrical terrain patterns automatically.",
	
	sections = {
		{
			heading = "Settings",
			bullets = {
				"**Segments** — Number of symmetry copies (2=mirror, 4=quad, etc.)",
				"**Type** — Radial or bilateral",
			},
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"2 segments = simple mirror",
		"Higher segments = mandala patterns",
	},
	
	docVersion = "2.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
SymmetryTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"symmetry",
	"material",
}

-- ============================================
-- OPERATION
-- ============================================
function SymmetryTool.execute(options: any)
	-- Symmetry is handled at a higher level (brush operation)
	-- This execute function handles the base stroke
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
	
	-- Simple add operation for the base stroke
	if brushOccupancy > cellOccupancy then
		writeOccupancies[voxelX][voxelY][voxelZ] = brushOccupancy
	end
	
	if brushOccupancy >= 0.5 and cellMaterial == Enum.Material.Air then
		writeMaterials[voxelX][voxelY][voxelZ] = desiredMaterial
	end
end

return SymmetryTool

