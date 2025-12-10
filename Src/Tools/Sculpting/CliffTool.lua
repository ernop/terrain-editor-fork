--!strict
--[[
	CliffTool.lua - Create vertical cliff faces
	
	Carves steep vertical faces into terrain at a specified angle,
	useful for creating dramatic cliff edges and rock walls.
]]

local CliffTool = {}

-- ============================================
-- IDENTITY
-- ============================================
CliffTool.id = "Cliff"
CliffTool.name = "Cliff"
CliffTool.category = "Sculpting"
CliffTool.buttonLabel = "Cliff"

-- ============================================
-- DOCUMENTATION
-- ============================================
CliffTool.docs = {
	title = "Cliff",
	subtitle = "Carve vertical cliff faces",
	
	description = "Creates steep vertical walls by carving terrain at a specified angle. Drag in the direction the cliff should face.",
	
	sections = {
		{
			heading = "Settings",
			bullets = {
				"**Angle** — Cliff steepness (90° = vertical)",
				"**Direction** — Set by dragging or manually",
			},
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Drag to set cliff facing direction",
		"R — Lock brush position",
	},
	
	docVersion = "2.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
CliffTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"cliff",
}

-- ============================================
-- OPERATION
-- ============================================
function CliffTool.execute(options: any)
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
	local centerPoint = options.centerPoint
	local cliffAngle = options.cliffAngle or 90
	local cliffDirX = options.cliffDirectionX or 1
	local cliffDirZ = options.cliffDirectionZ or 0
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Normalize direction
	local dirLen = math.sqrt(cliffDirX * cliffDirX + cliffDirZ * cliffDirZ)
	if dirLen < 0.01 then
		cliffDirX, cliffDirZ = 1, 0
	else
		cliffDirX, cliffDirZ = cliffDirX / dirLen, cliffDirZ / dirLen
	end
	
	-- Calculate distance along cliff direction from center
	local relX = worldX - centerPoint.X
	local relZ = worldZ - centerPoint.Z
	local distAlongCliff = relX * cliffDirX + relZ * cliffDirZ
	
	-- Calculate cliff plane height at this position
	local angleRad = math.rad(cliffAngle)
	local cliffSlope = math.tan(angleRad)
	local cliffHeight = centerPoint.Y + distAlongCliff * cliffSlope
	
	-- Determine if this voxel should be solid or air
	local targetOccupancy
	if worldY < cliffHeight - 2 then
		targetOccupancy = 1 -- Below cliff = solid
	elseif worldY > cliffHeight + 2 then
		targetOccupancy = 0 -- Above cliff = air
	else
		-- Transition zone
		targetOccupancy = 0.5 - (worldY - cliffHeight) / 4
		targetOccupancy = math.clamp(targetOccupancy, 0, 1)
	end
	
	-- Blend toward target
	local blendFactor = brushOccupancy * (options.strength or 0.5)
	local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor
	
	writeOccupancies[voxelX][voxelY][voxelZ] = math.clamp(newOccupancy, 0, 1)
end

return CliffTool

