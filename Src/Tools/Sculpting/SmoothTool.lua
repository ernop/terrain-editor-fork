--!strict
--[[
	SmoothTool.lua - Blend and smooth terrain surfaces
	
	Averages occupancy values between neighbors, smoothing out
	rough edges and harsh transitions. Essential for polishing terrain.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local OperationHelper = require(Plugin.Src.TerrainOperations.OperationHelper)

local materialAir = Enum.Material.Air
local materialWater = Enum.Material.Water

local SmoothTool = {}

-- ============================================
-- IDENTITY
-- ============================================
SmoothTool.id = "Smooth"
SmoothTool.name = "Smooth"
SmoothTool.category = "Sculpting"
SmoothTool.buttonLabel = "Smooth"

-- ============================================
-- DOCUMENTATION
-- ============================================
SmoothTool.docs = {
	title = "Smooth",
	subtitle = "Average voxel occupancy with neighbors",
	description = "Blends each voxel toward the average of its neighbors. Can both fill gaps and erode peaks.",
	
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
SmoothTool.configPanels = {
	"brushShape",
	"strength",
	"brushRate",
	"pivot",
	"planeLock",
	"spin",
}

-- ============================================
-- OPERATION
-- ============================================
function SmoothTool.execute(options: any)
	local readMaterials = options.readMaterials
	local readOccupancies = options.readOccupancies
	local writeMaterials = options.writeMaterials
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local magnitudePercent = options.magnitudePercent
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local strength = options.strength
	local filterSize = options.filterSize or 1
	local airFillerMaterial = options.airFillerMaterial or materialAir
	local ignoreWater = options.ignoreWater

	-- Need minimum region size for smooth to work
	if sizeX <= 2 or sizeZ <= 2 or sizeY <= 2 then
		return
	end

	-- Skip if brush influence too weak
	if brushOccupancy < 0.5 then
		return
	end

	local neighbourOccupanciesSum = 0
	local totalNeighbours = 0
	local hasFullNeighbour = false
	local hasEmptyNeighbour = false

	local cellStartMaterial = readMaterials[voxelX][voxelY][voxelZ]
	local cellStartsEmpty = cellStartMaterial == materialAir or cellOccupancy <= 0

	-- Sample neighbors in a cube pattern
	for xo = -filterSize, filterSize, filterSize do
		for yo = -filterSize, filterSize, filterSize do
			for zo = -filterSize, filterSize, filterSize do
				local checkX = voxelX + xo
				local checkY = voxelY + yo
				local checkZ = voxelZ + zo

				if checkX > 0 and checkX <= sizeX and checkY > 0 and checkY <= sizeY and checkZ > 0 and checkZ <= sizeZ then
					local occupancy = readOccupancies[checkX][checkY][checkZ]
					local distanceScale = 1 - (math.sqrt(xo * xo + yo * yo + zo * zo) / (filterSize * 2))

					local neighborMaterial = readMaterials[checkX][checkY][checkZ]
					if ignoreWater and neighborMaterial == materialWater then
						occupancy = 0
					end

					if occupancy >= 1 then
						hasFullNeighbour = true
					end

					if occupancy <= 0 then
						hasEmptyNeighbour = true
					end

					-- Scale occupancy to allow cells to fully fill or empty
					occupancy = occupancy * 1.5 - 0.25

					totalNeighbours = totalNeighbours + 1 * distanceScale
					neighbourOccupanciesSum = neighbourOccupanciesSum + occupancy * distanceScale
				end
			end
		end
	end

	local neighbourOccupancies = neighbourOccupanciesSum / (totalNeighbours > 0 and totalNeighbours or (cellOccupancy * 1.5 - 0.25))

	local difference = (neighbourOccupancies - cellOccupancy) * (strength + 0.1) * 0.5 * brushOccupancy * magnitudePercent

	-- Prevent growing without a full neighbor or eroding without an empty neighbor
	if not hasFullNeighbour and difference > 0 then
		difference = 0
	elseif not hasEmptyNeighbour and difference < 0 then
		difference = 0
	end

	local targetOccupancy = math.max(0, math.min(1, cellOccupancy + difference))
	
	if targetOccupancy ~= cellOccupancy then
		if cellStartsEmpty and targetOccupancy > 0 then
			-- Cell becoming non-empty - give it a material from neighbors
			writeMaterials[voxelX][voxelY][voxelZ] = OperationHelper.getMaterialForAutoMaterial(
				readMaterials, voxelX, voxelY, voxelZ, 
				sizeX, sizeY, sizeZ, cellMaterial
			)
		elseif targetOccupancy <= 0 then
			writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
		end

		writeOccupancies[voxelX][voxelY][voxelZ] = targetOccupancy
	end
end

return SmoothTool

