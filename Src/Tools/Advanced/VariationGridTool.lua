--!strict
--[[
	VariationGridTool.lua - Create grid-based terrain variation
	
	Subdivides terrain into a grid and applies random variation
	to each cell for controlled randomness.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local Noise = require(Plugin.Src.Util.Noise)

local VariationGridTool = {}

-- ============================================
-- IDENTITY
-- ============================================
VariationGridTool.id = "VariationGrid"
VariationGridTool.name = "Grid"
VariationGridTool.category = "Advanced"
VariationGridTool.buttonLabel = "Grid"

-- ============================================
-- DOCUMENTATION
-- ============================================
VariationGridTool.docs = {
	title = "Grid",
	subtitle = "Grid-based height variation",
	
	description = "Divides terrain into grid cells and applies random height offsets to each. Creates blocky, tiered landscapes.",
	
	sections = {
		{
			heading = "Settings",
			bullets = {
				"**Cell Size** — Grid cell dimensions (studs)",
				"**Variation** — Height randomness amount",
				"**Seed** — Change for different patterns",
			},
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Large cells = broad plateaus",
		"Small cells = choppy terrain",
	},
	
	docVersion = "2.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
VariationGridTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"grid",
}

-- ============================================
-- OPERATION
-- ============================================
function VariationGridTool.execute(options: any)
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
	local centerPoint = options.centerPoint
	local gridCellSize = options.gridCellSize or 8
	local gridVariation = options.gridVariation or 0.3
	local gridSeed = options.gridSeed or 0
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Determine which grid cell this voxel belongs to
	local gridX = math.floor(worldX / gridCellSize)
	local gridZ = math.floor(worldZ / gridCellSize)
	
	-- Generate height offset for this grid cell
	local cellHash = Noise.hash3D(gridX, gridZ, 0, gridSeed)
	local heightOffset = (cellHash - 0.5) * gridVariation * gridCellSize
	
	-- Calculate target occupancy based on grid height
	local gridBaseY = centerPoint.Y + heightOffset
	local targetOccupancy
	
	if worldY < gridBaseY - 2 then
		targetOccupancy = 1
	elseif worldY > gridBaseY + 2 then
		targetOccupancy = 0
	else
		targetOccupancy = 0.5 - (worldY - gridBaseY) / 4
		targetOccupancy = math.clamp(targetOccupancy, 0, 1)
	end
	
	-- Blend toward grid pattern
	local blendFactor = brushOccupancy * (options.strength or 0.5)
	local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor
	
	writeOccupancies[voxelX][voxelY][voxelZ] = math.clamp(newOccupancy, 0, 1)
end

return VariationGridTool

