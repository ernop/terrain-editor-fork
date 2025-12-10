--!strict
--[[
	TerraceTool.lua - Create stepped terrain
	
	Quantizes terrain height into discrete steps, creating
	terraced hillsides and stepped landscapes.
]]

local TerraceTool = {}

-- ============================================
-- IDENTITY
-- ============================================
TerraceTool.id = "Terrace"
TerraceTool.name = "Terrace"
TerraceTool.category = "Sculpting"
TerraceTool.buttonLabel = "Terrace"

-- ============================================
-- DOCUMENTATION
-- ============================================
TerraceTool.docs = {
	title = "Terrace",
	subtitle = "Create stepped terrain levels",
	
	description = "Quantizes vertical terrain into discrete steps. Voxels snap to the nearest step height.",
	
	sections = {
		{
			heading = "Settings",
			bullets = {
				"**Step Height** — Distance between steps (studs)",
				"**Sharpness** — Edge hardness (0=smooth, 1=sharp)",
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
TerraceTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"planeLock",
	"terrace",
}

-- ============================================
-- OPERATION
-- ============================================
function TerraceTool.execute(options: any)
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local worldY = options.worldY
	local stepHeight = options.stepHeight or 8
	local stepSharpness = options.stepSharpness or 0.8
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Calculate which step this Y position belongs to
	local stepIndex = math.floor(worldY / stepHeight)
	local stepBase = stepIndex * stepHeight
	local posInStep = (worldY - stepBase) / stepHeight
	
	-- Calculate target occupancy based on position within step
	local targetOccupancy
	if posInStep < (1 - stepSharpness) then
		-- Smooth transition zone
		targetOccupancy = 1
	else
		-- Sharp edge zone
		local edgePos = (posInStep - (1 - stepSharpness)) / stepSharpness
		targetOccupancy = 1 - edgePos
	end
	
	-- Blend toward target based on brush strength
	local blendFactor = brushOccupancy * (options.strength or 0.5)
	local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor
	
	writeOccupancies[voxelX][voxelY][voxelZ] = math.clamp(newOccupancy, 0, 1)
end

return TerraceTool

