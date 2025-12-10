--!strict
--[[
	MegarandomizeTool.lua - Scatter random materials
	
	Applies weighted random materials in clustered patterns
	for natural variation.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local Noise = require(Plugin.Src.Util.Noise)

local MegarandomizeTool = {}

-- ============================================
-- IDENTITY
-- ============================================
MegarandomizeTool.id = "Megarandomize"
MegarandomizeTool.name = "Randomize"
MegarandomizeTool.category = "Painting"
MegarandomizeTool.buttonLabel = "Randomize"

-- ============================================
-- DOCUMENTATION
-- ============================================
MegarandomizeTool.docs = {
	title = "Randomize",
	subtitle = "Scatter weighted random materials",
	
	description = "Applies materials randomly with configurable weights. Uses clustered noise for natural-looking patches.",
	
	sections = {
		{
			heading = "Settings",
			bullets = {
				"**Materials** — List with weight sliders",
				"**Cluster Size** — How large material patches are",
				"**Seed** — Change for different patterns",
			},
		},
		{
			heading = "Algorithm",
			bullets = {
				"For each solid voxel:",
				"  freq = 1 / clusterSize",
				"  noiseVal = fbm3D(worldPos × freq, seed, 2 octaves)",
				"  randomVal = (noiseVal + 1) / 2  (map to 0-1)",
				"  Normalize weights to sum to 1.0",
				"  Accumulate weights until randomVal < threshold",
				"  Select corresponding material",
			},
		},
		{
			heading = "Behavior",
			content = "Noise-based random selection creates coherent patches rather than per-voxel salt-and-pepper. Larger cluster size = bigger material regions. Weights control probability distribution; 60% grass + 40% rock means ~60% of area will be grass.",
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Adjust weights to control mix",
		"R — Lock brush position",
	},
	
	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
MegarandomizeTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"megarandomize",
}

-- ============================================
-- OPERATION
-- ============================================
function MegarandomizeTool.execute(options: any)
	local writeMaterials = options.writeMaterials
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
	local materials = options.megarandomizeMaterials or {
		{ material = Enum.Material.Grass, weight = 0.6 },
		{ material = Enum.Material.Rock, weight = 0.25 },
		{ material = Enum.Material.Ground, weight = 0.15 },
	}
	local clusterSize = options.megarandomizeClusterSize or 4
	local seed = options.megarandomizeSeed or 0
	
	-- Only paint solid terrain
	if cellOccupancy < 0.5 or cellMaterial == Enum.Material.Air then
		return
	end
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Generate clustered random value
	local scale = 1 / clusterSize
	local noiseVal = Noise.fbm3D(
		worldX * scale,
		worldY * scale,
		worldZ * scale,
		seed,
		2
	)
	local randomVal = (noiseVal + 1) / 2 -- Map to 0-1
	
	-- Select material based on weighted random
	local totalWeight = 0
	for _, entry in ipairs(materials) do
		totalWeight = totalWeight + entry.weight
	end
	
	local threshold = 0
	local selectedMaterial = materials[1].material
	for _, entry in ipairs(materials) do
		threshold = threshold + entry.weight / totalWeight
		if randomVal < threshold then
			selectedMaterial = entry.material
			break
		end
	end
	
	writeMaterials[voxelX][voxelY][voxelZ] = selectedMaterial
end

return MegarandomizeTool

