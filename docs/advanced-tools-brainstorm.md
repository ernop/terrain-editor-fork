# Advanced Terrain Tools — Brainstorm & Implementation Plan

> **Document created:** December 2024  
> **Status:** Research & Planning  
> **Total tools proposed:** 20

This document captures all brainstormed terrain tool ideas, their use cases, implementation approaches, and technical specifications. These tools are designed to transform terrain editing from tedious manual work into expressive, powerful sculpting.

---

## Table of Contents

1. [Philosophy & Goals](#philosophy--goals)
2. [Tool Categories](#tool-categories)
3. [Implementation Architecture](#implementation-architecture)
4. [Tool Specifications](#tool-specifications)
   - [Brush Operations](#category-a-brush-operations)
   - [Path-Based Tools](#category-b-path-based-tools)
   - [Generator Tools](#category-c-generator-tools)
   - [Region-Based Tools](#category-d-region-based-tools)
   - [Flood-Fill Tools](#category-e-flood-fill-tools)
5. [Detailed Specifications](#detailed-specifications)
6. [UI Patterns](#ui-patterns)
7. [Implementation Phases](#implementation-phases)
8. [Technical Notes](#technical-notes)

---

## Philosophy & Goals

### Core Metaphor: "Clay in My Hands"

Terrain should feel like sculpting clay — responsive, intuitive, powerful. The tools should:

- **Remove tedium** — One action should accomplish what currently takes 50+ manual operations
- **Enable creativity** — Unlock design patterns that builders currently avoid due to effort
- **Feel natural** — Operations should mirror real-world sculpting, painting, and construction
- **Provide control** — Power without unpredictability; always undo-able

### Design Principles

1. **Variants over separate tools** — One tool skeleton + multiple behavior variants = maximum power with minimal UI complexity (see Bridge tool pattern)
2. **Preview before commit** — Always show what will happen before modifying terrain
3. **Non-destructive when possible** — Live editing, undo support, blend modes
4. **Presets for speed** — One-click common configurations
5. **Parameters for precision** — Full control when needed

---

## Tool Categories

### Summary Matrix

| # | Tool | Category | Complexity | Primary Use |
|---|------|----------|------------|-------------|
| 1 | Trail | Path | Medium | Ground paths, roads |
| 2 | Terrace | Region | Medium | Stepped hillsides |
| 3 | Noise Sculpt | Brush | Medium | Organic texture |
| 4 | Gradient Paint | Brush | Medium | Material transitions |
| 5 | Clone/Stamp | Region | High | Repeat features |
| 6 | River/Channel | Path | Medium | Waterways |
| 7 | Slope Paint | Brush | Medium | Auto-texture by angle |
| 8 | Cavity Fill | Brush | Medium | Fix holes |
| 9 | Edge/Cliff | Path | Medium | Sharp boundaries |
| 10 | Megarandomizer | Brush | Medium | Material variation |
| 11 | Paint Can/Drip | Flood | Medium | Surface flood fill |
| 12 | Blob Connect | Generator | High | Organic linking |
| 13 | Variation Grid | Region | High | Pattern exploration |
| 14 | Growth Simulation | Generator | High | Organic expansion |
| 15 | Vein/Network | Path | High | Branching systems |
| 16 | Topology Morph | Region | High | State blending |
| 17 | Symmetricalizer | Region | High | Symmetric designs |
| 18 | Stalactite Gen | Generator | Medium | Cave formations |
| 19 | Tendril Gen | Generator | High | Organic growth |
| 20 | Melter | Brush | Medium | Gravity deformation |

---

## Implementation Architecture

### Current Codebase Structure

```
Src/
├── TerrainOperations/
│   ├── performTerrainBrushOperation.lua  — Main brush dispatcher
│   ├── SculptOperations.lua              — grow, erode, smooth
│   ├── OperationHelper.lua               — Brush power calculations
│   ├── smartLargeSculptBrush.lua         — Large brush optimization
│   └── smartColumnSculptBrush.lua        — Column-based operations
├── Util/
│   ├── TerrainEnums.lua                  — ToolId, BrushShape enums
│   └── Constants.lua                     — Defaults, limits
└── ...
```

### Proposed Additions

```
Src/TerrainOperations/
├── PathOperations.lua      (NEW) — Trail, River, Vein, Edge tools
├── GeneratorOperations.lua (NEW) — Stalactite, Tendril, Growth tools
├── RegionOperations.lua    (NEW) — Clone, Symmetry, Morph tools
├── FloodOperations.lua     (NEW) — Paint Can, Drip tools
└── NoiseUtils.lua          (NEW) — Perlin/noise helpers
```

### Implementation Patterns

#### Pattern A: Brush Operations
- Integrate into `performTerrainBrushOperation.lua`
- Add operation function to `SculptOperations.lua`
- Per-voxel processing within brush region
- Examples: Noise Sculpt, Slope Paint, Melter

#### Pattern B: Path-Based
- Follow Bridge tool pattern in `TerrainEditorModule.lua`
- Click-to-place waypoints → compute path → apply terrain
- State: startPoint, endPoint, waypoints[], variant
- Examples: Trail, River, Edge, Vein

#### Pattern C: Multi-Point/Generator
- Seed points → simulation algorithm → terrain output
- Often iterative (growth over time)
- State: seeds[], parameters, simulationState
- Examples: Stalactite, Tendril, Growth, Blob Connect

#### Pattern D: Region-Based
- Select region → transform → apply
- May involve capture/paste workflow
- State: sourceRegion, transform parameters
- Examples: Clone, Symmetry, Morph, Variation Grid

#### Pattern E: Flood-Fill
- Click point → spread across surface
- Queue-based traversal with priority
- State: visited{}, queue[], parameters
- Examples: Paint Can, Drip

---

## Tool Specifications

### Category A: Brush Operations

These integrate into the existing brush system via `performTerrainBrushOperation.lua`.

---

#### Tool 1: Noise Sculpt

**Purpose:** Add organic, natural-looking variation to terrain surfaces.

**Problem it solves:** Terrain often looks too smooth or artificially regular. Real terrain has bumps, cracks, weathered texture.

**State Variables:**
```lua
local noiseScale: number = 8        -- Wavelength of noise (1-32)
local noiseIntensity: number = 1    -- Amplitude multiplier (0.1-2.0)
local noiseSeed: number = 0         -- For reproducibility
local noiseVariant: string = "Bumpy"
```

**Variants:**
| Variant | Description | Use Case |
|---------|-------------|----------|
| Bumpy | Small-scale surface texture | Rock surfaces, orange peel |
| Rolling | Large-scale gentle undulation | Hills, dunes |
| Cracks | Ridge noise (absolute value) | Dried mud, fractured rock |
| Erosion | Directional bias | Wind/water carved surfaces |
| Volcanic | Bubbling/blistering pattern | Lava fields |

**Algorithm:**
```lua
local function noiseSculpt(options)
    local noiseValue = math.noise(
        options.worldX / noiseScale,
        options.worldZ / noiseScale,
        noiseSeed
    )
    
    -- Variant modifications
    if noiseVariant == "Cracks" then
        noiseValue = math.abs(noiseValue) * 2 - 1
    end
    
    local delta = noiseValue * noiseIntensity * options.brushOccupancy * options.strength
    local newOccupancy = math.clamp(options.cellOccupancy + delta, 0, 1)
    options.writeOccupancies[options.x][options.y][options.z] = newOccupancy
end
```

---

#### Tool 2: Gradient Paint

**Purpose:** Create smooth material transitions between two points.

**Problem it solves:** Natural terrain needs gradual transitions (beach→grass, grass→rock, snow line). Current Paint tool is binary.

**State Variables:**
```lua
local gradientMaterial1: Enum.Material = Enum.Material.Grass
local gradientMaterial2: Enum.Material = Enum.Material.Rock
local gradientWidth: number = 10
local gradientVariant: string = "Linear"
local gradientStartPoint: Vector3? = nil
local gradientEndPoint: Vector3? = nil
```

**Variants:**
| Variant | Description | Use Case |
|---------|-------------|----------|
| Linear | Straight line transition | General purpose |
| Radial | Circular spread from center | Craters, campfires |
| Altitude | Changes by Y height | Snow lines, water edges |
| Slope | Changes by terrain angle | Cliff faces |
| Noise | Perlin-based organic edge | Natural biome boundaries |

**Workflow:**
1. Click to set start point (material 1)
2. Click to set end point (material 2)
3. Brush applies gradient based on position

---

#### Tool 3: Slope Paint

**Purpose:** Automatically assign materials based on terrain steepness.

**Problem it solves:** Realistic terrain has grass on flat areas, rock on cliffs. Painting manually is exhausting.

**State Variables:**
```lua
local slopeFlatMaterial: Enum.Material = Enum.Material.Grass
local slopeSteepMaterial: Enum.Material = Enum.Material.Rock
local slopeCliffMaterial: Enum.Material = Enum.Material.Slate
local slopeThreshold1: number = 30   -- Degrees: flat → steep
local slopeThreshold2: number = 60   -- Degrees: steep → cliff
```

**Variants/Presets:**
| Preset | Flat | Steep | Cliff |
|--------|------|-------|-------|
| Natural | Grass | Rock | Slate |
| Arctic | Snow | Ice | Glacier |
| Desert | Sand | Sandstone | Rock |
| Volcanic | Basalt | Rock | CrackedLava |

**Algorithm:**
```lua
local function slopePaint(options)
    -- Calculate surface normal from occupancy gradients
    local gradX = getOccupancy(x+1,y,z) - getOccupancy(x-1,y,z)
    local gradY = getOccupancy(x,y+1,z) - getOccupancy(x,y-1,z)
    local gradZ = getOccupancy(x,y,z+1) - getOccupancy(x,y,z-1)
    
    local normal = Vector3.new(gradX, gradY, gradZ).Unit
    local slopeAngle = math.deg(math.acos(math.abs(normal.Y)))
    
    local material
    if slopeAngle < slopeThreshold1 then
        material = slopeFlatMaterial
    elseif slopeAngle < slopeThreshold2 then
        material = slopeSteepMaterial
    else
        material = slopeCliffMaterial
    end
    
    writeMaterial(x, y, z, material)
end
```

---

#### Tool 4: Paint Megarandomizer

**Purpose:** Apply multiple materials with weighted randomness for natural-looking variation.

**Problem it solves:** Natural terrain is never uniform. A forest floor has grass, mud, leaves. Currently requires painting one material at a time.
 c
**State Variables:**
```lua
local randomizerPalette: {{material: Enum.Material, weight: number}} = {
    {material = Enum.Material.Grass, weight = 0.6},
    {material = Enum.Material.Rock, weight = 0.25},
    {material = Enum.Material.Ground, weight = 0.15},
}
local randomizerClusterSize: number = 4   -- Patch coherence
local randomizerSeed: number = 0
local randomizerVariant: string = "Clustered"
```

**Variants:**
| Variant | Description | Use Case |
|---------|-------------|----------|
| Scatter | Pure random per-voxel | Gravel, debris |
| Clustered | Perlin-based patches | Natural ground |
| Spotted | Dominant + rare accents | Grass with flowers |
| Striped | Directional banding | Sedimentary rock |
| Altitude | Material by Y height | Single-stroke mountain |
| Radial | Material from center outward | Craters, scorch marks |

**Presets:**
| Preset | Materials |
|--------|-----------|
| Forest Floor | LeafyGrass 50%, Grass 25%, Mud 15%, Ground 10% |
| Rocky Hillside | Rock 40%, Grass 35%, Ground 15%, Slate 10% |
| Beach | Sand 60%, Ground 20%, Rock 15%, Water 5% |
| Volcanic | Basalt 45%, CrackedLava 30%, Rock 20%, Slate 5% |
| Arctic | Snow 50%, Ice 25%, Glacier 15%, Rock 10% |
| Swamp | Mud 40%, Water 25%, LeafyGrass 20%, Grass 15% |
| Ruins | Concrete 35%, Cobblestone 30%, Brick 20%, Ground 15% |

---

#### Tool 5: Cavity Fill

**Purpose:** Intelligently detect and fill terrain depressions/holes.

**Problem it solves:** After sculpting, terrain has unwanted gaps. Finding and fixing each is tedious.

**State Variables:**
```lua
local cavityFillVariant: string = "Smooth"
local cavitySensitivity: number = 0.5
```

**Variants:**
| Variant | Description | Use Case |
|---------|-------------|----------|
| Flat Fill | Fill to a plane | Building foundations |
| Smooth Fill | Blend with surroundings | Natural cleanup |
| Match Neighbors | Auto-material from nearby | Seamless repair |
| Lake Bed | Fill with water to level | Pond creation |

---

#### Tool 6: Melter

**Purpose:** Simulate terrain softening and flowing downward under gravity.

**Problem it solves:** Creating sagging, drooping, pooling terrain (lava, ice cream mountains, horror environments) is nearly impossible manually.

**State Variables:**
```lua
local meltViscosity: number = 0.5   -- 0=runny, 1=thick
local meltVariant: string = "Standard"
```

**Variants:**
| Variant | Behavior | Use Case |
|---------|----------|----------|
| Standard | Even melting | General deformation |
| Lava | Hot, runny, glows | Volcanic |
| Ice Cream | Medium viscosity, smooth | Surreal, cartoon |
| Wax | Thick, layered drips | Candle caves, horror |
| Collapse | Structural failure | Destruction |

**Algorithm:**
```lua
local function melt(options)
    local belowOcc = getOccupancy(x, y-1, z)
    local canFlow = belowOcc < 1 and options.cellOccupancy > 0
    
    if canFlow and options.brushOccupancy > 0.5 then
        local flowAmount = options.cellOccupancy * options.strength * (1 - meltViscosity) * 0.3
        
        -- Remove from current, add to below
        writeOccupancy(x, y, z, options.cellOccupancy - flowAmount)
        writeOccupancy(x, y-1, z, math.min(1, belowOcc + flowAmount))
        
        -- Transfer material
        if getMaterial(x, y-1, z) == Air then
            writeMaterial(x, y-1, z, options.cellMaterial)
        end
    end
end
```

**Note:** Needs multiple simulation passes per brush stroke.

---

### Category B: Path-Based Tools

These follow the Bridge tool pattern: define waypoints → compute path → apply terrain.

---

#### Tool 7: Trail Tool

**Purpose:** Create ground-level paths that conform to existing terrain.

**Problem it solves:** Bridge connects through air. Trail stays on ground for roads, hiking paths.

**State Variables:**
```lua
local trailWidth: number = 4
local trailVariant: string = "Conform"
local trailDepth: number = 1    -- For sunken
local trailHeight: number = 1   -- For raised
```

**Variants:**
| Variant | Description | Use Case |
|---------|-------------|----------|
| Flat | Levels path to average height | Roads through hills |
| Conform | Follows terrain, just smooths | Hiking trails |
| Sunken | Carves below surface | Streams, trenches |
| Raised | Builds above surface | Causeways, dikes |
| Banked | Tilts on curves | Race tracks |

**Key difference from Bridge:** Raycasts down to find terrain surface at each point.

---

#### Tool 8: River/Channel Tool

**Purpose:** Carve waterways with proper bank shaping and optional water fill.

**State Variables:**
```lua
local riverWidth: number = 6
local riverDepth: number = 4
local riverVariant: string = "River"
local riverFillWater: boolean = true
local riverWaterLevel: number = 0.8
```

**Variants:**
| Variant | Cross-Section | Use Case |
|---------|---------------|----------|
| Stream | Narrow, shallow | Small water features |
| River | Wide, U-shaped | Major waterways |
| Canyon | Deep, V-shaped | Dramatic canyons |
| Ravine | Steep V-shape | Erosion cuts |
| Dry Wash | Flat bottom | Desert arroyos |
| Lava Flow | Raised edges, fills with CrackedLava | Volcanic |

---

#### Tool 9: Edge/Cliff Tool

**Purpose:** Define sharp terrain boundaries and cliff faces.

**Problem it solves:** Creating clean cliff edges is difficult. Smooth and Erode round everything.

**State Variables:**
```lua
local cliffHeight: number = 10
local cliffVariant: string = "Sheer"
local cliffAngle: number = 90
```

**Variants:**
| Variant | Description | Use Case |
|---------|-------------|----------|
| Sheer | Perfect 90° vertical | Clean cuts |
| Stepped | Natural sedimentary layers | Realistic cliffs |
| Overhang | Top extends past bottom | Sea cliffs |
| Undercut | Bottom extends past top | Wave erosion |
| Fractured | Irregular with noise | Natural breaks |

---

#### Tool 10: Vein/Network Tool

**Purpose:** Create branching network structures (rivers, roots, caves, ridges).

**State Variables:**
```lua
local veinDepth: number = 3          -- Branching levels
local veinTaper: number = 0.7        -- Width reduction per level
local veinVariant: string = "RiverDelta"
local veinCarve: boolean = true      -- Carve vs build
```

**Variants:**
| Variant | Pattern | Use Case |
|---------|---------|----------|
| River Delta | Wide branching toward mouth | Estuaries |
| Root System | Branching downward | Tree roots |
| Lightning | Sharp angular branches | Cracks, scars |
| Leaf Veins | Central spine + sides | Decorative |
| Mycelium | Dense interconnected mesh | Cave networks |
| Mountain Ridges | Raised branching spines | Mountain ranges |

**Algorithm:** Recursive branching with random angle/length variation.

---

### Category C: Generator Tools

These use seed points and simulation algorithms.

---

#### Tool 11: Stalactite/Stalagmite Generator

**Purpose:** Generate hanging/rising spike formations for caves.

**State Variables:**
```lua
local stalactiteDensity: number = 0.5
local stalactiteMinHeight: number = 2
local stalactiteMaxHeight: number = 8
local stalactiteVariant: string = "Classic"
local stalactiteDirection: string = "Down"  -- Down or Up
```

**Variants:**
| Variant | Shape | Use Case |
|---------|-------|----------|
| Classic | Smooth conical | Limestone caves |
| Icicle | Thin, sharp, curved | Ice caves |
| Dripstone | Wavy, layered rings | Ancient caves |
| Crystal | Angular, faceted | Gem caves |
| Organic | Twisted, tendril-like | Alien, flesh |
| Columns | Stalactite meets stalagmite | Mature caves |
| Curtain | Thin wavy sheets | Flowstone |

---

#### Tool 12: Tendril/Life Generator

**Purpose:** Create organic reaching/branching forms (roots, vines, tentacles, coral).

**State Variables:**
```lua
local tendrilCount: number = 5
local tendrilLength: number = 20
local tendrilBranching: number = 3
local tendrilTwist: number = 0.5
local tendrilVariant: string = "Roots"
local tendrilGravity: number = 0      -- -1=down, 0=none, 1=up
local tendrilSurfaceAffinity: number = 0  -- 0=free, 1=cling
```

**Variants:**
| Variant | Behavior | Use Case |
|---------|----------|----------|
| Roots | Grow down, branch heavily | Tree roots |
| Vines | Climb surfaces, thin | Overgrown ruins |
| Tentacles | Thick base, taper, wavy | Alien, horror |
| Coral | Upward branching, fractal | Underwater |
| Mycelium | Dense network | Fungal caves |
| Nerves | Follow surfaces closely | Organic architecture |
| Brambles | Chaotic tangles | Cursed forests |

**Algorithm:** Growth simulation with steering behaviors (gravity, noise, surface attraction).

---

#### Tool 13: Growth Simulation

**Purpose:** Organic expansion from seed points that merge naturally.

**State Variables:**
```lua
local growthSeeds: {Vector3} = {}
local growthSpeed: number = 1
local growthPattern: string = "Cellular"
local growthMerge: string = "Blend"
```

**Variants:**
| Variant | Pattern | Use Case |
|---------|---------|----------|
| Cellular | Round, even expansion | Islands, plateaus |
| Branching | Fractal tree-like | Deltas, roots |
| Crystalline | Angular, geometric | Ice, minerals |
| Amoeba | Irregular, flowing | Organic caves |
| Competitive | Growths push each other | Tectonic, biomes |

---

#### Tool 14: Blob Connect

**Purpose:** Connect multiple seed points with organic, flowing terrain.

**State Variables:**
```lua
local blobSeeds: {Vector3} = {}
local blobTension: number = 0.5
local blobMergeBulge: number = 1.2
local blobVariant: string = "Blob"
```

**Variants:**
| Variant | Character | Use Case |
|---------|-----------|----------|
| Membrane | Thin stretched surface | Cave ceilings |
| Blob | Thick organic masses | Rock formations |
| Tendril | Thin reaching connections | Roots, vines |
| Plateau | Flat tops, organic edges | Connected mesas |
| Melt | Droopy, gravity-affected | Melting ice |

**Algorithm:** Metaball-style field function evaluated per voxel.

---

### Category D: Region-Based Tools

These operate on selected terrain regions with transformations.

---

#### Tool 15: Clone/Stamp

**Purpose:** Sample terrain region and replicate with variations.

**State Variables:**
```lua
local cloneSourceRegion: Region3? = nil
local cloneSourceData: {materials, occupancies}? = nil
local cloneVariant: string = "Exact"
local cloneBlendMode: string = "Replace"
```

**Variants:**
| Variant | Transform | Use Case |
|---------|-----------|----------|
| Exact | Pixel-perfect copy | Precise duplication |
| MirrorX | Flip X axis | Symmetric pairs |
| MirrorZ | Flip Z axis | Front/back pairs |
| Rotated | Apply rotation | Varied orientation |
| Noised | Add random variation | Natural repetition |
| Scaled | Resize | Different sizes |

**Blend Modes:**
| Mode | Behavior |
|------|----------|
| Replace | Overwrite target |
| Add | Add occupancies |
| Max | Take higher occupancy |
| Average | Blend 50/50 |

---

#### Tool 16: Variation Grid

**Purpose:** Generate grid of variations from single terrain feature.

**State Variables:**
```lua
local gridSize: Vector2 = Vector2.new(3, 3)
local variationAxes: {string} = {"rotation", "scale", "noise"}
```

**Variation Axes:**
- Rotation — Each cell rotated differently
- Scale — 50% to 150% range
- Noise seed — Same shape, different detail
- Height — Taller to shorter
- Material — Gradient across grid
- Erosion — Fresh to weathered

---

#### Tool 17: Symmetricalizer

**Purpose:** Transform terrain through mathematical symmetry operations.

*See [Detailed Specifications](#symmetricalizer-complete-specification) below.*

---

#### Tool 18: Topology Morph

**Purpose:** Blend between two terrain states.

**State Variables:**
```lua
local morphStateA: {materials, occupancies}? = nil
local morphStateB: {materials, occupancies}? = nil
local morphBlend: number = 0.5  -- 0=A, 1=B
local morphVariant: string = "Linear"
```

**Variants:**
| Variant | Blend Style | Use Case |
|---------|-------------|----------|
| Linear | Simple interpolation | Smooth morph |
| Dissolve | Random per-voxel | Scattered transition |
| Wipe | Directional | Progressive change |
| Radial | Center outward | Explosion/implosion |
| Noise | Perlin boundary | Organic transition |

---

### Category E: Flood-Fill Tools

---

#### Tool 19: Paint Can

**Purpose:** Surface-aware flood fill for materials.

**State Variables:**
```lua
local floodMaxRadius: number = 50
local floodSourceFilter: Enum.Material? = nil
local floodVariant: string = "Flood"
```

**Variants:**
| Variant | Behavior | Use Case |
|---------|----------|----------|
| Flood | Equal spread all directions | Repainting fields |
| Drip | Flows downhill, pools | Rain stains, lava |
| Splash | Radiates with decreasing intensity | Impact marks |
| Creep | Slow, respects boundaries | Moss, rust |
| Tide | Fills to Y-level | Flooding |
| Stain | Random spread, doesn't fill uniformly | Oil spills |

**Algorithm:** Priority queue-based flood fill with surface detection.

---

## Detailed Specifications

### Symmetricalizer — Complete Specification

#### Overview

The Symmetricalizer transforms terrain through mathematical symmetry operations, enabling creation of perfectly symmetric structures that would take hours to build manually.

#### Symmetry Types (12 Total)

**Mirror Family:**
| Type | Axis | Copies |
|------|------|--------|
| Mirror X | YZ plane | 2 |
| Mirror Z | XY plane | 2 |
| Mirror Y | XZ plane | 2 |
| Mirror XZ | Both | 4 |

**Radial Family:**
| Type | Segments | Angle |
|------|----------|-------|
| Radial-2 | 2 | 180° |
| Radial-3 | 3 | 120° |
| Radial-4 | 4 | 90° |
| Radial-5 | 5 | 72° |
| Radial-6 | 6 | 60° |
| Radial-8 | 8 | 45° |
| Radial-N | N | 360°/N |

**Compound Family:**
| Type | Description |
|------|-------------|
| Kaleidoscope-4 | Radial-4 + mirror within segments |
| Kaleidoscope-6 | Radial-6 + mirror within segments |
| Kaleidoscope-8 | Radial-8 + mirror within segments |

**Special Family:**
| Type | Description |
|------|-------------|
| Helical | Rotate + translate along axis |
| Translational | Repeat in direction |
| Fractal | Self-similar at scales |

#### State Variables

```lua
-- Core
local symmetryEnabled: boolean = false
local symmetryCenter: Vector3 = Vector3.zero
local symmetryAxis: Vector3 = Vector3.yAxis
local symmetryType: string = "Radial4"
local symmetrySegments: number = 4

-- Source
local symmetrySourceRegion: Region3? = nil
local symmetrySourceAngleStart: number = 0
local symmetrySourceAngleEnd: number = math.pi / 2

-- Live mode
local symmetryLiveMode: boolean = false
local symmetryPreviewParts: {BasePart} = {}

-- Helical
local helicalRisePerTurn: number = 20
local helicalTotalTurns: number = 2

-- Blend
local symmetryBlendSeams: boolean = true
local symmetrySeamWidth: number = 2
```

#### Workflow States

```
IDLE → PICKING_CENTER → CENTER_SET → DEFINING_SOURCE → READY → LIVE_EDITING
```

#### Core Algorithm

```lua
local function applySymmetry()
    local sourceMats, sourceOccs = terrain:ReadVoxels(symmetrySourceRegion, 4)
    local transforms = getSymmetryTransforms(symmetryType, symmetrySegments)
    
    for i = 2, #transforms do
        applyTransformedCopy(sourceMats, sourceOccs, sourceCenter, transforms[i])
    end
    
    if symmetryBlendSeams then
        blendSymmetrySeams(transforms)
    end
end

local function getSymmetryTransforms(symmetryType, segments)
    local transforms = {{rotation = CFrame.new(), mirror = false}}
    
    if symmetryType:match("^Radial%-") then
        for i = 1, segments - 1 do
            local angle = (i / segments) * math.pi * 2
            table.insert(transforms, {
                rotation = CFrame.Angles(0, angle, 0),
                mirror = false
            })
        end
    elseif symmetryType:match("^Kaleidoscope%-") then
        for i = 0, segments - 1 do
            local angle = (i / segments) * math.pi * 2
            table.insert(transforms, {
                rotation = CFrame.Angles(0, angle, 0),
                mirror = (i % 2 == 1) and "Radial" or false
            })
        end
    end
    -- ... other types
    
    return transforms
end
```

#### Presets

| Preset | Type | Use |
|--------|------|-----|
| Arena | Radial-4 | Combat arenas |
| Colosseum | Radial-8 | Large stadiums |
| Temple | Kaleidoscope-6 | Sacred geometry |
| Volcano | Radial-16 | Crater rims |
| Valley | MirrorZ | Symmetric canyons |
| SpiralTower | Helical | Ramps, towers |
| Snowflake | Kaleidoscope-6 | Intricate patterns |
| Crystal | Kaleidoscope-8 | Geometric caves |

#### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| S | Toggle tool |
| 1-8 | Quick select Radial-N |
| K | Toggle Kaleidoscope |
| L | Toggle Live mode |
| Enter | Apply |
| Escape | Cancel |
| C | Pick center |
| R | Define region |

---

## UI Patterns

### Variant Button Grid (from Bridge)

Used for tools with discrete variants:

```lua
local variantButtonsContainer = Instance.new("Frame")
variantButtonsContainer.Name = "VariantButtons"
variantButtonsContainer.BackgroundTransparency = 1
variantButtonsContainer.Size = UDim2.new(1, 0, 0, 0)
variantButtonsContainer.AutomaticSize = Enum.AutomaticSize.Y

local variantGridLayout = Instance.new("UIGridLayout")
variantGridLayout.CellSize = UDim2.new(0, 80, 0, 26)
variantGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
```

### Material Palette (for Megarandomizer)

Grid of material buttons with weight sliders:

```
┌─────────────────────────────────┐
│ [Grass ████████] 60% [−][+]    │
│ [Rock  ████    ] 25% [−][+]    │
│ [Mud   ██      ] 10% [−][+]    │
│ [Ground█       ]  5% [−][+]    │
│                                 │
│ [+ Add Material]                │
└─────────────────────────────────┘
```

### Two-Point Selection (for Gradient, Bridge-like tools)

```
Status: Click to set START
        Click to set END
        READY - Click to apply!
        
[Start: (123, 45, 67)]  [Clear Start]
[End:   (200, 45, 100)] [Clear End]
```

### Preview Toggle

All tools should have preview capability:

```lua
local previewEnabled = true
local previewParts: {BasePart} = {}

local function updatePreview()
    clearPreviewParts()
    if previewEnabled and hasValidSetup() then
        createPreviewVisualization()
    end
end
```

---

## Implementation Phases

### Phase 1: Quick Wins (Brush Operations)
**Estimated time:** 1-2 days each

1. ✅ Noise Sculpt — Already partially exists, extend with variants
2. Slope Paint — Simple angle calculation
3. Cavity Fill — Variation on Grow
4. Melter — Gravity-based flow

### Phase 2: Path Tools (Bridge Pattern)
**Estimated time:** 2-3 days each

5. Trail Tool — Bridge + ground conforming
6. River Tool — Bridge + carving + water fill
7. Edge/Cliff — Linear cut operation

### Phase 3: Paint Enhancements
**Estimated time:** 2-4 days each

8. Paint Megarandomizer — Complex UI, simple logic
9. Gradient Paint — Two-point interpolation
10. Paint Can/Drip — Flood fill algorithm

### Phase 4: Generators
**Estimated time:** 3-5 days each

11. Stalactite Gen — Surface spawn + cone generation
12. Tendril Gen — Growth simulation
13. Vein Network — Recursive branching

### Phase 5: Region Operations
**Estimated time:** 4-7 days each

14. Clone/Stamp — Capture + paste + transforms
15. Symmetricalizer — Full specification above
16. Blob Connect — Metaball evaluation
17. Growth Simulation — Cellular automata
18. Variation Grid — Systematic generation
19. Topology Morph — State interpolation

---

## Technical Notes

### Voxel System

- Voxel size: 4×4×4 studs (`Constants.VOXEL_RESOLUTION = 4`)
- Occupancy: 0-1 per voxel
- Materials: 22 terrain materials available
- API: `terrain:ReadVoxels()`, `terrain:WriteVoxels()`
- Fast path: `FillBall`, `FillBlock`, `FillCylinder`, `FillWedge`

### Performance Considerations

- Large brushes (>32 voxels) use `smartLargeSculptBrush` optimization
- Flood fill needs visited set to prevent infinite loops
- Preview parts should be minimal (wireframe preferred)
- Live mode needs debouncing for rapid changes

### Undo Support

All tools must bracket operations:

```lua
ChangeHistoryService:SetWaypoint("ToolName_Start")
-- ... do operation ...
ChangeHistoryService:SetWaypoint("ToolName_End")
```

### Material List

```lua
Grass, Sand, Rock, Ground, Snow, Ice, Glacier, Water,
Mud, Slate, Concrete, Brick, Cobblestone, Asphalt,
Pavement, Basalt, CrackedLava, Salt, Sandstone,
Limestone, LeafyGrass, WoodPlanks
```

### Noise Functions

Roblox provides `math.noise(x, y, z)` — returns -0.5 to 0.5.

For domain warping, ridge noise, FBM:

```lua
-- Ridge noise
local function ridgeNoise(x, y, z)
    return 1 - math.abs(math.noise(x, y, z) * 2)
end

-- Fractal Brownian Motion
local function fbm(x, y, z, octaves)
    local total = 0
    local amplitude = 1
    local frequency = 1
    for i = 1, octaves do
        total = total + math.noise(x * frequency, y * frequency, z * frequency) * amplitude
        amplitude = amplitude * 0.5
        frequency = frequency * 2
    end
    return total
end
```

---

## Inspiration Sources

### Design Study (Figure 51/52)

The variation study showing 16 dots transformed into 9 organic connected shapes inspired:
- Blob Connect (discrete points → fluid connections)
- Variation Grid (systematic exploration)
- Growth Simulation (organic expansion)
- Vein Network (branching connections)
- Topology Morph (fluid transformation)

Key principles:
- Discrete elements can merge into organic wholes
- Systematic variation reveals design space
- Connection patterns follow natural rules
- Growth and flow create emergent complexity

---

## Future Ideas (Not Yet Specified)

- **Erosion Simulation** — Physics-based weathering over time
- **Biome Painter** — Large-scale material zones with transition rules
- **Heightmap Import** — Load grayscale images as terrain
- **Terraform Presets** — One-click mountain, valley, island, etc.
- **Destruction Tool** — Realistic crater/explosion damage
- **Vegetation Scatter** — Place terrain + spawn vegetation points

---

*End of document*

