--!strict
--[[
	PathTool.lua - Carve paths and trenches
	
	Creates channels through terrain with configurable profile
	(V-shaped, U-shaped, or flat bottom).
]]

local PathTool = {}

-- ============================================
-- IDENTITY
-- ============================================
PathTool.id = "Path"
PathTool.name = "Path"
PathTool.category = "Sculpting"
PathTool.buttonLabel = "Path"

-- ============================================
-- DOCUMENTATION
-- ============================================
PathTool.docs = {
	title = "Path",
	subtitle = "Carve channels and trenches",
	
	description = "Removes terrain in a linear channel. Drag to set direction. Choose profile shape for different trench styles.",
	
	sections = {
		{
			heading = "Profiles",
			bullets = {
				"**V** — Pointed bottom, natural drainage",
				"**U** — Rounded bottom, river beds",
				"**Flat** — Square bottom, roads and canals",
			},
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Drag to set path direction",
		"R — Lock brush position",
	},
	
	docVersion = "2.0",
}

-- ============================================
-- CONFIGURATION
-- ============================================
PathTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"path",
}

-- ============================================
-- OPERATION
-- ============================================
function PathTool.execute(options: any)
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
	local centerPoint = options.centerPoint
	local pathDepth = options.pathDepth or 6
	local pathProfile = options.pathProfile or "U"
	local pathDirX = options.pathDirectionX or 0
	local pathDirZ = options.pathDirectionZ or 1
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Normalize direction
	local dirLen = math.sqrt(pathDirX * pathDirX + pathDirZ * pathDirZ)
	if dirLen < 0.01 then
		pathDirX, pathDirZ = 0, 1
	else
		pathDirX, pathDirZ = pathDirX / dirLen, pathDirZ / dirLen
	end
	
	-- Calculate perpendicular distance from path center line
	local relX = worldX - centerPoint.X
	local relZ = worldZ - centerPoint.Z
	local perpDist = math.abs(-pathDirZ * relX + pathDirX * relZ)
	
	-- Calculate depth at this perpendicular distance based on profile
	local halfWidth = options.cursorSizeX * 2 -- Half brush width in studs
	local normalizedDist = perpDist / halfWidth
	
	local depthFactor
	if pathProfile == "V" then
		depthFactor = 1 - normalizedDist
	elseif pathProfile == "Flat" then
		depthFactor = normalizedDist < 0.8 and 1 or (1 - (normalizedDist - 0.8) / 0.2)
	else -- "U" default
		depthFactor = math.sqrt(1 - normalizedDist * normalizedDist)
	end
	depthFactor = math.max(0, depthFactor)
	
	-- Calculate target depth at this position
	local carveDepth = pathDepth * depthFactor
	local surfaceY = centerPoint.Y
	
	-- Determine target occupancy
	local targetOccupancy
	if worldY > surfaceY then
		targetOccupancy = cellOccupancy -- Above surface, don't change
	elseif worldY > surfaceY - carveDepth then
		targetOccupancy = 0 -- In carved zone
	else
		targetOccupancy = cellOccupancy -- Below carved zone
	end
	
	-- Blend toward target
	local blendFactor = brushOccupancy * (options.strength or 0.5)
	local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor
	
	writeOccupancies[voxelX][voxelY][voxelZ] = math.clamp(newOccupancy, 0, 1)
end

return PathTool

