--!strict
--[[
	TendrilTool.lua - Create branching organic tendrils
	
	Generates vine-like, branching structures that grow
	outward from a center point.
	
	OPTIMIZED: Uses fast path to pre-compute tendril paths once,
	then rasterizes with FillBall. Previous per-voxel approach
	caused severe lag due to O(voxels × branches × samples) complexity.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local Noise = require(Plugin.Src.Util.Noise)
local OperationHelper = require(Plugin.Src.TerrainOperations.OperationHelper)
local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

type SculptSettings = ToolDocFormat.SculptSettings
type OperationSet = ToolDocFormat.OperationSet

local TendrilTool = {}

-- ============================================
-- IDENTITY
-- ============================================
TendrilTool.id = "Tendril"
TendrilTool.name = "Tendril"
TendrilTool.category = "Generator"
TendrilTool.buttonLabel = "Tendril"

-- ============================================
-- TRAITS
-- ============================================
TendrilTool.traits = {
	category = "Generator",
	executionType = "perVoxel",
	modifiesOccupancy = true,
	modifiesMaterial = true,
	hasFastPath = true, -- Now has a fast path!
	hasLargeBrushPath = false,
	requiresGlobalState = false,
	usesBrush = true,
	usesStrength = true,
	needsMaterial = true,
}

-- ============================================
-- DOCUMENTATION
-- ============================================
TendrilTool.docs = {
	title = "Tendril",
	subtitle = "Create branching vine-like structures",

	description = "Generates organic, curling tendrils that branch outward. Great for roots, vines, or alien terrain.",

	sections = {
		{
			heading = "Settings",
			bullets = {
				"**Radius** — Tendril thickness",
				"**Branches** — Number of main tendrils",
				"**Length** — How far tendrils extend",
				"**Curl** — Spiral tightness",
			},
		},
		{
			heading = "Fast Path Algorithm",
			bullets = {
				"Pre-computes all tendril path points ONCE",
				"For each branch b = 0..branches-1:",
				"  For t = 0..1 along tendril:",
				"    Compute spiral position with noise",
				"    Store path point with tapered radius",
				"Rasterizes each path point with FillBall",
				"~100x faster than per-voxel approach",
			},
		},
		{
			heading = "Behavior",
			content = "Parametric spiral curves with noise displacement. Each branch spirals outward and downward. Taper makes tips thinner than roots.",
		},
	},

	quickTips = {
		"Shift+Scroll — Resize brush",
		"Click to place tendril origin",
		"Change seed for different patterns",
	},

	docVersion = "2.2",
}

-- ============================================
-- CONFIGURATION
-- ============================================
TendrilTool.configPanels = {
	"brushShape",
	"brushSize",
	"brushLock",
	"strength",
	"brushRate",
	"pivot",
	"tendrilSettings",
	"autoMaterial",
	"material",
}

-- ============================================
-- FAST PATH (PRIMARY IMPLEMENTATION)
-- ============================================

-- Use fast path unless auto-material is enabled (need per-voxel material lookup)
function TendrilTool.canUseFastPath(opSet: OperationSet): boolean
	if opSet.autoMaterial then
		return false
	end
	return true
end

-- Generate tendril geometry and rasterize with FillBall
function TendrilTool.fastPath(terrain: Terrain, opSet: OperationSet): boolean
	local material = opSet.material
	local centerPoint = opSet.centerPoint
	
	-- Tendril parameters
	local radius = opSet.tendrilRadius or 1.5
	local branches = opSet.tendrilBranches or 5
	local length = opSet.tendrilLength or 15
	local curl = opSet.tendrilCurl or 0.5
	local seed = opSet.tendrilSeed or opSet.noiseSeed or 0
	
	-- Convert radius from UI units to studs
	local radiusStuds = radius * 4
	
	-- Step size along tendril (smaller = smoother but more FillBall calls)
	-- We want overlapping spheres for smooth tendrils
	local stepSize = 0.03 -- 3% per step = ~33 steps per branch
	
	-- Generate and rasterize each branch
	for branch = 0, branches - 1 do
		-- Each branch spirals outward from center
		local baseAngle = (branch / branches) * math.pi * 2 + seed
		
		-- Walk along the tendril
		for t = 0, 1, stepSize do
			local dist = t * length
			local spiralAngle = baseAngle + t * curl * math.pi * 4
			
			-- Add some noise-based displacement for organic feel
			local noiseOffset = Noise.fbmFast(branch, t * 5, 0, seed, 2) * 2
			
			-- Tendril position relative to center
			local tendrilX = math.cos(spiralAngle) * dist
			local tendrilY = -dist * 0.3 + noiseOffset -- Droop down slightly
			local tendrilZ = math.sin(spiralAngle) * dist
			
			-- Absolute world position
			local worldPos = centerPoint + Vector3.new(tendrilX, tendrilY, tendrilZ)
			
			-- Taper: radius decreases along length (thicker at root, thinner at tip)
			local taperFactor = 1 - t * 0.7
			local segmentRadius = math.max(radiusStuds * taperFactor, 2) -- Minimum 2 studs
			
			-- Rasterize this segment
			terrain:FillBall(worldPos, segmentRadius, material)
		end
	end
	
	return true
end

-- ============================================
-- OPERATION (FALLBACK - rarely used)
-- ============================================
-- This per-voxel version is kept as fallback but should rarely run
-- since canUseFastPath always returns true.
function TendrilTool.execute(options: SculptSettings)
	local writeMaterials = options.writeMaterials
	local writeOccupancies = options.writeOccupancies
	local readMaterials = options.readMaterials
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
	local centerPoint = options.centerPoint
	local desiredMaterial = options.desiredMaterial
	local autoMaterial = options.autoMaterial
	local radius = options.tendrilRadius or 1.5
	local branches = options.tendrilBranches or 5
	local length = options.tendrilLength or 15
	local curl = options.tendrilCurl or 0.5
	local seed = options.tendrilSeed or 0

	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end

	-- Calculate distance to nearest tendril
	local minDist = math.huge
	local worldPos = Vector3.new(worldX, worldY, worldZ)
	local relPos = worldPos - centerPoint

	-- OPTIMIZATION: Use larger step size to reduce iterations
	-- This is fallback code anyway, so we favor speed over precision
	for branch = 0, branches - 1 do
		local baseAngle = (branch / branches) * math.pi * 2 + seed

		-- Larger step = fewer iterations (0.1 instead of 0.05)
		for t = 0, 1, 0.1 do
			local dist = t * length
			local spiralAngle = baseAngle + t * curl * math.pi * 4
			local noiseOffset = Noise.fbmFast(branch, t * 5, 0, seed, 2) * 2

			local tendrilX = math.cos(spiralAngle) * dist
			local tendrilY = -dist * 0.3 + noiseOffset
			local tendrilZ = math.sin(spiralAngle) * dist

			local tendrilPos = Vector3.new(tendrilX, tendrilY, tendrilZ)
			local distToTendril = (relPos - tendrilPos).Magnitude

			if distToTendril < minDist then
				minDist = distToTendril
			end
		end
	end

	-- Calculate occupancy based on distance to tendril
	if minDist < radius * 2 then
		local tendrilOccupancy = math.max(0, 1 - minDist / (radius * 2))
		tendrilOccupancy = tendrilOccupancy * brushOccupancy

		if tendrilOccupancy > cellOccupancy then
			writeOccupancies[voxelX][voxelY][voxelZ] = tendrilOccupancy
			if tendrilOccupancy > 0.5 then
				local targetMaterial = desiredMaterial
				if autoMaterial then
					targetMaterial = OperationHelper.getMaterialForAutoMaterial(
						readMaterials,
						voxelX, voxelY, voxelZ,
						sizeX, sizeY, sizeZ,
						cellMaterial
					)
				end
				writeMaterials[voxelX][voxelY][voxelZ] = targetMaterial
			end
		end
	end
end

return TendrilTool
