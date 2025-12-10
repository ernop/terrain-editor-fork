--!strict
--[[
	StalactiteTool.lua - Create hanging/protruding formations
	
	Generates stalactite or stalagmite formations by extruding
	terrain vertically with tapering profiles.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local Noise = require(Plugin.Src.Util.Noise)

local StalactiteTool = {}

-- ============================================
-- IDENTITY
-- ============================================
StalactiteTool.id = "Stalactite"
StalactiteTool.name = "Stalactite"
StalactiteTool.category = "Advanced"
StalactiteTool.buttonLabel = "Stalactite"

-- ============================================
-- DOCUMENTATION
-- ============================================
StalactiteTool.docs = {
	title = "Stalactite",
	subtitle = "Create hanging or protruding spikes",
	
	description = "Extrudes tapered spikes from terrain surfaces. Direction controls whether they hang down (stalactites) or grow up (stalagmites).",
	
	sections = {
		{
			heading = "Settings",
			bullets = {
				"**Direction** — Down (-1) or Up (+1)",
				"**Density** — Spike frequency",
				"**Length** — Maximum spike length",
				"**Taper** — Point sharpness (0=blunt, 1=needle)",
			},
		},
		{
			heading = "Algorithm",
			bullets = {
				"For each voxel in brush region:",
				"  hasSpike = fbm3D(x×0.2, z×0.2, 0) > (1 - density×2)",
				"  if hasSpike:",
				"    Trace upward/downward to find root surface",
				"    spikeLen = length × (0.5 + hash×0.5) (randomized)",
				"    normalizedDist = distFromRoot / spikeLen",
				"    spikeOcc = 1 - normalizedDist^(1/taper)",
				"    if spikeOcc > cellOcc: set voxel",
			},
		},
		{
			heading = "Behavior",
			content = "Noise-based spike placement creates natural clustering. Taper exponent controls profile: low taper = cylindrical, high taper = needle-sharp. Each spike has randomized length for variation.",
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Use on cave ceilings for stalactites",
		"Use on cave floors for stalagmites",
	},
	
	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
StalactiteTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"stalactite",
	"material",
}

-- ============================================
-- OPERATION
-- ============================================
function StalactiteTool.execute(options: any)
	local writeMaterials = options.writeMaterials
	local writeOccupancies = options.writeOccupancies
	local readOccupancies = options.readOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
	local desiredMaterial = options.desiredMaterial
	local direction = options.stalactiteDirection or -1 -- -1 = down, +1 = up
	local density = options.stalactiteDensity or 0.3
	local length = options.stalactiteLength or 10
	local taper = options.stalactiteTaper or 0.8
	local seed = options.stalactiteSeed or 0
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Generate spike pattern using noise
	local noiseVal = Noise.fbm3D(worldX * 0.2, worldZ * 0.2, 0, seed, 2)
	local hasSpike = noiseVal > (1 - density * 2)
	
	if not hasSpike then
		return
	end
	
	-- Find distance to surface in spike direction
	local function getOcc(x, y, z)
		if x < 1 or x > sizeX or y < 1 or y > sizeY or z < 1 or z > sizeZ then
			return 0
		end
		return readOccupancies[x][y][z]
	end
	
	-- Calculate spike occupancy based on position
	local spikeNoise = Noise.hash3D(worldX * 10, worldZ * 10, 0, seed)
	local spikeLength = length * (0.5 + spikeNoise * 0.5)
	
	-- How far are we from the "root" of the spike?
	local distFromRoot = 0
	local checkY = voxelY
	local step = direction > 0 and -1 or 1
	
	for i = 1, math.ceil(spikeLength / 4) do
		checkY = checkY + step
		if getOcc(voxelX, checkY, voxelZ) > 0.5 then
			distFromRoot = i * 4
			break
		end
	end
	
	if distFromRoot == 0 then
		return -- No root surface found
	end
	
	-- Calculate occupancy based on taper
	local normalizedDist = distFromRoot / spikeLength
	if normalizedDist > 1 then
		return -- Beyond spike length
	end
	
	local spikeOccupancy = 1 - (normalizedDist ^ (1 / taper))
	spikeOccupancy = spikeOccupancy * brushOccupancy
	
	if spikeOccupancy > cellOccupancy then
		writeOccupancies[voxelX][voxelY][voxelZ] = spikeOccupancy
		if spikeOccupancy > 0.5 then
			writeMaterials[voxelX][voxelY][voxelZ] = desiredMaterial
		end
	end
end

return StalactiteTool

