--!strict
--[[
	CloneTool.lua - Copy and paste terrain
	
	Samples terrain from one location and stamps it elsewhere.
	Ctrl+Click to set source, then paint to stamp copies.
]]

local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

type SculptSettings = ToolDocFormat.SculptSettings

local CloneTool = {}

-- ============================================
-- IDENTITY
-- ============================================
CloneTool.id = "Clone"
CloneTool.name = "Clone"
CloneTool.category = "Utility"
CloneTool.buttonLabel = "Clone"

-- ============================================
-- TRAITS
-- ============================================
CloneTool.traits = {
	category = "Utility",
	executionType = "perVoxel",
	modifiesOccupancy = true,
	modifiesMaterial = true,
	hasFastPath = false,
	hasLargeBrushPath = false,
	requiresGlobalState = true,
	globalStateKeys = { "cloneSourceBuffer", "cloneSourceCenter" },
	usesBrush = true,
	usesStrength = true,
	needsMaterial = false,
}

-- ============================================
-- DOCUMENTATION
-- ============================================
CloneTool.docs = {
	title = "Clone",
	subtitle = "Copy and stamp terrain",
	
	description = "Samples terrain from a source location and replicates it. Ctrl+Click to capture source, then paint to stamp.",
	
	sections = {
		{
			heading = "Workflow",
			bullets = {
				"**Ctrl+Click** — Capture terrain at cursor",
				"**Click/Drag** — Stamp captured terrain",
			},
		},
		{
			heading = "Algorithm",
			bullets = {
				"On Ctrl+Click:",
				"  Read voxel region around cursor into buffer",
				"  Store {occupancy, material} for each voxel",
				"  Record source center point",
				"On paint:",
				"  offset = (currentCenter - sourceCenter) / 4 (voxel units)",
				"  For each voxel at (x, y, z):",
				"    sourceVoxel = buffer[x-offset, y-offset, z-offset]",
				"    Blend source occupancy with brush strength",
				"    Copy material if occupancy > 0.5",
			},
		},
		{
			heading = "Behavior",
			content = "Source buffer persists until next Ctrl+Click. Offset tracking allows stamping at different locations while preserving relative voxel positions. Strength controls blend between existing and source terrain.",
		},
	},
	
	quickTips = {
		"Ctrl+Click — Set clone source",
		"Shift+Scroll — Resize brush",
		"R — Lock brush position",
	},
	
	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
CloneTool.configPanels = {
	"brushShape",
	"size",
	"strength",
	"brushRate",
	"pivot",
	"hollow",
	"spin",
	"cloneInfo",
}

-- ============================================
-- OPERATION
-- ============================================
function CloneTool.execute(options: SculptSettings)
	local writeMaterials = options.writeMaterials
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cloneBuffer = options.cloneSourceBuffer
	local cloneCenter = options.cloneSourceCenter
	local centerPoint = options.centerPoint
	
	-- Need source data to clone
	if not cloneBuffer or not cloneCenter then
		return
	end
	
	-- Only affect cells within brush
	if brushOccupancy < 0.01 then
		return
	end
	
	-- Calculate offset from current center to source center
	local offsetX = math.floor((centerPoint.X - cloneCenter.X) / 4 + 0.5)
	local offsetY = math.floor((centerPoint.Y - cloneCenter.Y) / 4 + 0.5)
	local offsetZ = math.floor((centerPoint.Z - cloneCenter.Z) / 4 + 0.5)
	
	-- Look up source voxel
	local sourceX = voxelX - offsetX
	local sourceY = voxelY - offsetY
	local sourceZ = voxelZ - offsetZ
	
	local sourceData = cloneBuffer[sourceX] 
		and cloneBuffer[sourceX][sourceY] 
		and cloneBuffer[sourceX][sourceY][sourceZ]
	
	if sourceData then
		-- Blend source occupancy with brush strength
		local blendFactor = brushOccupancy * (options.strength or 0.5)
		local targetOcc = sourceData.occupancy
		local currentOcc = options.cellOccupancy
		
		writeOccupancies[voxelX][voxelY][voxelZ] = currentOcc + (targetOcc - currentOcc) * blendFactor
		
		if sourceData.occupancy > 0.5 then
			writeMaterials[voxelX][voxelY][voxelZ] = sourceData.material
		end
	end
end

return CloneTool

