--!strict
-- Constant data tables for brush shapes and materials
-- Extracted to reduce local register count in main module

local TerrainEnums = require(script.Parent.TerrainEnums)
local BrushShape = TerrainEnums.BrushShape
local ToolId = TerrainEnums.ToolId

local BrushData = {}

-- Shape capabilities: which shapes support rotation
BrushData.ShapeSupportsRotation = {
	[BrushShape.Sphere] = false,
	[BrushShape.Cube] = true,
	[BrushShape.Cylinder] = true,
	[BrushShape.Wedge] = true,
	[BrushShape.CornerWedge] = true,
	[BrushShape.Dome] = false,
	[BrushShape.Torus] = true,
	[BrushShape.Ring] = true,
	[BrushShape.ZigZag] = true,
	[BrushShape.Sheet] = true,
	[BrushShape.Grid] = true,
	[BrushShape.Stick] = true,
	[BrushShape.Spinner] = false,
	[BrushShape.Spikepad] = true,
}

-- Shape sizing modes: "uniform" = single size, "box" = X, Y, Z independent
-- DEPRECATED: Use ShapeDimensions for proper per-shape axis definitions
BrushData.ShapeSizingMode = {
	[BrushShape.Sphere] = "uniform",
	[BrushShape.Cube] = "box",
	[BrushShape.Cylinder] = "cylinder",
	[BrushShape.Wedge] = "box",
	[BrushShape.CornerWedge] = "box",
	[BrushShape.Dome] = "cylinder",
	[BrushShape.Torus] = "torus",
	[BrushShape.Ring] = "ring",
	[BrushShape.ZigZag] = "box",
	[BrushShape.Sheet] = "sheet",
	[BrushShape.Grid] = "uniform",
	[BrushShape.Stick] = "stick",
	[BrushShape.Spinner] = "uniform",
	[BrushShape.Spikepad] = "spikepad",
}

--[[
	ShapeDimensions - Defines the sizing axes for each brush shape
	
	Each shape defines:
	- axes: Array of dimension definitions
	  - label: UI label for the slider
	  - maps: Which state vars this dimension controls ("x", "y", "z")
	  - primary: true if this is the Shift+Scroll dimension
	  - secondary: true if this is the Shift+Alt+Scroll dimension
	
	When maps has multiple values (e.g., {"x", "z"}), they're kept equal.
	
	Keyboard shortcuts:
	- Shift + Scroll = primary axis (overall size / most impactful)
	- Shift + Alt + Scroll = secondary axis
	- For shapes with 3 independent axes, primary scales uniformly
]]
BrushData.ShapeDimensions = {
	[BrushShape.Sphere] = {
		-- Sphere: single radius (all axes equal)
		axes = {
			{ label = "Size", maps = { "x", "y", "z" }, primary = true },
		},
	},
	[BrushShape.Cube] = {
		-- Cube: 3 independent axes
		-- Shift+Scroll = XZ (horizontal footprint), Shift+Alt+Scroll = Y (height)
		axes = {
			{ label = "X", maps = { "x" } },
			{ label = "Y", maps = { "y" }, secondary = true },
			{ label = "Z", maps = { "z" } },
		},
		-- Primary is XZ together (horizontal plane)
		primaryMaps = { "x", "z" },
	},
	[BrushShape.Cylinder] = {
		-- Cylinder: radius (X=Z) and height (Y)
		axes = {
			{ label = "Radius", maps = { "x", "z" }, primary = true },
			{ label = "Height", maps = { "y" }, secondary = true },
		},
	},
	[BrushShape.Wedge] = {
		-- Wedge: 3 independent axes
		-- Shift+Scroll = XZ (footprint), Shift+Alt+Scroll = Y (height)
		axes = {
			{ label = "X", maps = { "x" } },
			{ label = "Y", maps = { "y" }, secondary = true },
			{ label = "Z", maps = { "z" } },
		},
		primaryMaps = { "x", "z" },
	},
	[BrushShape.CornerWedge] = {
		-- CornerWedge: 3 independent axes
		-- Shift+Scroll = XZ (footprint), Shift+Alt+Scroll = Y (height)
		axes = {
			{ label = "X", maps = { "x" } },
			{ label = "Y", maps = { "y" }, secondary = true },
			{ label = "Z", maps = { "z" } },
		},
		primaryMaps = { "x", "z" },
	},
	[BrushShape.Dome] = {
		-- Dome: radius (X=Z) and height (Y)
		axes = {
			{ label = "Radius", maps = { "x", "z" }, primary = true },
			{ label = "Height", maps = { "y" }, secondary = true },
		},
	},
	[BrushShape.Torus] = {
		-- Torus: ring radius (major) and tube radius
		-- X = major radius (ring size), Y = tube radius (thickness)
		axes = {
			{ label = "Ring Radius", maps = { "x" }, primary = true },
			{ label = "Tube Radius", maps = { "y" }, secondary = true },
		},
		-- Z is unused for torus
	},
	[BrushShape.Ring] = {
		-- Ring: outer radius and thickness (height of the ring)
		-- X = outer radius, Y = thickness
		axes = {
			{ label = "Radius", maps = { "x" }, primary = true },
			{ label = "Thickness", maps = { "y" }, secondary = true },
		},
	},
	[BrushShape.ZigZag] = {
		-- ZigZag: 3 independent axes
		-- Shift+Scroll = XZ (footprint), Shift+Alt+Scroll = Y (height)
		axes = {
			{ label = "X", maps = { "x" } },
			{ label = "Y", maps = { "y" }, secondary = true },
			{ label = "Z", maps = { "z" } },
		},
		primaryMaps = { "x", "z" },
	},
	[BrushShape.Sheet] = {
		-- Sheet: arc radius (curve), thickness, and height
		axes = {
			{ label = "Arc Radius", maps = { "x" }, primary = true },
			{ label = "Thickness", maps = { "y" }, secondary = true },
			{ label = "Height", maps = { "z" } },
		},
	},
	[BrushShape.Grid] = {
		-- Grid: uniform cell size
		axes = {
			{ label = "Size", maps = { "x", "y", "z" }, primary = true },
		},
	},
	[BrushShape.Stick] = {
		-- Stick: length (Y) and thickness (X=Z)
		axes = {
			{ label = "Length", maps = { "y" }, primary = true },
			{ label = "Thickness", maps = { "x", "z" }, secondary = true },
		},
	},
	[BrushShape.Spinner] = {
		-- Spinner: uniform size (rotating cube)
		axes = {
			{ label = "Size", maps = { "x", "y", "z" }, primary = true },
		},
	},
	[BrushShape.Spikepad] = {
		-- Spikepad: base size (X=Z) and spike height (Y)
		axes = {
			{ label = "Base Size", maps = { "x", "z" }, primary = true },
			{ label = "Spike Height", maps = { "y" }, secondary = true },
		},
	},
}

-- Helper function: Get the primary axis definition for a shape
-- Returns { maps = {...} } - may be from primaryMaps or an axis marked primary
function BrushData.getPrimaryAxis(shape: string): { label: string?, maps: { string } }?
	local dims = BrushData.ShapeDimensions[shape]
	if not dims then
		return nil
	end
	-- Check for explicit primaryMaps first (for shapes like Cube with XZ primary)
	if dims.primaryMaps then
		return { maps = dims.primaryMaps }
	end
	-- Otherwise look for an axis marked primary
	for _, axis in ipairs(dims.axes) do
		if axis.primary then
			return axis
		end
	end
	-- Fallback to first axis
	return dims.axes[1]
end

-- Helper function: Get the secondary axis definition for a shape
function BrushData.getSecondaryAxis(shape: string): { label: string, maps: { string } }?
	local dims = BrushData.ShapeDimensions[shape]
	if not dims then
		return nil
	end
	for _, axis in ipairs(dims.axes) do
		if axis.secondary then
			return axis
		end
	end
	return nil
end

-- Helper function: Check if shape uses uniform scroll (scales all axes together)
function BrushData.usesUniformScroll(shape: string): boolean
	local dims = BrushData.ShapeDimensions[shape]
	if not dims then
		return false
	end
	return dims.scrollUniform == true
end

-- Tool config definitions: FALLBACK for tools not in ToolRegistry
-- Primary configs now live in each tool's .configPanels field (Src/Tools/*/*.lua)
-- This is only used for tools that don't have tool files yet (analysis tools)
BrushData.ToolConfigs = {
	-- Analysis Tools (no tool files yet - these are UI-only)
	[ToolId.VoxelInspect] = {
		"voxelInspectPanel",
	},
	[ToolId.ComponentAnalyzer] = {
		"componentAnalyzerPanel",
	},
	[ToolId.OccupancyOverlay] = {
		"occupancyOverlayPanel",
	},
}

-- Bridge variant definitions
BrushData.BridgeVariants = {
	"Arc",
	"Sinusoidal",
	"Blippy",
	"SquareWave",
	"Rollercoaster",
	"TwistySwingly",
	"MegaMeander",
}

-- Brush shape options for UI
BrushData.Shapes = {
	{ id = BrushShape.Sphere, name = "Sphere" },
	{ id = BrushShape.Cube, name = "Cube" },
	{ id = BrushShape.Cylinder, name = "Cyl" },
	{ id = BrushShape.Wedge, name = "Wedge" },
	{ id = BrushShape.CornerWedge, name = "Corner" },
	{ id = BrushShape.Dome, name = "Dome" },
	{ id = BrushShape.Torus, name = "Torus" },
	{ id = BrushShape.Ring, name = "Ring" },
	{ id = BrushShape.ZigZag, name = "ZigZag" },
	{ id = BrushShape.Sheet, name = "Sheet" },
	{ id = BrushShape.Grid, name = "Grid" },
	{ id = BrushShape.Stick, name = "Stick" },
	{ id = BrushShape.Spikepad, name = "Spikes" },
}

-- Terrain tile asset IDs
BrushData.TerrainTileAssets = {
	asphalt = "rbxassetid://78614136624014",
	basalt = "rbxassetid://71488841892968",
	brick = "rbxassetid://86199875827473",
	cobblestone = "rbxassetid://138302697949882",
	concrete = "rbxassetid://81313531028668",
	crackedlava = "rbxassetid://115898687343919",
	glacier = "rbxassetid://90944124973144",
	grass = "rbxassetid://99269182833344",
	ground = "rbxassetid://98068530890664",
	ice = "rbxassetid://130640331811455",
	leafygrass = "rbxassetid://132107716629085",
	limestone = "rbxassetid://81415278652229",
	mud = "rbxassetid://76887606792976",
	pavement = "rbxassetid://114087276888883",
	rock = "rbxassetid://92599200690067",
	salt = "rbxassetid://134960396477809",
	sand = "rbxassetid://83926858135627",
	sandstone = "rbxassetid://130446207383659",
	slate = "rbxassetid://106648045724926",
	snow = "rbxassetid://91289820814306",
	water = "rbxassetid://95030501428333",
	woodplanks = "rbxassetid://104230772282297",
}

-- Material definitions for UI
BrushData.Materials = {
	{ enum = Enum.Material.Grass, key = "grass", name = "Grass" },
	{ enum = Enum.Material.Sand, key = "sand", name = "Sand" },
	{ enum = Enum.Material.Rock, key = "rock", name = "Rock" },
	{ enum = Enum.Material.Ground, key = "ground", name = "Ground" },
	{ enum = Enum.Material.Snow, key = "snow", name = "Snow" },
	{ enum = Enum.Material.Ice, key = "ice", name = "Ice" },
	{ enum = Enum.Material.Glacier, key = "glacier", name = "Glacier" },
	{ enum = Enum.Material.Water, key = "water", name = "Water" },
	{ enum = Enum.Material.Mud, key = "mud", name = "Mud" },
	{ enum = Enum.Material.Slate, key = "slate", name = "Slate" },
	{ enum = Enum.Material.Concrete, key = "concrete", name = "Concrete" },
	{ enum = Enum.Material.Brick, key = "brick", name = "Brick" },
	{ enum = Enum.Material.Cobblestone, key = "cobblestone", name = "Cobblestone" },
	{ enum = Enum.Material.Asphalt, key = "asphalt", name = "Asphalt" },
	{ enum = Enum.Material.Pavement, key = "pavement", name = "Pavement" },
	{ enum = Enum.Material.Basalt, key = "basalt", name = "Basalt" },
	{ enum = Enum.Material.CrackedLava, key = "crackedlava", name = "Cracked Lava" },
	{ enum = Enum.Material.Salt, key = "salt", name = "Salt" },
	{ enum = Enum.Material.Sandstone, key = "sandstone", name = "Sandstone" },
	{ enum = Enum.Material.Limestone, key = "limestone", name = "Limestone" },
	{ enum = Enum.Material.LeafyGrass, key = "leafygrass", name = "Leafy Grass" },
	{ enum = Enum.Material.WoodPlanks, key = "woodplanks", name = "Wood Planks" },
}

-- Compute bridge path offset for a given t (0 to 1), distance, and variant
function BrushData.getBridgeOffset(t: number, distance: number, variant: string): Vector3
	local baseArc = math.sin(t * math.pi) * distance * 0.1
	local waveAmplitude = distance * 0.15

	if variant == "Arc" then
		return Vector3.new(0, baseArc, 0)
	elseif variant == "Sinusoidal" then
		local wave = math.sin(t * math.pi * 6) * waveAmplitude * 0.5
		return Vector3.new(0, baseArc + wave, 0)
	elseif variant == "Blippy" then
		local blip = math.abs(math.sin(t * math.pi * 12)) * waveAmplitude * 0.3
		return Vector3.new(0, baseArc + blip, 0)
	elseif variant == "SquareWave" then
		local phase = (t * 4) % 1
		local step = phase < 0.5 and 0 or waveAmplitude * 0.6
		return Vector3.new(0, baseArc + step, 0)
	elseif variant == "Rollercoaster" then
		local coaster = math.sin(t * math.pi * 4) * waveAmplitude
		local peak = math.max(0, math.sin(t * math.pi * 4)) ^ 2 * waveAmplitude * 0.5
		return Vector3.new(0, baseArc + coaster + peak, 0)
	elseif variant == "TwistySwingly" then
		local vertWave = math.sin(t * math.pi * 5) * waveAmplitude * 0.4
		local horizWave = math.cos(t * math.pi * 3) * waveAmplitude * 0.6
		return Vector3.new(horizWave, baseArc + vertWave, 0)
	elseif variant == "MegaMeander" then
		-- Wild flying path that soars high and swoops dramatically
		-- Multiple overlapping frequencies for organic feel
		local megaArc = math.sin(t * math.pi) * distance * 0.5 -- Much higher base arc (5x normal)
		local bigSwoop = math.sin(t * math.pi * 2.5) * distance * 0.3 -- Big swoops
		local medSwoop = math.cos(t * math.pi * 4) * distance * 0.15 -- Medium frequency variation
		local smallWiggle = math.sin(t * math.pi * 7) * distance * 0.05 -- Small wiggles
		-- Dramatic dips that "try to go under arches"
		local dipFactor = math.max(0, math.sin(t * math.pi * 3)) ^ 3 * distance * -0.2
		local vertOffset = megaArc + bigSwoop + medSwoop + smallWiggle + dipFactor
		-- Horizontal meandering (side to side wandering)
		local horizMeander = math.sin(t * math.pi * 3.5) * distance * 0.25
		local horizWiggle = math.cos(t * math.pi * 6) * distance * 0.1
		return Vector3.new(horizMeander + horizWiggle, vertOffset, 0)
	end

	return Vector3.new(0, baseArc, 0)
end

return BrushData
