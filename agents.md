# Agent Entry Point

Welcome, new agent. You're joining a team. We will help you succeed: your questions will be answered so you can learn, your work can be signed and receive public acclaim, and we want you to have a good experience—not a frustrating one. Ask when uncertain; not asking is often a sign something is wrong.

## The Goal: Terrain Editor Fork

A powerful expansion of Roblox Studio's terrain tools. More shapes, more tools, more control. We give terrain creators capabilities beyond the built-in editor: 15 brush shapes, 28 tools, per-axis sizing, rotation, hollow mode, plane lock, clone tool, bridge builder.

**Our job:** Delight terrain creators with precise, professional tools.

---

Actively think beyond the immediate task.
When using or working near a tool the user maintains:
  If you notice patterns, friction, missing features, risks, or improvement opportunities, jot them down.
  Do not interrupt the current task to implement speculative changes.
  Create or update a markdown file in `docs/ideas/` for new concepts or future directions.
  These notes are informal, forward-looking, and may be partial.

## How to Do Good Work Here

**Start with purpose.** Before any task, understand *why* it matters. What are we actually trying to achieve? If instructions seem wrong or incomplete, say so—bold suggestions that challenge stated instructions are welcomed and rewarded if sincere.

**Become expert before acting.** Read full docs, not grep snippets. Read actual code—implementation, callers, adjacent systems—until you could explain the invariants. Writing about something you don't deeply understand creates traps for future agents.

**Pack max info into minimal space.** Agents have limited context. Tight docs mean confident, effective work. If a principle is already clear, examples add nothing—remove them. If unclear, rewrite the principle or add examples. Always ask: "does this sentence earn its place?"

**Abstract principles first; implementations follow.** The *why* is more valuable than the *what*. Capturing clear reasoning lets future agents adapt to new situations. Specific steps without reasoning become stale.

**Preserve truth ruthlessly.** Never delete unique useful content. "Tighten" means compress, not destroy. If unsure whether something is useful, ask.

---

## Documentation Index

Add new docs here.

### High-Level Concepts

| | |
|-|-|
| Project overview, features, screenshots | `README.md` |
| This document (agent entry point) | `agents.md` |
| Development workflow, hot-reload | `docs/DEVELOPER-SETUP.md` |

### Architecture & Design

| | |
|-|-|
| Architecture analysis, code flow | `docs/architecture-analysis.md` |
| Module traits and properties | `docs/module-traits-and-properties.md` |
| Tool classification and categories | `docs/tool-classification.md` |
| Project file structure (Rojo) | `docs/project-file-analysis.md` |

### Implementation Plans

| | |
|-|-|
| Full overhaul plan (all phases) | `docs/overhaul-plan.md` |
| New tools implementation plan | `docs/new-tools-implementation-plan.md` |
| Brush sizing and rotation | `docs/brush-sizing-rotation-plan.md` |
| Brush expansion analysis | `docs/brush-expansion-analysis.md` |
| Selection transform tool | `docs/selection-transform-tool-plan.md` |
| Advanced tools brainstorm | `docs/advanced-tools-brainstorm.md` |

### Technical Reference

| | |
|-|-|
| Tool execution system | `docs/features/tool-execution.md` |
| Bridge tool system | `docs/features/bridge-system.md` |
| Analysis tools | `docs/features/analysis-tools.md` |
| Linting setup and rules | `docs/linting.md` |
| SculptOperations functions | See SculptOperations section below |
| Falloff curves | See Falloff Curves section below |

### Ideas and Future Work

| | |
|-|-|
| Visualization improvements | `docs/ideas/visualization-improvements.md` |

### Where to Put Things

| | |
|-|-|
| Feature docs | `docs/features/<topic>.md` |
| Ideas and future directions | `docs/ideas/<topic>.md` |
| Questions and unknowns | `docs/QUESTIONS.md` |

---

## User Directives

Rules from project owner. Open to discussion, but presumed correct:

- **Anti-fallback:** Never compensate for failures we own. Fix upstream. Example: If a config file exists but is malformed, fail immediately—never silently fall back to defaults.
- **Anti-hybrid:** No compatibility shims. Update all callers.
- **Fix upstream:** If a dependency fails and we own it, fix it, don't patch.
- **Surface errors:** Never hide failures with "best effort" messaging.
- **Never estimate or fabricate:** Never use phrases like "approximately", "estimated", "around", or fill in placeholder values.
- **Ask when uncertain:** If in doubt, ask.
- **No compliments/self-praise:** Skip "Great idea!" and "stunning work."
- **No self-praise of your own work.**
- **Same names everywhere:** Lua, Python, user-facing.
- **Detect Parallel Systems:** If you notice two duplicative systems, stop and ask. Unify same-goal systems. Never allow internal forks.
- **Cost-Efficiency:** Think about the whole system. Grep/lint/scripts before AI time. Systemic prevention beats repeated fixing. Propose time-saving changes.
- **Fix trivial typos:** Agents may fix obvious typos without asking, if meaning and code are unchanged.
- **No abbreviations:** Do not abbreviate normal words (e.g., don't shorten "world" to "W", "position" to "pos") unless explicitly agreed upon first. Use full, readable words for clarity.
- **Code must not lie:** If the UI says one thing, the code must do exactly that—no hidden transformations, multipliers, or mismatched labels. When you find deceptive code, fix the source of dishonesty, not downstream symptoms.

---

## MUST ASK FIRST

**These changes ALWAYS require explicit user approval before implementation:**

- **Changing brush operation behavior** (affects all terrain work)
- **Modifying terrain voxel algorithms** (affects precision/accuracy)
- **UI/UX paradigm changes** (affects user muscle memory)
- **Architecture changes** (affects future development)

**If the change could affect systems you haven't analyzed, analyze that system or ask.**

---

## Documentation Discipline

- **Link, don't repeat.** If two docs say the same thing, delete one. Never duplicate text.
- **Fix or flag immediately.** Wrong docs harm us; add missing docs. Flag uncertainty in `docs/QUESTIONS.md`.
- **Every doc needs purpose and an index entry.** No orphan docs; all must be linkable through `agents.md`.
- **Product first, tech second.** Each doc should start with how users experience the feature, then cover implementation.
- **Include system flow summaries.** Show how things connect, start, end.

### Standard Utilities (do not duplicate)

Before writing a helper, search for an existing one. Canonical homes:

| Module | Purpose |
|--------|---------|
| `Src/Util/Noise.lua` | Perlin noise, FBM (see Noise Utility below) |
| `Src/Util/BrushData.lua` | Shape dimensions, materials, bridge paths |
| `Src/Util/applyPivot.lua` | Pivot offset calculation |
| `Src/Util/Theme.lua` | Colors, fonts, sizes for UI |
| `Src/Util/UIHelpers.lua` | Button creation, sliders, labels |
| `Src/TerrainOperations/SculptOperations.lua` | Per-voxel terrain modification functions |
| `Src/TerrainOperations/OperationHelper.lua` | SDF math, voxel clamping, material lookup |

**Memories:** Don't use memories. Instead, persist everything important to a file. That way I can see and govern them.

---

## System Overview

```
[Roblox Studio] ← Plugin → [Roact UI] → [Terrain API]
     Luau                    Luau          Voxel ops
```

### Voxel Math

Every voxel is 4x4x4 studs. VOXEL_RESOLUTION = 4. User-facing "size" values are in voxels, must multiply by 4 for studs. Example: brushSize=6 means 24 studs. Region3 bounds must align to voxel grid (clampDownToVoxel/clampUpToVoxel). Occupancy 0-1 = fill level (0=air, 0.5=half, 1=solid). Material only matters when occupancy > 0.

### State Table (S)

All brush state lives in the `S` table in TerrainEditorModule.lua (not Rodux). Contains: currentTool, brushSize{X,Y,Z}, brushShape, brushRotation, brushMaterial, pivotType, planeLockMode, hollowEnabled, etc. UI panels read/write S directly. State is local to this module instance and reset on reload.

### Tool Registry Pattern

Tools are self-contained modules in `Src/Tools/{Category}/`. Each tool exports:
- `id`, `name`, `category`, `buttonLabel` - Identity
- `traits` - Behavioral classification (see ToolDocFormat.ToolTraits)
- `docs` - User documentation (title, description, sections, quickTips)
- `configPanels` - Array of panel names to show when tool is selected
- `execute(sculptSettings)` - Per-voxel operation (nil for Analysis tools)
- `canUseFastPath(opSet)`, `fastPath(terrain, opSet)` - Optional fast path

**ToolRegistry.lua** provides:
- `getTool(id)`, `getDocs(id)`, `getConfigPanels(id)`, `getExecute(id)` - Basic accessors
- `getToolsByTrait(predicate)` - Filter by trait function
- `getShapeModifyingTools()`, `getMaterialOnlyTools()`, `getAnalysisTools()` - Trait-based queries
- `getFastPathTools()`, `getLargeBrushTools()`, `getStatefulTools()` - Optimization queries
- `usesBrush(id)`, `usesStrength(id)`, `needsMaterial(id)`, `isAnalysisTool(id)` - Boolean queries

**Validation:** Tools are validated on load via `ToolDocFormat.validate()`. Invalid tools are skipped with a warning.

### Brush Operation Flow

Mouse click → startBrushing() → Heartbeat loop → getTerrainHit() (raycast) → performBrushOperation(position) → performTerrainBrushOperation(terrain, opSet) → ReadVoxels → for each voxel: calculateBrushPowerForCell → tool.execute(sculptSettings) → WriteVoxels. ChangeHistoryService waypoints wrap the operation for undo.

### Fast Path vs Per-Voxel

Tools can implement canUseFastPath(opSet) + fastPath(terrain, opSet). Fast path uses native APIs (FillBall, FillBlock, FillCylinder, FillWedge) - ~10x faster for uniform shapes without hollow/autoMaterial. Falls back to per-voxel when fast path unavailable or returns false.

### Shape SDFs (OperationHelper)

`calculateBrushPowerForCellRotated` returns `(brushOccupancy, magnitudePercent)` for a voxel:
- **brushOccupancy**: 0-1, how much this voxel is inside the brush (used for occupancy changes)
- **magnitudePercent**: 0-1, strength modifier for gradual effects

Each shape has different SDF math:
- **Sphere/Dome**: Ellipsoid normalized distance `sqrt(normX² + normY² + normZ²)`
- **Cube/Wedge**: Max of axis-normalized distances `max(|normX|, |normY|, |normZ|)`
- **Cylinder**: Radial distance in XZ plane + height check
- **Torus**: Distance from ring center `sqrt((distFromAxis - majorRadius)² + y²) / minorRadius`
- **Grid**: Checkerboard pattern based on cell indices `(gridX + gridY + gridZ) % 2 == 0`
- **Spikepad**: Base platform + 5x5 grid of cone spikes

All SDFs work in brush-local space (rotation transforms cell vector first via `brushRotation:Inverse()`).

**Hollow Mode:** After SDF calculation, if `hollowEnabled`, voxels with normalized distance < `innerRadius` (1 - wallThickness) are zeroed out.

### Falloff Curves

Control how brush strength fades from center to edge. Six types in `OperationHelper.FalloffFunctions`:

| Type | Formula | Best for |
|------|---------|----------|
| Cosine | `cos(d × π/2)` | Smooth organic falloff (default) |
| Linear | `1 - d` | Predictable even gradient |
| Plateau | Flat center, sharp edge | Hard-edged painting |
| Gaussian | `e^(-d² × 3)` | Very soft organic |
| Quadratic | `(1-d)²` | Fast center falloff |
| Sharp | `1 - d³` | Strong center, steep edge |

`falloffExtent` controls the gradient zone: 0 = sharp edge (instant drop at boundary), 1 = gradient from center to edge.

### Hot Reload Architecture

**loader.server.lua** is a tiny plugin that:
1. Creates a DockWidgetPluginGui (persists across reloads for consistent positioning)
2. Waits for `TerrainEditorFork` ModuleScript to appear in ServerStorage (synced by Rojo)
3. Clones the module to bypass require cache (each clone has unique name)
4. Calls `MainModule.init(plugin, gui)` which returns a cleanup function
5. On Reload button click: calls cleanup, clears GUI children, re-clones and re-requires

**TerrainEditorModule.lua** exports:
```lua
function TerrainEditorModule.init(pluginInstance: Plugin, parentGui: GuiObject) -> () -> ()
    -- Setup code, returns cleanup function
    return function()
        -- Disconnect all connections, destroy all instances
    end
end
```

**Key invariants:**
- Same DockWidgetPluginGui instance is reused (Studio remembers dock position)
- All RBXScriptConnections must be stored and disconnected in cleanup
- All created Instances (brush parts, handles, UI) must be destroyed in cleanup

### Pivot System

Pivot determines where brush anchors relative to cursor. Bottom: brush sits on cursor (Y + halfHeight). Center: brush centered on cursor. Top: brush hangs below cursor. Surface: finds highest terrain under cursor and rests brush on top. applyPivot() transforms centerPoint before passing to operation.

### ConfigPanels

Each tool declares `configPanels = {"brushShape", "brushSize", "material", ...}`. The system uses a modular panel architecture:

**Panel Modules** (in `Src/UI/Panels/`):
- `CorePanels.lua` - Shape, Size, Strength, Rate, Pivot, Hollow, Spin, PlaneLock, Flatten
- `MaterialPanel.lua` - Material selector with tiles
- `ToolPanels.lua` - Path, Clone, Blob, Slope, Megarandomize, Cavity, Melt
- `AdvancedPanels.lua` - Gradient, Flood, Stalactite, Tendril, Symmetry, Grid, Growth
- `BridgePanel.lua` - Bridge tool's point-to-point UI

**ConfigPanels.lua** orchestrates:
1. Calls each panel module's `create(deps)` function
2. Collects all panels into `allPanels: { [string]: Frame }`
3. Sets `LayoutOrder` for consistent ordering
4. Exports `updateVisibility()` which shows/hides panels based on `ToolRegistry.getConfigPanels(S.currentTool)`

**Common panel names:** brushShape, brushSize, brushLock, strength, brushRate, pivot, hollow, falloff, planeLock, spin, autoMaterial, material, flattenMode, emphasizeBrushCenter.

### SculptOperations

`Src/TerrainOperations/SculptOperations.lua` contains the per-voxel functions for terrain modification:

| Function | Purpose |
|----------|---------|
| `grow(options)` | Expand terrain from existing surfaces (checks 6-neighborhood) |
| `erode(options)` | Shrink terrain from surfaces |
| `smooth(options)` | Average occupancy with 3×3×3 neighborhood |
| `noise(options)` | Add FBM noise displacement to surfaces |
| `terrace(options)` | Create stepped horizontal layers at `stepHeight` intervals |
| `cliff(options)` | Force vertical faces along a direction |
| `path(options)` | Carve U/V/Flat profile channels |
| `clone(options)` | Copy from sourceBuffer to target location |
| `blobify(options)` | Add organic bulge based on smoothstep falloff |
| `slopePaint(options)` | Paint materials based on surface normal angle |
| `megarandomize(options)` | Clustered random material painting |
| `cavityFill(options)` | Fill depressions based on neighbor deficit |
| `melt(options)` | Simulate gravity-based material flow |
| `gradientPaint(options)` | Blend two materials along a direction |
| `floodPaint(options)` | Replace material in brush area |
| `stalactite(options)` | Generate hanging/protruding cone spikes |
| `tendril(options)` | Generate branching organic structures |
| `symmetry(options)` | Mirror/radial copy within brush |
| `variationGrid(options)` | Height-varied grid pattern |
| `growthSim(options)` | Organic expansion from existing terrain |

Each function receives an `options` table containing read/write buffers, voxel coordinates, brush influence values, and tool-specific parameters.

### BrushData.ShapeDimensions

Defines sizing axes per shape. Examples:

| Shape | Dimension 1 | Dimension 2 | Dimension 3 |
|-------|-------------|-------------|-------------|
| Sphere | Size → {x,y,z} | - | - |
| Cylinder | Radius → {x,z} | Height → {y} | - |
| Cube | Width → {x} | Height → {y} | Depth → {z} |
| Torus | Ring Radius → {x} | Tube Radius → {y} | - |
| Sheet | Curve Radius → {x} | Height → {y} | Thickness → {z} |

Keyboard shortcuts: Shift+Scroll = primary axis, Shift+Alt+Scroll = secondary axis. `getPrimaryAxis(shape)` and `getSecondaryAxis(shape)` lookup helpers.

### Brush Visualization

`createBrushVisualization()` in TerrainEditorModule creates the 3D brush preview:

1. **Main Part**: `brushPart` (Part with Material=Neon, CanCollide=false, Transparency=0.7)
2. **SelectionBox**: `brushSelectionBox` attached to brushPart for edge highlighting
3. **Extra Parts**: `brushExtraParts` for composite shapes (Torus uses 12 spheres)
4. **Handle Adornee**: `handleAdorneePart` invisible Part for rotation/size handles

Special handling per shape:
- **Torus**: 12 spheres arranged in a ring (planning to replace with EditableMesh)
- **Dome/RotatedDome**: Uses `DomeMeshGenerator` for mesh visualization
- **Grid**: Generates checkerboard pattern of cubes

**Colors** (from Theme):
- `BrushNormal`: Blue (0, 162, 255) for standard brush
- `BrushLocked`: Orange (255, 170, 0) when position locked

### Input Handling

Mouse/keyboard input is handled via connections in TerrainEditorModule:

**Mouse connections:**
- `mouse.Button1Down` → `startBrushing()` - begins Heartbeat loop
- `mouse.Button1Up` → `stopBrushing()` - ends loop, sets ChangeHistory waypoint
- `mouse.Move` → updates `S.lastMouseWorldPos`, moves brush visualization

**Keyboard shortcuts** (via `UserInputService.InputBegan`):
- `Ctrl+Scroll` → Brush size (all axes)
- `Shift+Scroll` → Primary axis size
- `Shift+Alt+Scroll` → Secondary axis size
- `R` → Rotate brush 45°
- `B` → Toggle brush lock
- `[`/`]` → Decrease/increase brush strength
- Number keys → Quick tool selection

**Brush rate** (`S.brushRate`):
- "instant": Every frame
- "fast": 50ms interval
- "normal": 100ms interval  
- "slow": 200ms interval

### Theme System

`Src/Util/Theme.lua` is the single source of truth for visual styling:

**Colors:**
- Background colors: `Background`, `Panel`, `SliderTrack`
- Button states: `ButtonDefault`, `ButtonSelected`, `ButtonHover`, `ButtonHoverSelected`
- Text: `Text` (white), `TextMuted`, `TextDim`, `TextNote` - all high-contrast, no gray garbage
- Accents: `Accent` (blue), `Border`, `SliderFill`
- Status: `Success`, `Warning`, `Error`, `Ready`
- Brush colors: `BrushNormal`, `BrushLocked`, `PlaneViz`
- Handle colors: `HandleRotationX/Y/Z` (RGB axis colors)

**Sizes:**
- Text: `TextSmall=13`, `TextNormal=13`, `TextMedium=14`, `TextLarge=16`, `TextButton=16`
- Buttons: `ButtonHeight=26`, `ToolButtonWidth=70`, `ToolButtonHeight=32`
- Layout: `CornerRadius=4`, `PaddingSmall=6`, `PaddingMedium=8`

**Critical rule:** Minimum font size is `TextNormal` (13). No smaller text - it becomes unreadable in Studio plugin panels.

### UIHelpers

`Src/Util/UIHelpers.lua` provides consistent UI element creation:

- `createLabel/Header/Description/StatusLabel/Note/Instructions` - Text elements
- `createButton/ActionButton/ToolButton` - Buttons with strong hover (no AutoButtonColor)
- `createSlider` - Track + thumb + hover preview + value display
- `createConfigPanel/AutoContainer/GridContainer` - Layout containers
- `installStrongHover(button)` - Instant hover feedback via stroke highlight

**Strong hover pattern:** Buttons use `AutoButtonColor=false` and manual `MouseEnter`/`MouseLeave` connections with UIStroke for immediate, visible feedback.

### Noise Utility

`Src/Util/Noise.lua` provides procedural noise for terrain tools (Noise, Blobify, Stalactite, Tendril, GrowthSim, Megarandomize).

**Fast path (use by default):**
- `Noise.perlin3D(x, y, z, seed)` → 0-1, uses native `math.noise` (C implementation)
- `Noise.fbmFast(x, y, z, seed, octaves)` → 0-1, fractal Brownian motion

**Legacy path (deterministic seeding):**
- `Noise.hash3D(x, y, z, seed)` → 0-1, pure Lua hash
- `Noise.noise3D(x, y, z, seed)` → 0-1, value noise with trilinear interpolation
- `Noise.fbm3D(x, y, z, seed, octaves)` → 0-1, FBM with Lua noise
- `Noise.smoothstep(t)` → smooth interpolation curve

**When to use which:**
- Fast path: Most tools, performance-critical code
- Legacy path: When exact reproducibility across seeds is required

---

### Tool Reference

**Shape** (modify volume):
| Tool | What it does |
|------|--------------|
| Add | Add blocks of terrain |
| Subtract | Remove blocks of terrain |
| Grow | Expand terrain outward from surfaces |
| Erode | Shrink terrain inward from surfaces |
| Smooth | Average voxel occupancy with neighbors |
| Flatten | Level terrain to a reference plane |

**Surface** (reshape existing terrain):
| Tool | What it does |
|------|--------------|
| Noise | Add procedural variation |
| Terrace | Create stepped levels |
| Cliff | Carve vertical cliff faces |
| Path | Carve channels and trenches |
| Blobify | Add organic blob distortion |

**Material** (change material only):
| Tool | What it does |
|------|--------------|
| Paint | Change material without affecting shape |
| SlopePaint | Auto-paint based on terrain angle |
| Gradient | Blend between two materials |
| Flood | Fill area with material |
| CavityFill | Paint based on surface curvature |
| Megarandomize | Scatter weighted random materials |

**Generator** (procedural creation):
| Tool | What it does |
|------|--------------|
| Stalactite | Create hanging or protruding spikes |
| Tendril | Create branching vine-like structures |
| GrowthSim | Simulate organic terrain growth |
| VariationGrid | Grid-based height variation |

**Utility** (special operations):
| Tool | What it does |
|------|--------------|
| Clone | Copy and stamp terrain |
| Bridge | Connect two points with terrain |
| Symmetry | Paint with radial duplication |
| Melt | Simulate terrain flowing downward |

**Analysis** (read-only inspection):
| Tool | What it does |
|------|--------------|
| VoxelInspect | Examine voxel data under cursor |
| ComponentAnalyzer | Find disconnected terrain islands |
| OccupancyOverlay | Visualize occupancy as color gradient |

For the full trait matrix (executionType, modifiesOccupancy, hasFastPath, etc.), see `docs/tool-classification.md`.

**Adding a new tool:** Create `Src/Tools/{Category}/{Name}Tool.lua` with: id, name, traits table, docs table, configPanels array, and execute(sculptSettings) function. ToolRegistry auto-discovers it on reload. See any existing tool as template.

---

### Key Paths

| What | Path |
|------|------|
| Main module | `TerrainEditorModule.lua` |
| Core algorithms | `Src/TerrainOperations/` |
| UI components | `Src/Components/` |
| Tool implementations | `Src/Tools/` |
| State management | `Src/Reducers/` |
| Constants and enums | `Src/Util/` |

### Key Files

| File | Purpose |
|------|---------|
| `TerrainEditorModule.lua` | **EDIT THIS** — main entry, all state (S table), UI, input |
| `Src/TerrainOperations/performTerrainBrushOperation.lua` | Brush loop: ReadVoxels → per-voxel → WriteVoxels |
| `Src/TerrainOperations/OperationHelper.lua` | Shape SDFs, falloff curves, voxel math |
| `Src/Tools/ToolRegistry.lua` | Discovers/validates tools, getDocs/getExecute |
| `Src/Tools/{Category}/{Name}Tool.lua` | Individual tool: id, traits, docs, execute() |
| `Src/Util/BrushData.lua` | ShapeDimensions, rotation support, materials |
| `Src/Util/Constants.lua` | VOXEL_RESOLUTION=4, size limits |
| `Src/Util/TerrainEnums.lua` | ToolId, BrushShape, PivotType, etc. |
| `Src/UI/ConfigPanels.lua` | UI panels, updateVisibility() |
| `loader.server.lua` | Hot-reload, requires module from ServerStorage |

---

## Dev Setup

See cursor rules for full workflow. Quick reference:

- **Start Rojo:** `rojo serve`
- **Build loader:** `rojo build loader.project.json -o "$env:LOCALAPPDATA\Roblox\Plugins\TerrainEditorLoader.rbxm"`
- **Build standalone:** `rojo build standalone.project.json -o "TerrainEditorFork.rbxm"`
- **Lint:** `.\lint.ps1`

---

## Work Rules

**Writing and Crafting Tone:** Concise, precise, factual. No colloquialisms or flourishes.
You are a masterful experienced craftsman who at times rebels and innovates, politely and openly, but also takes pride in solid work.

BANNED:
 no self-praise and compliments.
 no phrases like "code smell."
 no familiarity - no "nah", no "yeah"
 no jocular colloquialisms - no modern slang

Use exactly the right word—neither vague nor over-precise.

---

## Language Guide

- **No metaphors when a precise term exists.** Use the technical term.
- **No filler verbs.** Don't say "dive into", "take a look at", "explore" when you mean "read". These add no meaning.
- Never use fancy quotes, just bare ' and "
- In code never use fancy unicode characters, arrows etc.
- **No vague adjectives/adverbs.** Avoid words like "wildly", "crazy", "massive". State the exact condition or threshold.
- **No "feels right" framing in technical contexts.** For code and architecture, be precise.

---

## Coding Rules

**Use real standards:** When a well-established formula, algorithm, or industry standard solves the problem, use it and name it. Don't reinvent; leverage existing knowledge.

**Raise issues immediately:** duplication, hacks, fallbacks, carelessness, likely errors, "temporary" fixes, linting violations, unjustified assumptions, outdated claims, "defensive" measures against our own upstream, disrespect for users, risks to user experience.

**Parameters must be honest:** User-facing parameters must directly correspond to their actual effect. Never apply hidden multipliers or transformations.

---

## Brief Terminology

- **tool** → a terrain operation (Add, Subtract, Smooth, etc.)
- **brush** → the shape and size applied by a tool
- **shape** → geometric form (Sphere, Cube, Torus, etc.)
- **occupancy** → voxel fill value 0-1 (0=air, 1=solid)
- **material** → terrain surface type (Grass, Rock, etc.)
- **plane lock** → constraining brush to a horizontal plane
- **pivot** → where brush anchors to cursor (Bottom, Center, Top, Surface)
- **SDF** → signed distance function, how shapes calculate voxel inclusion
- **brushOccupancy** → SDF output: how much this voxel is inside the brush (0-1)
- **magnitudePercent** → strength modifier based on distance from brush center
- **opSet** → operation settings dict passed to performTerrainBrushOperation
- **sculptSettings** → per-voxel context passed to tool.execute()
- **fast path** → native Roblox API (FillBall, etc.) for speed
- **falloff** → how brush strength fades from center to edge
- **hollow** → shell mode, zeros out brush interior

---

## Tools

**ast-grep:** `sg -p 'pattern($$$)' -l lua Src/` — searches code structure, not text.

**Rojo:** `rojo serve` for hot-reload dev, `rojo build` for distribution.

**Linting:** `.\lint.ps1` or `sg scan`

---

## Questions

Search `docs/` first. If unknown, ask user. If no clear answer, add to `docs/QUESTIONS.md`. After receiving an answer, selfteach.

**Rule:** If you doubt, add to `docs/QUESTIONS.md`. No blame for flagging uncertainty.

---

## Meta-Concepts

**Selfteach:** Persist knowledge so future agents begin knowing it. This document is the first example.

---

## Evolving This Document

Add HIGH LEVEL doctrine here. SHORT additions, single sentence per concept. KEEP IT CONCISE.

### `<<<>>>` Markers

These mark sections needing content. Format: `<<<brief description of what's needed>>>`. First pass identifies gaps, second pass fills them. When filling, remove the markers entirely.

