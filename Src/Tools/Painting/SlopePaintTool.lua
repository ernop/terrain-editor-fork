--!strict
--[[
	SlopePaintTool.lua - Automatic angle-based material painting
	
	Automatically applies different materials based on terrain slope.
	Flat areas get one material, steep areas get another.
]]

local SlopePaintTool = {}

-- ============================================
-- IDENTITY
-- ============================================
SlopePaintTool.id = "SlopePaint"
SlopePaintTool.name = "Slope Paint"
SlopePaintTool.category = "Painting"
SlopePaintTool.buttonLabel = "Slope Paint"

-- ============================================
-- DOCUMENTATION
-- ============================================
SlopePaintTool.docs = {
	title = "Slope Paint",
	subtitle = "Auto-paint based on terrain angle",
	
	description = "Applies materials based on surface slope. Configure thresholds to control where each material appears.",
	
	sections = {
		{
			heading = "Materials",
			bullets = {
				"**Flat** — Applied to gentle slopes (default: grass)",
				"**Steep** — Applied to medium slopes (default: rock)",
				"**Cliff** — Applied to near-vertical (default: slate)",
			},
		},
		{
			heading = "Thresholds",
			bullets = {
				"**Threshold 1** — Angle where Flat→Steep transition occurs",
				"**Threshold 2** — Angle where Steep→Cliff transition occurs",
			},
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Great for natural terrain texturing",
		"R — Lock brush position",
	},
	
	docVersion = "2.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
SlopePaintTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"slope",
}

-- ============================================
-- OPERATION
-- ============================================
function SlopePaintTool.execute(options: any)
	local writeMaterials = options.writeMaterials
	local readOccupancies = options.readOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local slopeFlatMaterial = options.slopeFlatMaterial or Enum.Material.Grass
	local slopeSteepMaterial = options.slopeSteepMaterial or Enum.Material.Rock
	local slopeCliffMaterial = options.slopeCliffMaterial or Enum.Material.Slate
	local threshold1 = options.slopeThreshold1 or 30
	local threshold2 = options.slopeThreshold2 or 60
	
	-- Only paint solid terrain
	if cellOccupancy < 0.5 or cellMaterial == Enum.Material.Air then
		return
	end
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Calculate surface normal from occupancy gradient
	local function getOcc(x, y, z)
		if x < 1 or x > sizeX or y < 1 or y > sizeY or z < 1 or z > sizeZ then
			return 0
		end
		return readOccupancies[x][y][z]
	end
	
	local gradX = getOcc(voxelX + 1, voxelY, voxelZ) - getOcc(voxelX - 1, voxelY, voxelZ)
	local gradY = getOcc(voxelX, voxelY + 1, voxelZ) - getOcc(voxelX, voxelY - 1, voxelZ)
	local gradZ = getOcc(voxelX, voxelY, voxelZ + 1) - getOcc(voxelX, voxelY, voxelZ - 1)
	
	local gradLen = math.sqrt(gradX * gradX + gradY * gradY + gradZ * gradZ)
	if gradLen < 0.01 then
		return -- No gradient = interior voxel, skip
	end
	
	-- Calculate slope angle from vertical (Y component)
	local normalY = -gradY / gradLen
	local slopeAngle = math.deg(math.acos(math.clamp(normalY, -1, 1)))
	
	-- Select material based on slope
	local targetMaterial
	if slopeAngle < threshold1 then
		targetMaterial = slopeFlatMaterial
	elseif slopeAngle < threshold2 then
		targetMaterial = slopeSteepMaterial
	else
		targetMaterial = slopeCliffMaterial
	end
	
	writeMaterials[voxelX][voxelY][voxelZ] = targetMaterial
end

return SlopePaintTool

