--!strict
--[[
	CavityFillTool.lua - Paint concave/convex areas
	
	Detects surface curvature and paints materials into
	cavities (concave) or ridges (convex).
]]

local CavityFillTool = {}

-- ============================================
-- IDENTITY
-- ============================================
CavityFillTool.id = "CavityFill"
CavityFillTool.name = "Cavity Fill"
CavityFillTool.category = "Painting"
CavityFillTool.buttonLabel = "Cavity Fill"

-- ============================================
-- DOCUMENTATION
-- ============================================
CavityFillTool.docs = {
	title = "Cavity Fill",
	subtitle = "Paint based on surface curvature",
	
	description = "Detects concave areas (dips, crevices) and applies material. Useful for adding dirt in cracks or moss in hollows.",
	
	sections = {
		{
			heading = "Settings",
			bullets = {
				"**Sensitivity** — How shallow a cavity triggers paint",
			},
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Low sensitivity = only deep cavities",
		"R — Lock brush position",
	},
	
	docVersion = "2.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
CavityFillTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"cavity",
	"material",
}

-- ============================================
-- OPERATION
-- ============================================
function CavityFillTool.execute(options: any)
	local writeMaterials = options.writeMaterials
	local readOccupancies = options.readOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local desiredMaterial = options.desiredMaterial
	local sensitivity = options.cavitySensitivity or 0.3
	
	-- Only paint solid terrain
	if cellOccupancy < 0.5 or cellMaterial == Enum.Material.Air then
		return
	end
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Calculate laplacian (curvature approximation)
	local function getOcc(x, y, z)
		if x < 1 or x > sizeX or y < 1 or y > sizeY or z < 1 or z > sizeZ then
			return cellOccupancy
		end
		return readOccupancies[x][y][z]
	end
	
	local laplacian = (
		getOcc(voxelX + 1, voxelY, voxelZ) +
		getOcc(voxelX - 1, voxelY, voxelZ) +
		getOcc(voxelX, voxelY + 1, voxelZ) +
		getOcc(voxelX, voxelY - 1, voxelZ) +
		getOcc(voxelX, voxelY, voxelZ + 1) +
		getOcc(voxelX, voxelY, voxelZ - 1)
	) / 6 - cellOccupancy
	
	-- Positive laplacian = cavity (neighbors have more material = we're in a dip)
	if laplacian > sensitivity then
		writeMaterials[voxelX][voxelY][voxelZ] = desiredMaterial
	end
end

return CavityFillTool

