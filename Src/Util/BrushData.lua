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
BrushData.ShapeSizingMode = {
	[BrushShape.Sphere] = "uniform",
	[BrushShape.Cube] = "box",
	[BrushShape.Cylinder] = "box",
	[BrushShape.Wedge] = "box",
	[BrushShape.CornerWedge] = "box",
	[BrushShape.Dome] = "box",
	[BrushShape.Torus] = "box",
	[BrushShape.Ring] = "box",
	[BrushShape.ZigZag] = "box",
	[BrushShape.Sheet] = "box",
	[BrushShape.Grid] = "box",
	[BrushShape.Stick] = "box",
	[BrushShape.Spinner] = "box",
	[BrushShape.Spikepad] = "box",
}

-- Tool config definitions: which settings each tool needs
-- Rationale:
-- - Material: Only for tools that CREATE/CHANGE terrain material (Add, Paint, Bridge)
-- - Hollow: Only for tools that create/remove volume (Add, Subtract, Clone)
-- - Plane Lock: Useful for most tools, especially Flatten
-- - Pivot: Useful for positioning brush in most tools
BrushData.ToolConfigs = {
	-- Add: Creates new terrain - needs material picker and hollow mode
	[ToolId.Add] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"hollow",
		"planeLock",
		"spin",
		"material",
	},
	-- Subtract: Removes terrain - needs hollow mode, no material
	[ToolId.Subtract] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"hollow",
		"planeLock",
		"spin",
	},
	-- Grow: Grows existing terrain - no material, no hollow
	[ToolId.Grow] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"planeLock",
		"spin",
	},
	-- Erode: Wears terrain down - no material, no hollow
	[ToolId.Erode] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"planeLock",
		"spin",
	},
	-- Smooth: Smooths surface - no material, no hollow
	[ToolId.Smooth] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"planeLock",
		"spin",
	},
	-- Flatten: Levels terrain - needs flatten mode, plane lock is very useful
	[ToolId.Flatten] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"planeLock",
		"flattenMode",
		"spin",
	},
	-- Noise: Adds procedural noise - no material, no hollow
	[ToolId.Noise] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"spin",
		-- Note: noiseScale, noiseIntensity, noiseSeed panels not yet implemented
	},
	-- Terrace: Creates stepped terraces - no material, no hollow
	[ToolId.Terrace] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"spin",
		-- Note: stepHeight, stepSharpness panels not yet implemented
	},
	-- Cliff: Creates cliff faces - no material, no hollow
	[ToolId.Cliff] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"spin",
		-- Note: cliffAngle, cliffDirectionInfo panels not yet implemented
	},
	-- Path: Carves a path/channel - no material, no hollow (it's already a channel)
	[ToolId.Path] = {
		"brushShape",
		"strength",
		"brushRate",
		"spin",
		"pathDepth",
		"pathProfile",
		"pathDirectionInfo",
	},
	-- Clone: Copies terrain - hollow might be useful for copying hollow structures
	[ToolId.Clone] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"hollow",
		"spin",
		"cloneInfo",
	},
	-- Blobify: Creates organic blobs - no material, no hollow
	[ToolId.Blobify] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"spin",
		"blobIntensity",
		"blobSmoothness",
	},
	-- Paint: Changes material only - needs material picker, no hollow or pivot needed
	[ToolId.Paint] = {
		"brushShape",
		"strength",
		"brushRate",
		"spin",
		"material",
		-- Note: autoMaterial panel not yet implemented
	},
	-- Bridge: Creates bridge terrain - needs material, special bridge controls
	[ToolId.Bridge] = {
		"bridgeInfo",
		"strength",
		"material",
	},
	-- Slope Paint: Auto-textures terrain based on surface angle
	[ToolId.SlopePaint] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"spin",
		"slopeMaterials",
	},
	-- Megarandomize: Applies multiple materials with weighted randomness
	[ToolId.Megarandomize] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"spin",
		"megarandomizeSettings",
	},
	-- Cavity Fill: Intelligently fills terrain depressions
	[ToolId.CavityFill] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"spin",
		"cavitySensitivity",
	},
	-- Melt: Simulates terrain melting/flowing downward
	[ToolId.Melt] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"spin",
		"meltViscosity",
	},
	-- Gradient Paint: Creates material transitions between two points
	[ToolId.GradientPaint] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"spin",
		"gradientSettings",
	},
	-- Flood Paint: Surface-aware flood fill for materials
	[ToolId.FloodPaint] = {
		"brushShape",
		"floodSettings",
		"material",
	},
	-- Stalactite: Creates hanging spike formations
	[ToolId.Stalactite] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"stalactiteSettings",
		"material",
	},
	-- Tendril: Creates organic branching structures
	[ToolId.Tendril] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"tendrilSettings",
		"material",
	},
	-- Symmetry: Creates symmetric copies
	[ToolId.Symmetry] = {
		"brushShape",
		"brushRate",
		"pivot",
		"symmetrySettings",
	},
	-- Variation Grid: Creates grid pattern with variations
	[ToolId.VariationGrid] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"gridSettings",
		"material",
	},
	-- Growth Simulation: Organic terrain expansion
	[ToolId.GrowthSim] = {
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"growthSettings",
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
