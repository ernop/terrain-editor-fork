--!strict
--[[
	SubtractTool.lua - Remove terrain by carving out material
	
	The inverse of Add. Click and drag to remove terrain,
	creating holes, caves, and carved features.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local OperationHelper = require(Plugin.Src.TerrainOperations.OperationHelper)
local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

local materialAir = Enum.Material.Air
local materialWater = Enum.Material.Water

type SculptSettings = ToolDocFormat.SculptSettings
type OperationSet = ToolDocFormat.OperationSet

local SubtractTool = {}

-- ============================================
-- IDENTITY
-- ============================================
SubtractTool.id = "Subtract"
SubtractTool.name = "Subtract"
SubtractTool.category = "Shape"
SubtractTool.buttonLabel = "Subtract"

-- ============================================
-- TRAITS
-- ============================================
SubtractTool.traits = {
	category = "Shape",
	executionType = "perVoxel",
	modifiesOccupancy = true,
	modifiesMaterial = true,
	hasFastPath = true,
	hasLargeBrushPath = false,
	requiresGlobalState = false,
	usesBrush = true,
	usesStrength = true,
	needsMaterial = false,
}

-- ============================================
-- DOCUMENTATION
-- ============================================
SubtractTool.docs = {
	title = "Subtract",
	subtitle = "Remove blocks of terrain",
	description = "Carves away terrain inside the brush shape.",

	sections = {
		{
			heading = "Algorithm",
			bullets = {
				"For each voxel in brush region:",
				"  desiredOcc = 1 - brushOcc (inverse)",
				"  if desiredOcc < cellOcc: cellOcc = desiredOcc",
				"  if desiredOcc ≤ 1/256: set to Air (or Water if below sea level)",
			},
		},
		{
			heading = "Fast Path",
			content = "For uniform shapes without IgnoreWater or Hollow mode, uses native Fill APIs with Air material.",
		},
	},

	quickTips = {
		"Shift+Scroll — Resize brush",
		"Ctrl+Scroll — Adjust strength",
		"R — Lock brush position",
	},

	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
SubtractTool.configPanels = {
	"brushShape",
	"size",
	"brushLock",
	"strength",
	"brushRate",
	"pivot",
	"hollow",
	"falloff",
	"planeLock",
	"spin",
}

-- ============================================
-- FAST PATH
-- ============================================

function SubtractTool.canUseFastPath(opSet: OperationSet): boolean
	-- Can use fast path when not ignoring water
	if opSet.ignoreWater then
		return false
	end
	if opSet.hollowEnabled then
		return false
	end
	local shape = opSet.brushShape
	return shape == "Sphere" or shape == "Cube" or shape == "Cylinder" or shape == "Wedge"
end

function SubtractTool.fastPath(terrain: Terrain, opSet: OperationSet): boolean
	local shape = opSet.brushShape
	local centerPoint = opSet.centerPoint
	local sizeX = opSet.cursorSizeX * 4
	local sizeY = opSet.cursorSizeY * 4
	local sizeZ = opSet.cursorSizeZ * 4
	local rotation = opSet.brushRotation or CFrame.new()
	local fillCFrame = CFrame.new(centerPoint) * rotation

	if shape == "Sphere" then
		local isUniform = (sizeX == sizeY) and (sizeY == sizeZ)
		local hasRotation = rotation ~= CFrame.new()
		if isUniform and not hasRotation then
			terrain:FillBall(centerPoint, sizeX * 0.5, materialAir)
		else
			return false
		end
	elseif shape == "Cube" then
		terrain:FillBlock(fillCFrame, Vector3.new(sizeX, sizeY, sizeZ), materialAir)
	elseif shape == "Cylinder" then
		terrain:FillCylinder(fillCFrame, sizeY, sizeX * 0.5, materialAir)
	elseif shape == "Wedge" then
		terrain:FillWedge(fillCFrame, Vector3.new(sizeX, sizeY, sizeZ), materialAir)
	else
		return false
	end

	return true
end

-- ============================================
-- OPERATION
-- ============================================
function SubtractTool.execute(options: SculptSettings)
	local writeMaterials = options.writeMaterials
	local writeOccupancies = options.writeOccupancies
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local airFillerMaterial = options.airFillerMaterial or materialAir

	-- Skip air cells
	if cellMaterial == materialAir then
		return
	end

	-- Calculate desired occupancy (inverse of brush)
	local desiredOccupancy = 1 - brushOccupancy

	-- Only subtract if it would reduce occupancy
	if desiredOccupancy < cellOccupancy then
		if desiredOccupancy <= OperationHelper.one256th then
			-- Fully removed - set to air (or water if below water level)
			writeOccupancies[voxelX][voxelY][voxelZ] = airFillerMaterial == materialWater and 1 or 0
			writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
		else
			-- Partially removed
			writeOccupancies[voxelX][voxelY][voxelZ] = desiredOccupancy
		end
	end
end

return SubtractTool
