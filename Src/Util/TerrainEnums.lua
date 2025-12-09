--[[
Collection of enums used inside the Terrain Tools plugin

Many of these are also used as a key in the LocalizationTable, so take care if you're changing any of the values
e.g. ToolId.Add = "Add" is used to lookup Studio.TerrainToolsV2.ToolName.Add to retrieve the localized string
]]

local TerrainEnums = {}

TerrainEnums.ToolId = {
	Generate = "Generate",

	Import = "Import",
	ImportLocal = "ImportLocal",

	SeaLevel = "SeaLevel",
	Replace = "Replace",
	Clear = "Clear",

	Select = "Select",
	Move = "Move",
	Resize = "Resize",
	Rotate = "Rotate",
	Copy = "Copy",
	Paste = "Paste",
	Delete = "Delete",
	Fill = "Fill",

	Add = "Add",
	Subtract = "Subtract",

	Grow = "Grow",
	Erode = "Erode",
	Smooth = "Smooth",
	Flatten = "Flatten",
	Noise = "Noise",
	Terrace = "Terrace",
	Cliff = "Cliff",

	Paint = "Paint",
	Bridge = "Bridge",

	None = "None",
}

-- TODO: Remove Build, Sculpt and Paint tabs when cleaning up
-- They have been replaced by Edit
-- Also remove them from the localization CSVs
TerrainEnums.TabId = {
	Create = "Create",
	Build = "Build",
	Region = "Region",
	Sculpt = "Sculpt",
	Paint = "Paint",
	Edit = "EDIT2",
}

TerrainEnums.PivotType = {
	Top = "Top",
	Center = "Cen",
	Bottom = "Bot",
}

TerrainEnums.PlaneLockType = {
	Off = "Off",
	Auto = "Auto",
	Manual = "Manual",
}

TerrainEnums.FlattenMode = {
	Erode = "Erode",
	Both = "Both",
	Grow = "Grow",
}

TerrainEnums.BrushShape = {
	Sphere = "Sphere",
	Cube = "Cube",
	Cylinder = "Cylinder",
	Wedge = "Wedge",
	CornerWedge = "CornerWedge",
	Dome = "Dome",
	-- Creative shapes
	Torus = "Torus",           -- Donut shape
	Ring = "Ring",             -- Flat washer/ring
	ZigZag = "ZigZag",         -- Z-shaped profile
	Sheet = "Sheet",           -- Curved paper/partial cylinder
	Grid = "Grid",             -- 3D checkerboard pattern
	Stick = "Stick",           -- Long thin rod
	Spinner = "Spinner",       -- Auto-rotating cube
	Spikepad = "Spikepad",     -- Flat base with sharp spikes
}

TerrainEnums.Biome = {
	Water = "Water",
	Plains = "Plains",
	Dunes = "Dunes",
	Mountains = "Mountains",
	Arctic = "Arctic",
	Marsh = "Marsh",
	Hills = "Hills",
	Canyons = "Canyons",
	Lavascape = "Lavascape",
}

TerrainEnums.Shape = {
	Block = "Block",

	-- Cylinder has its height along the up vector of a CFrame
	-- CylinderRotate has its height along the right vector of a CFrame
	-- Both types are used in the engine, so we need to be able to handle both for part conversion
	-- Here we treat them as separate shapes entirely
	Cylinder = "Cylinder",
	CylinderRotate = "CylinderRotate",

	Ball = "Ball",
	Wedge = "Wedge",
}

TerrainEnums.ReplaceMode = {
	Box = "Box",
	Brush = "Brush",
}

TerrainEnums.ImportMaterialMode = {
	DefaultMaterial = "DefaultMaterial",
	Colormap = "Colormap",
}

return TerrainEnums
