--!strict
--[[
	AddTool.lua - Create new terrain by adding material
	
	The most fundamental sculpting tool. Click and drag to paint
	new terrain into empty space using the selected material.
]]

local Plugin = script.Parent.Parent.Parent.Parent
local OperationHelper = require(Plugin.Src.TerrainOperations.OperationHelper)
local ToolDocFormat = require(script.Parent.Parent.ToolDocFormat)

local materialAir = Enum.Material.Air

type SculptSettings = ToolDocFormat.SculptSettings
type OperationSet = ToolDocFormat.OperationSet

local AddTool = {}

-- ============================================
-- IDENTITY
-- ============================================
AddTool.id = "Add"
AddTool.name = "Add"
AddTool.category = "Shape"
AddTool.buttonLabel = "Add"

-- ============================================
-- TRAITS
-- ============================================
AddTool.traits = {
	category = "Shape",
	executionType = "perVoxel",
	modifiesOccupancy = true,
	modifiesMaterial = true,
	hasFastPath = true,
	hasLargeBrushPath = false,
	requiresGlobalState = false,
	usesBrush = true,
	usesStrength = true,
	needsMaterial = true,
}

-- ============================================
-- DOCUMENTATION
-- ============================================
AddTool.docs = {
	title = "Add",
	subtitle = "Add blocks of terrain",
	description = "Creates terrain inside the brush shape using the selected material.",
	
	sections = {
		{
			heading = "Algorithm",
			bullets = {
				"For each voxel in brush region:",
				"  brushOcc = brush shape SDF → occupancy (0-1)",
				"  if brushOcc > cellOcc: cellOcc = brushOcc",
				"  if brushOcc ≥ 0.5 and cell is Air: set material",
			},
		},
		{
			heading = "Fast Path",
			content = "For uniform spheres, cubes, cylinders, wedges without AutoMaterial or Hollow mode, uses native Terrain:FillBall/FillBlock/FillCylinder/FillWedge APIs for ~10x speed.",
		},
	},
	
	quickTips = {
		"Shift+Scroll — Resize brush",
		"Ctrl+Scroll — Adjust strength",
		"R — Lock brush position",
		"Alt+Click — Sample material",
	},
	
	docVersion = "2.1",
}

-- ============================================
-- CONFIGURATION
-- ============================================
AddTool.configPanels = {
	"brushShape",
	"size",
	"strength",
	"brushRate",
	"pivot",
	"hollow",
	"falloff",
	"planeLock",
	"spin",
	"material",
}

-- ============================================
-- FAST PATH
-- ============================================

-- Check if this operation can use fast Roblox API
function AddTool.canUseFastPath(opSet: OperationSet): boolean
	-- Can't use fast path with autoMaterial (need per-voxel material lookup)
	if opSet.autoMaterial then
		return false
	end
	-- Can't use fast path with hollow mode
	if opSet.hollowEnabled then
		return false
	end
	-- Only basic shapes have fast API support
	local shape = opSet.brushShape
	return shape == "Sphere" or shape == "Cube" or shape == "Cylinder" or shape == "Wedge"
end

function AddTool.fastPath(terrain: Terrain, opSet: OperationSet): boolean
	local shape = opSet.brushShape
	local material = opSet.material
	local centerPoint = opSet.centerPoint
	local sizeX = opSet.cursorSizeX * 4 -- Convert voxels to studs
	local sizeY = opSet.cursorSizeY * 4
	local sizeZ = opSet.cursorSizeZ * 4
	local rotation = opSet.brushRotation or CFrame.new()
	local fillCFrame = CFrame.new(centerPoint) * rotation
	
	if shape == "Sphere" then
		local isUniform = (sizeX == sizeY) and (sizeY == sizeZ)
		local hasRotation = rotation ~= CFrame.new()
		if isUniform and not hasRotation then
			terrain:FillBall(centerPoint, sizeX * 0.5, material)
		else
			-- Fall back to per-voxel for ellipsoids
			return false
		end
	elseif shape == "Cube" then
		terrain:FillBlock(fillCFrame, Vector3.new(sizeX, sizeY, sizeZ), material)
	elseif shape == "Cylinder" then
		terrain:FillCylinder(fillCFrame, sizeY, sizeX * 0.5, material)
	elseif shape == "Wedge" then
		terrain:FillWedge(fillCFrame, Vector3.new(sizeX, sizeY, sizeZ), material)
	else
		return false -- Unknown shape, use slow path
	end
	
	return true
end

-- ============================================
-- OPERATION
-- ============================================
function AddTool.execute(options: SculptSettings)
	local writeMaterials = options.writeMaterials
	local writeOccupancies = options.writeOccupancies
	local readMaterials = options.readMaterials
	local voxelX, voxelY, voxelZ = options.x, options.y, options.z
	local sizeX, sizeY, sizeZ = options.sizeX, options.sizeY, options.sizeZ
	local brushOccupancy = options.brushOccupancy
	local cellOccupancy = options.cellOccupancy
	local cellMaterial = options.cellMaterial
	local desiredMaterial = options.desiredMaterial
	local autoMaterial = options.autoMaterial
	
	-- Add terrain where brush occupancy exceeds current occupancy
	if brushOccupancy > cellOccupancy then
		writeOccupancies[voxelX][voxelY][voxelZ] = brushOccupancy
	end
	
	-- Set material where brush is strong enough and cell was air
	if brushOccupancy >= 0.5 and cellMaterial == materialAir then
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

return AddTool

