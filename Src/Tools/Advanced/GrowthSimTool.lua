--!strict
--[[
	GrowthSimTool.lua - Simulate terrain growth patterns
	
	Grows terrain following organic or crystalline patterns,
	simulating natural growth processes.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local Noise = require(Plugin.Src.Util.Noise)

local GrowthSimTool = {}

-- ============================================
-- IDENTITY
-- ============================================
GrowthSimTool.id = "GrowthSim"
GrowthSimTool.name = "Growth"
GrowthSimTool.category = "Advanced"
GrowthSimTool.buttonLabel = "Growth"

-- ============================================
-- DOCUMENTATION
-- ============================================
GrowthSimTool.docs = {
	title = "Growth",
	subtitle = "Simulate organic terrain growth",
	
	description = "Expands terrain following growth patterns. Different patterns create coral-like, crystal, or organic expansion.",
	
	sections = {
		{
			heading = "Patterns",
			bullets = {
				"**Organic** — Irregular, natural spreading",
				"**Crystal** — Angular, geometric growth",
				"**Coral** — Branching, reef-like",
			},
		},
		{
			heading = "Settings",
			bullets = {
				"**Rate** — Growth speed",
				"**Bias** — Directional preference (up/down)",
			},
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Multiple passes = more growth",
		"Bias > 0 = upward growth",
	},
	
	docVersion = "2.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
GrowthSimTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"growth",
	"material",
}

-- ============================================
-- OPERATION
-- ============================================
function GrowthSimTool.execute(options: any)
	local writeMaterials = options.writeMaterials
	local writeOccupancies = options.writeOccupancies
	local readOccupancies = options.readOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
	local desiredMaterial = options.desiredMaterial
	local growthRate = options.growthRate or 0.3
	local growthBias = options.growthBias or 0
	local growthPattern = options.growthPattern or "organic"
	local growthSeed = options.growthSeed or 0
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Get neighbor occupancies
	local function getOcc(x, y, z)
		if x < 1 or x > sizeX or y < 1 or y > sizeY or z < 1 or z > sizeZ then
			return 0
		end
		return readOccupancies[x][y][z]
	end
	
	-- Calculate neighbor influence
	local neighborSum = 0
	local neighborCount = 0
	local biasedSum = 0
	
	local offsets = {
		{1, 0, 0}, {-1, 0, 0},
		{0, 1, 0}, {0, -1, 0},
		{0, 0, 1}, {0, 0, -1},
	}
	
	for _, offset in ipairs(offsets) do
		local occ = getOcc(voxelX + offset[1], voxelY + offset[2], voxelZ + offset[3])
		neighborSum = neighborSum + occ
		neighborCount = neighborCount + 1
		
		-- Apply vertical bias
		if offset[2] ~= 0 then
			biasedSum = biasedSum + occ * offset[2] * growthBias
		end
	end
	
	local neighborAvg = neighborSum / neighborCount
	
	-- Growth only happens near existing terrain
	if neighborAvg < 0.1 then
		return
	end
	
	-- Apply pattern-specific noise
	local patternNoise = 0
	if growthPattern == "organic" then
		patternNoise = Noise.fbm3D(worldX * 0.1, worldY * 0.1, worldZ * 0.1, growthSeed, 3) * 0.3
	elseif growthPattern == "crystal" then
		-- Angular pattern using quantized noise
		local rawNoise = Noise.fbm3D(worldX * 0.2, worldY * 0.2, worldZ * 0.2, growthSeed, 2)
		patternNoise = math.floor(rawNoise * 4) / 4 * 0.3
	else -- coral
		patternNoise = Noise.fbm3D(worldX * 0.15, worldY * 0.15, worldZ * 0.15, growthSeed, 4) * 0.4
	end
	
	-- Calculate growth
	local growthAmount = neighborAvg * growthRate * brushOccupancy + patternNoise + biasedSum * 0.1
	local newOccupancy = math.clamp(cellOccupancy + growthAmount * 0.3, 0, 1)
	
	if newOccupancy > cellOccupancy then
		writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy
		if newOccupancy > 0.5 and cellMaterial == Enum.Material.Air then
			writeMaterials[voxelX][voxelY][voxelZ] = desiredMaterial
		end
	end
end

return GrowthSimTool

