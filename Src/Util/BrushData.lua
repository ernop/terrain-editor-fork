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
	[BrushShape.RotatedDome] = true, -- Forward-facing dome, benefits from rotation to aim different directions
	[BrushShape.Torus] = true,
	[BrushShape.Ring] = true,
	[BrushShape.ZigZag] = true,
	[BrushShape.Sheet] = true,
	[BrushShape.Grid] = true,
	[BrushShape.Stick] = true,
	[BrushShape.Spinner] = false,
	[BrushShape.Spikepad] = true,
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
	[BrushShape.RotatedDome] = {
		-- RotatedDome: forward-facing dome (good for tunnel/arch entrances)
		-- Radius (X=Y for circular dome face), Depth (Z controls how deep it goes)
		axes = {
			{ label = "Radius", maps = { "x", "y" }, primary = true },
			{ label = "Depth", maps = { "z" }, secondary = true },
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
		-- Sheet: arc radius (curve), height, and thickness
		-- X = curve radius, Y = height (vertical extent), Z = thickness (how thick the sheet is)
		axes = {
			{ label = "Arc Radius", maps = { "x" }, primary = true },
			{ label = "Height", maps = { "y" }, secondary = true },
			{ label = "Thickness", maps = { "z" } },
		},
	},
	[BrushShape.Grid] = {
		-- Grid: size is controlled by Grid Shape Settings panel (count * cubeSize)
		-- No standard size sliders for Grid - it uses dedicated controls
		axes = {}, -- Empty: Grid uses gridShapeSettings panel instead
		noSizeSliders = true, -- Flag to skip size slider generation
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

-- Helper function: Check if shape uses uniform sizing (all axes linked to same value)
-- Returns true for shapes like Sphere, Grid, Spinner where X=Y=Z
function BrushData.isUniformShape(shape: string): boolean
	local dims = BrushData.ShapeDimensions[shape]
	if not dims then
		return true -- Default to uniform if unknown
	end
	-- Check if there's exactly one axis that maps to all three dimensions
	if #dims.axes == 1 then
		local maps = dims.axes[1].maps
		local hasX, hasY, hasZ = false, false, false
		for _, axis in ipairs(maps) do
			if axis == "x" then hasX = true end
			if axis == "y" then hasY = true end
			if axis == "z" then hasZ = true end
		end
		return hasX and hasY and hasZ
	end
	return false
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
	-- Creative/geometric variants
	"Fibonacci",
	"Fractal",
	"Exponential",
	"Logarithmic",
	"Corkscrew",
	"Drunkard",
	"Heartbeat",
	"Staircase",
	"Catenary",
	"TrollBridge",
}

-- Brush shape options for UI
BrushData.Shapes = {
	{ id = BrushShape.Sphere, name = "Sphere" },
	{ id = BrushShape.Cube, name = "Cube" },
	{ id = BrushShape.Cylinder, name = "Cyl" },
	{ id = BrushShape.Wedge, name = "Wedge" },
	{ id = BrushShape.CornerWedge, name = "Corner" },
	{ id = BrushShape.Dome, name = "Dome" },
	{ id = BrushShape.RotatedDome, name = "Arch" },
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

-- Compute bridge path offset for a given t (0 to 1), distance, variant, and intensity
-- intensity: multiplier for how extreme the variations are (0.1 to 3.0, default 1.0)
function BrushData.getBridgeOffset(t: number, distance: number, variant: string, intensity: number?): Vector3
	local i = intensity or 1.0
	local baseArc = math.sin(t * math.pi) * distance * 0.1 * i
	local waveAmplitude = distance * 0.15 * i

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
		local megaArc = math.sin(t * math.pi) * distance * 0.5 * i
		local bigSwoop = math.sin(t * math.pi * 2.5) * distance * 0.3 * i
		local medSwoop = math.cos(t * math.pi * 4) * distance * 0.15 * i
		local smallWiggle = math.sin(t * math.pi * 7) * distance * 0.05 * i
		-- Dramatic dips that "try to go under arches"
		local dipFactor = math.max(0, math.sin(t * math.pi * 3)) ^ 3 * distance * -0.2 * i
		local vertOffset = megaArc + bigSwoop + medSwoop + smallWiggle + dipFactor
		-- Horizontal meandering (side to side wandering)
		local horizMeander = math.sin(t * math.pi * 3.5) * distance * 0.25 * i
		local horizWiggle = math.cos(t * math.pi * 6) * distance * 0.1 * i
		return Vector3.new(horizMeander + horizWiggle, vertOffset, 0)

	elseif variant == "Fibonacci" then
		-- Golden spiral growth: each segment rises proportional to golden ratio
		-- Creates an ever-accelerating ascent that feels "naturally impossible"
		local phi = 1.618033988749895 -- Golden ratio
		local fibHeight = (phi ^ (t * 5) - 1) / (phi ^ 5 - 1) * distance * 0.4 * i
		-- Add gentle spiral motion in horizontal plane
		local spiralAngle = t * math.pi * 3
		local spiralRadius = t * distance * 0.15 * i
		local horizX = math.cos(spiralAngle) * spiralRadius
		local horizZ = math.sin(spiralAngle) * spiralRadius * 0.5
		return Vector3.new(horizX, baseArc + fibHeight, horizZ)

	elseif variant == "Fractal" then
		-- Self-similar bumps at multiple scales (octave noise)
		-- Each frequency is half the previous, amplitude also halves
		local octave1 = math.sin(t * math.pi * 2) * waveAmplitude * 0.5
		local octave2 = math.sin(t * math.pi * 4) * waveAmplitude * 0.25
		local octave3 = math.sin(t * math.pi * 8) * waveAmplitude * 0.125
		local octave4 = math.sin(t * math.pi * 16) * waveAmplitude * 0.0625
		local fractalHeight = octave1 + octave2 + octave3 + octave4
		-- Horizontal fractal wobble too
		local horizOctave1 = math.cos(t * math.pi * 3) * waveAmplitude * 0.3
		local horizOctave2 = math.cos(t * math.pi * 7) * waveAmplitude * 0.15
		return Vector3.new(horizOctave1 + horizOctave2, baseArc + fractalHeight, 0)

	elseif variant == "Exponential" then
		-- Starts flat, then rockets skyward at the end
		-- Uses smoothstep-like curve for dramatic effect
		local expFactor = (math.exp(t * 3) - 1) / (math.exp(3) - 1)
		local expHeight = expFactor * distance * 0.5 * i
		-- Slight horizontal drift as it climbs
		local drift = math.sin(t * math.pi) * distance * 0.1 * i
		return Vector3.new(drift, expHeight, 0)

	elseif variant == "Logarithmic" then
		-- Quick rise at start, then nearly flat approach to end
		-- Inverse feeling of exponential - front-loaded climb
		local logT = math.max(0.001, t) -- Avoid log(0)
		local logFactor = math.log(1 + logT * 10) / math.log(11)
		local logHeight = logFactor * distance * 0.35 * i
		-- Horizontal curve that opens up
		local spread = t * t * distance * 0.15 * i
		return Vector3.new(math.sin(t * math.pi * 2) * spread, logHeight, 0)

	elseif variant == "Corkscrew" then
		-- Full 3D helix wrapping around the straight path
		-- Like a spring stretched between two points
		local turns = 4 * i -- Number of full rotations
		local helixAngle = t * math.pi * 2 * turns
		local helixRadius = distance * 0.12 * i
		-- Radius varies: smaller at ends, larger in middle
		local radiusModifier = math.sin(t * math.pi)
		local effectiveRadius = helixRadius * (0.3 + radiusModifier * 0.7)
		local helixX = math.cos(helixAngle) * effectiveRadius
		local helixY = math.sin(helixAngle) * effectiveRadius
		return Vector3.new(helixX, baseArc + helixY, 0)

	elseif variant == "Drunkard" then
		-- Pseudo-random wobble using deterministic chaos
		-- Simulates a wobbly, stumbling path
		local seed = 12345
		local chaos1 = math.sin(t * 137.5 + seed) * math.cos(t * 73.1)
		local chaos2 = math.cos(t * 89.3 + seed * 2) * math.sin(t * 41.7)
		local chaos3 = math.sin(t * 197.2 + seed * 3)
		local wobbleY = (chaos1 + chaos2 * 0.5) * waveAmplitude * 0.8
		local wobbleX = chaos3 * waveAmplitude * 0.6
		-- Add stumble: occasional sharp dips
		local stumble = math.max(0, math.sin(t * math.pi * 7)) ^ 4 * waveAmplitude * -0.5
		return Vector3.new(wobbleX, baseArc + wobbleY + stumble, 0)

	elseif variant == "Heartbeat" then
		-- ECG/EKG-style cardiac rhythm pattern
		-- Flat sections punctuated by sharp spikes
		local beatPeriod = 0.2 -- Each heartbeat takes 20% of the path
		local phase = (t % beatPeriod) / beatPeriod
		local beatHeight = 0
		if phase < 0.1 then
			-- P wave: small bump
			beatHeight = math.sin(phase / 0.1 * math.pi) * waveAmplitude * 0.2
		elseif phase < 0.2 then
			-- Flat PR segment
			beatHeight = 0
		elseif phase < 0.25 then
			-- Q dip
			beatHeight = -waveAmplitude * 0.15
		elseif phase < 0.35 then
			-- R spike: sharp peak
			local rPhase = (phase - 0.25) / 0.1
			beatHeight = math.sin(rPhase * math.pi) * waveAmplitude * 1.5
		elseif phase < 0.4 then
			-- S dip
			beatHeight = -waveAmplitude * 0.1
		elseif phase < 0.6 then
			-- ST segment + T wave
			local tPhase = (phase - 0.4) / 0.2
			beatHeight = math.sin(tPhase * math.pi) * waveAmplitude * 0.3
		end
		return Vector3.new(0, baseArc + beatHeight * i, 0)

	elseif variant == "Staircase" then
		-- Distinct steps with flat landings
		-- Like walking up a grand staircase
		local numSteps = math.floor(6 * i)
		local stepIndex = math.floor(t * numSteps)
		local stepProgress = (t * numSteps) % 1
		local stepHeight = (stepIndex / numSteps) * distance * 0.3 * i
		-- Smooth transition between steps (ease in/out)
		local transitionZone = 0.3
		local riseAmount = 0
		if stepProgress < transitionZone then
			-- Rising portion
			local risePhase = stepProgress / transitionZone
			riseAmount = (1 - math.cos(risePhase * math.pi)) / 2 * (distance * 0.3 * i / numSteps)
		end
		-- Add slight horizontal zigzag at each step
		local zigzag = ((stepIndex % 2) * 2 - 1) * distance * 0.05 * i
		return Vector3.new(zigzag, stepHeight + riseAmount, 0)

	elseif variant == "Catenary" then
		-- True hanging chain curve (hyperbolic cosine)
		-- The natural shape of a rope suspended between two points
		-- Sags in the middle, curves up at the ends
		local a = distance * 0.15 * i -- Catenary parameter (controls sag depth)
		-- Catenary: y = a * cosh((x - center) / a) - a
		-- Normalized so it touches y=0 at both ends
		local x = (t - 0.5) * 2 -- Map t from [0,1] to [-1,1]
		local coshValue = (math.exp(x * 2) + math.exp(-x * 2)) / 2 -- cosh(2x)
		local coshEnd = (math.exp(2) + math.exp(-2)) / 2 -- cosh(2) for normalization
		local sagDepth = (coshValue - 1) / (coshEnd - 1) * distance * 0.25 * i
		-- Catenary sags DOWN, but we add base arc, so net effect depends on intensity
		-- For low intensity: gentle sag. For high: dramatic suspension bridge dip
		return Vector3.new(0, baseArc - sagDepth, 0)

	elseif variant == "TrollBridge" then
		-- Looks like a normal arc at first... then does a LOOP-THE-LOOP in the middle
		-- Perfectly ridiculous and impossible
		local loopCenter = 0.5 -- Loop happens at middle
		local loopRadius = distance * 0.25 * i
		local loopWidth = 0.3 -- Loop takes 30% of the path
		local loopStart = loopCenter - loopWidth / 2
		local loopEnd = loopCenter + loopWidth / 2

		if t >= loopStart and t <= loopEnd then
			-- WE'RE IN THE LOOP ZONE
			local loopProgress = (t - loopStart) / loopWidth
			local loopAngle = loopProgress * math.pi * 2 -- Full 360 degree loop
			-- Loop goes UP and OVER (starts at bottom, goes up, over, down, continues)
			local loopX = math.sin(loopAngle) * loopRadius * 0.5
			local loopY = (1 - math.cos(loopAngle)) * loopRadius -- 0 at start, 2r at top, 0 at end
			-- Base height at loop entrance
			local baseHeight = math.sin(loopStart * math.pi) * distance * 0.15 * i
			return Vector3.new(loopX, baseHeight + loopY, 0)
		else
			-- Normal arc section (before and after loop)
			local adjustedT = t
			if t > loopEnd then
				-- After loop, continue from where we left off
				adjustedT = t
			end
			return Vector3.new(0, math.sin(adjustedT * math.pi) * distance * 0.15 * i, 0)
		end
	end

	return Vector3.new(0, baseArc, 0)
end

-- Anchored version: ensures start and end points stay exactly where user placed them
-- This corrects for variants where getBridgeOffset returns non-zero at t=0 or t=1
-- Without this, changing intensity can shift the endpoints away from user's intended positions
function BrushData.getBridgeOffsetAnchored(t: number, distance: number, variant: string, intensity: number?): Vector3
	-- Get the raw offsets at start, end, and current t
	local startOffset = BrushData.getBridgeOffset(0, distance, variant, intensity)
	local endOffset = BrushData.getBridgeOffset(1, distance, variant, intensity)
	local currentOffset = BrushData.getBridgeOffset(t, distance, variant, intensity)
	
	-- Linear interpolation of endpoint offsets (what we need to subtract)
	local correction = startOffset:Lerp(endOffset, t)
	
	-- Return the offset minus the correction, so start=0 and end=0
	return currentOffset - correction
end

-- Terrain-aware bridge offset: adjusts path to respect nearby terrain
-- minClearance: minimum distance above terrain (studs)
-- maxAdjustment: maximum vertical adjustment per point (studs)
function BrushData.getBridgeOffsetTerrainAware(
	t: number,
	distance: number,
	variant: string,
	intensity: number?,
	terrainHeightAtPoint: number?, -- Height of terrain at this path position (nil if no terrain)
	basePathY: number, -- Y coordinate of the base linear path at this t
	minClearance: number?,
	maxAdjustment: number?
): Vector3
	local baseOffset = BrushData.getBridgeOffsetAnchored(t, distance, variant, intensity)
	
	-- If no terrain data, return the base offset
	if not terrainHeightAtPoint then
		return baseOffset
	end
	
	local clearance = minClearance or 4 -- Default 4 studs (1 voxel) clearance
	local maxAdj = maxAdjustment or (distance * 0.3) -- Default max 30% of distance
	
	-- Calculate where the path would be without terrain adjustment
	local pathY = basePathY + baseOffset.Y
	local terrainTop = terrainHeightAtPoint + clearance
	
	-- If path is below terrain + clearance, push it up
	if pathY < terrainTop then
		local neededAdjustment = terrainTop - pathY
		-- Clamp the adjustment to avoid crazy spikes
		local actualAdjustment = math.min(neededAdjustment, maxAdj)
		-- Smooth the adjustment using a bell curve to avoid sharp transitions
		local smoothFactor = math.sin(t * math.pi) -- Strongest in middle, zero at ends
		actualAdjustment = actualAdjustment * (0.3 + 0.7 * smoothFactor)
		return Vector3.new(baseOffset.X, baseOffset.Y + actualAdjustment, baseOffset.Z)
	end
	
	return baseOffset
end

-- Plane-aware bridge: keeps the bridge path more consistent with its own plane
-- This calculates a "reference plane" from start/end and constrains lateral drift
-- planeConstraint: 0 = no constraint, 1 = fully constrained to start-end plane
function BrushData.getBridgeOffsetPlaneAware(
	t: number,
	distance: number,
	variant: string,
	intensity: number?,
	planeConstraint: number? -- 0 to 1: how much to constrain to the start-end plane
): Vector3
	local baseOffset = BrushData.getBridgeOffsetAnchored(t, distance, variant, intensity)
	
	local constraint = planeConstraint or 0
	if constraint <= 0 then
		return baseOffset
	end
	
	-- The X and Z components represent lateral drift perpendicular to the path
	-- Reduce them based on plane constraint
	local lateralReduction = 1 - constraint
	return Vector3.new(
		baseOffset.X * lateralReduction,
		baseOffset.Y, -- Keep vertical movement unchanged
		baseOffset.Z * lateralReduction
	)
end

return BrushData
