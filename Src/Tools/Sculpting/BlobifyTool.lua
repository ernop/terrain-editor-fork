--!strict
--[[
	BlobifyTool.lua - Add organic blob-like deformation
	
	Applies smooth, organic distortion to terrain surfaces,
	creating natural-looking bulges and indentations.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local Noise = require(Plugin.Src.Util.Noise)

local BlobifyTool = {}

-- ============================================
-- IDENTITY
-- ============================================
BlobifyTool.id = "Blobify"
BlobifyTool.name = "Blobify"
BlobifyTool.category = "Sculpting"
BlobifyTool.buttonLabel = "Blobify"

-- ============================================
-- DOCUMENTATION
-- ============================================
BlobifyTool.docs = {
	title = "Blobify",
	subtitle = "Add organic blob distortion",
	
	description = "Applies smooth, bulging deformation using layered noise. Creates organic, melted-looking surfaces.",
	
	sections = {
		{
			heading = "Settings",
			bullets = {
				"**Intensity** — Blob displacement amount",
				"**Smoothness** — Blob roundness (low = lumpy)",
			},
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Ctrl+Scroll — Adjust strength",
		"R — Lock brush position",
	},
	
	docVersion = "2.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
BlobifyTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"blob",
}

-- ============================================
-- OPERATION
-- ============================================
function BlobifyTool.execute(options: any)
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
	local blobIntensity = options.blobIntensity or 0.5
	local blobSmoothness = options.blobSmoothness or 0.7
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Generate blob noise
	local scale = 0.1 * (1.1 - blobSmoothness)
	local blobNoise = Noise.fbm3D(
		worldX * scale,
		worldY * scale,
		worldZ * scale,
		0, -- seed
		2 -- octaves for smooth blobs
	)
	
	-- Apply blob deformation
	local displacement = blobNoise * blobIntensity * brushOccupancy
	local newOccupancy = math.clamp(cellOccupancy + displacement, 0, 1)
	
	writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy
end

return BlobifyTool

