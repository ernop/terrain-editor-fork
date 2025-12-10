--!strict
--[[
	NoiseTool.lua - Add procedural noise to terrain surfaces
	
	Applies 3D Perlin noise to displace terrain, creating natural
	variation and organic surface detail.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local Noise = require(Plugin.Src.Util.Noise)

local NoiseTool = {}

-- ============================================
-- IDENTITY
-- ============================================
NoiseTool.id = "Noise"
NoiseTool.name = "Noise"
NoiseTool.category = "Sculpting"
NoiseTool.buttonLabel = "Noise"

-- ============================================
-- DOCUMENTATION
-- ============================================
NoiseTool.docs = {
	title = "Noise",
	subtitle = "Add procedural variation to terrain",
	
	description = "Displaces voxel occupancy using 3D Perlin noise. Creates organic surface detail.",
	
	sections = {
		{
			heading = "Settings",
			bullets = {
				"**Scale** — Noise frequency (smaller = finer detail)",
				"**Intensity** — Displacement strength",
				"**Seed** — Change for different patterns",
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
NoiseTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"planeLock",
	"noise",
}

-- ============================================
-- OPERATION
-- ============================================
function NoiseTool.execute(options: any)
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
	local noiseScale = options.noiseScale or 4
	local noiseIntensity = options.noiseIntensity or 0.5
	local noiseSeed = options.noiseSeed or 0
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Sample noise at world position
	local scale = 1 / noiseScale
	local noiseValue = Noise.fbm3D(
		worldX * scale,
		worldY * scale,
		worldZ * scale,
		noiseSeed,
		3 -- octaves
	)
	
	-- Apply noise as displacement
	local displacement = noiseValue * noiseIntensity * brushOccupancy
	local newOccupancy = math.clamp(cellOccupancy + displacement, 0, 1)
	
	writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy
end

return NoiseTool

