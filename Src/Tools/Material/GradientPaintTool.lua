--!strict
--[[
	GradientPaintTool.lua - Paint material gradients
	
	Blends between two materials across a defined axis,
	with optional noise for natural transitions.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local Noise = require(Plugin.Src.Util.Noise)
local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

type SculptSettings = ToolDocFormat.SculptSettings

local GradientPaintTool = {}

-- ============================================
-- IDENTITY
-- ============================================
GradientPaintTool.id = "GradientPaint"
GradientPaintTool.name = "Gradient"
GradientPaintTool.category = "Material"
GradientPaintTool.buttonLabel = "Gradient"

-- ============================================
-- TRAITS
-- ============================================
GradientPaintTool.traits = {
	category = "Material",
	executionType = "perVoxel",
	modifiesOccupancy = false,
	modifiesMaterial = true,
	hasFastPath = false,
	hasLargeBrushPath = false,
	requiresGlobalState = true,
	globalStateKeys = { "gradientStartPoint", "gradientEndPoint" },
	usesBrush = true,
	usesStrength = true,
	needsMaterial = false, -- Uses gradient endpoints from config
}

-- ============================================
-- DOCUMENTATION
-- ============================================
GradientPaintTool.docs = {
	title = "Gradient",
	subtitle = "Blend between two materials",

	description = "Creates material transitions along an axis. Set start and end points to define gradient direction.",

	sections = {
		{
			heading = "Workflow",
			bullets = {
				"**Ctrl+Click** — Set gradient start point",
				"**Shift+Click** — Set gradient end point",
				"**Paint** — Apply gradient in brush area",
			},
		},
		{
			heading = "Algorithm",
			bullets = {
				"axis = endPoint - startPoint",
				"For each solid voxel:",
				"  relPos = worldPos - startPoint",
				"  t = dot(relPos, axis) / |axis|² (projection onto axis)",
				"  noise = fbm3D(worldPos × 0.1, seed) × noiseAmount",
				"  gradientPos = clamp(t + noise, 0, 1)",
				"  material = gradientPos < 0.5 ? material1 : material2",
			},
		},
		{
			heading = "Behavior",
			content = "Projects voxel position onto gradient axis. Position 0-0.5 gets material1, 0.5-1 gets material2. Noise adds randomness to the boundary, creating organic transitions instead of a sharp line.",
		},
	},

	quickTips = {
		"Ctrl+Click — Set start point",
		"Shift+Click — Set end point",
		"Shift+Scroll — Resize brush",
	},

	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
GradientPaintTool.configPanels = {
	"brushShape",
	"size",
	"strength",
	"brushRate",
	"pivot",
	"spin",
	"gradientSettings",
}

-- ============================================
-- OPERATION
-- ============================================
function GradientPaintTool.execute(options: SculptSettings)
	local writeMaterials = options.writeMaterials
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
	local material1 = options.gradientMaterial1 or Enum.Material.Grass
	local material2 = options.gradientMaterial2 or Enum.Material.Rock
	local startPoint = options.gradientStartPoint
	local endPoint = options.gradientEndPoint
	local noiseAmount = options.gradientNoiseAmount or 0.1
	local seed = options.gradientSeed or 0

	-- Only paint solid terrain
	if cellOccupancy < 0.5 or cellMaterial == Enum.Material.Air then
		return
	end

	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end

	-- Need both points to create gradient
	if not startPoint or not endPoint then
		return
	end

	-- Calculate position along gradient axis
	local axis = endPoint - startPoint
	local axisLen = axis.Magnitude
	if axisLen < 0.01 then
		return
	end

	local worldPos = Vector3.new(worldX, worldY, worldZ)
	local relPos = worldPos - startPoint
	local dotProduct = relPos:Dot(axis) / (axisLen * axisLen)

	-- Add noise to transition
	local noise = 0
	if noiseAmount > 0 then
		noise = Noise.fbm3D(worldX * 0.1, worldY * 0.1, worldZ * 0.1, seed, 2) * noiseAmount
	end

	local gradientPos = math.clamp(dotProduct + noise, 0, 1)

	-- Select material based on position
	local selectedMaterial = gradientPos < 0.5 and material1 or material2

	writeMaterials[voxelX][voxelY][voxelZ] = selectedMaterial
end

return GradientPaintTool
