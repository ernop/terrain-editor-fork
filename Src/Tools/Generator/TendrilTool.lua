--!strict
--[[
	TendrilTool.lua - Create branching organic tendrils
	
	Generates vine-like, branching structures that grow
	outward from a center point.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local Noise = require(Plugin.Src.Util.Noise)
local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

type SculptSettings = ToolDocFormat.SculptSettings

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
			heading = "Algorithm",
			bullets = {
				"For each voxel, compute distance to nearest tendril:",
				"For each branch b = 0..branches-1:",
				"  baseAngle = (b/branches) × 2π + seed",
				"  For t = 0..1 along tendril:",
				"    spiralAngle = baseAngle + t × curl × 4π",
				"    pos = (cos(spiralAngle)×t×len, -t×len×0.3 + noise, sin(spiralAngle)×t×len)",
				"    taperRadius = radius × (1 - t×0.7)",
				"    track minDist to this point",
				"spikeOcc = max(0, 1 - minDist/(radius×2))",
			},
		},
		{
			heading = "Behavior",
			content = "Parametric spiral curves with noise displacement. Each branch spirals outward and downward. Distance field creates smooth tubular shapes. Taper makes tips thinner than roots.",
		},
	},

	quickTips = {
		"Shift+Scroll — Resize brush",
		"Click to place tendril origin",
		"Change seed for different patterns",
	},

	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
TendrilTool.configPanels = {
	"brushShape",
	"size",
	"strength",
	"brushRate",
	"pivot",
	"tendrilSettings",
	"material",
}

-- ============================================
-- OPERATION
-- ============================================
function TendrilTool.execute(options: SculptSettings)
	local writeMaterials = options.writeMaterials
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
	local centerPoint = options.centerPoint
	local desiredMaterial = options.desiredMaterial
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

	for branch = 0, branches - 1 do
		-- Each branch spirals outward
		local baseAngle = (branch / branches) * math.pi * 2 + seed

		-- Sample points along the tendril
		for t = 0, 1, 0.05 do
			local dist = t * length
			local spiralAngle = baseAngle + t * curl * math.pi * 4
			local noiseOffset = Noise.fbm3D(branch, t * 5, 0, seed, 2) * 2

			-- Tendril position
			local tendrilX = math.cos(spiralAngle) * dist
			local tendrilY = -dist * 0.3 + noiseOffset -- Droop down slightly
			local tendrilZ = math.sin(spiralAngle) * dist

			local tendrilPos = Vector3.new(tendrilX, tendrilY, tendrilZ)
			local distToTendril = (relPos - tendrilPos).Magnitude

			-- Tendril tapers
			local taperRadius = radius * (1 - t * 0.7)

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
				writeMaterials[voxelX][voxelY][voxelZ] = desiredMaterial
			end
		end
	end
end

return TendrilTool
