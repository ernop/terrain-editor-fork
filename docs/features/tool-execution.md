# Tool Execution System

How terrain tools are discovered, validated, and executed.

---

## Tool Discovery

`ToolRegistry.lua` auto-discovers tools on module load:

1. Scans all subfolders of `Src/Tools/` (Shape, Surface, Material, Generator, Utility, Analysis)
2. Requires each `*Tool.lua` file
3. Validates against `ToolDocFormat.lua` schema
4. Stores in internal registry keyed by `tool.id`

```lua
-- Registration happens automatically when ToolRegistry is required
local tool = require(toolModule)
if validateTool(tool) then
    registry[tool.id] = tool
end
```

---

## Tool Structure

Each tool module exports:

```lua
return {
    id = "MyTool",          -- Unique identifier, matches TerrainEnums.ToolId
    name = "My Tool",       -- Display name
    category = "Shape",     -- For folder organization (optional)
    buttonLabel = "My",     -- Short label for toolbar button
    
    traits = {
        category = "Shape",
        executionType = "perVoxel",  -- or "columnBased", "pointToPoint", "uiOnly"
        modifiesOccupancy = true,
        modifiesMaterial = true,
        hasFastPath = false,
        hasLargeBrushPath = false,
        requiresGlobalState = false,
        usesBrush = true,
        usesStrength = true,
        needsMaterial = true,
    },
    
    docs = {
        title = "My Tool",
        subtitle = "Short description",
        description = "Longer description of what it does",
        sections = { ... },
        quickTips = { "Tip 1", "Tip 2" },
    },
    
    configPanels = { "brushShape", "brushSize", "strength", "material" },
    
    execute = function(sculptSettings)
        -- Per-voxel operation
    end,
    
    -- Optional: Fast path for native API optimization
    canUseFastPath = function(opSet)
        return not opSet.hollowEnabled and not opSet.autoMaterial
    end,
    fastPath = function(terrain, opSet)
        -- Use Terrain:FillBall, FillBlock, etc.
        return true  -- success
    end,
}
```

---

## Execution Flow

### Per-Voxel Tools (most tools)

```
Mouse Click
    ↓
startBrushing()
    ↓
RunService.Heartbeat loop
    ↓
getTerrainHit() → raycast to find brush position
    ↓
performBrushOperation(position)
    ↓
Build opSet table with all settings
    ↓
performTerrainBrushOperation(terrain, opSet)
    ↓
┌─────────────────────────────────────┐
│ Check fast path:                    │
│   if canUseFastPath(opSet):        │
│     if fastPath(terrain, opSet):   │
│       return (done)                │
└─────────────────────────────────────┘
    ↓
Calculate bounds (with rotation padding if needed)
    ↓
terrain:ReadVoxels(region) → readMaterials, readOccupancies
terrain:ReadVoxels(region) → writeMaterials, writeOccupancies
    ↓
For each voxel (x, y, z):
    ↓
    calculateBrushPowerForCellRotated() → (brushOccupancy, magnitudePercent)
    ↓
    Build sculptSettings with voxel-specific values
    ↓
    toolExecute(sculptSettings)  ← Per-voxel function from tool
    ↓
terrain:WriteVoxels(region, writeMaterials, writeOccupancies)
```

### Column-Based Tools (Flatten)

Uses `smartColumnSculptBrush.lua` for processing columns instead of individual voxels.

### Point-to-Point Tools (Bridge)

Does not use the standard brush loop. Instead:
1. First click sets `bridgeStartPoint`
2. Second click sets `bridgeEndPoint`
3. Path is generated using `BridgePathGenerator`
4. Series of brush operations along the path

---

## sculptSettings Table

Passed to `tool.execute()` for each voxel:

```lua
{
    -- Voxel position
    x = 5,                    -- Voxel X index in buffer
    y = 12,                   -- Voxel Y index
    z = 8,                    -- Voxel Z index
    worldX = 48.0,            -- World X coordinate (studs)
    worldY = 96.0,            -- World Y coordinate
    worldZ = 64.0,            -- World Z coordinate
    
    -- Cell vectors (offset from brush center)
    cellVectorX = 8.0,        -- Studs from brush center X
    cellVectorY = -4.0,       -- Studs from brush center Y
    cellVectorZ = 2.0,        -- Studs from brush center Z
    
    -- Brush influence at this voxel
    brushOccupancy = 0.85,    -- 0-1, how much voxel is inside brush
    magnitudePercent = 0.7,   -- 0-1, strength modifier from falloff
    
    -- Current voxel state
    cellOccupancy = 0.5,      -- Current occupancy value
    cellMaterial = Enum.Material.Grass,
    
    -- Buffer references
    readMaterials = {...},    -- 3D table (read-only)
    readOccupancies = {...},  -- 3D table (read-only)
    writeMaterials = {...},   -- 3D table (write to this)
    writeOccupancies = {...}, -- 3D table (write to this)
    
    -- Region dimensions
    sizeX = 16,               -- Total voxels in X
    sizeY = 16,               -- Total voxels in Y
    sizeZ = 16,               -- Total voxels in Z
    
    -- Operation parameters
    strength = 0.5,
    desiredMaterial = Enum.Material.Rock,
    autoMaterial = false,
    ignoreWater = true,
    airFillerMaterial = Enum.Material.Air,  -- or Water if underwater
    
    -- Plus all tool-specific parameters from opSet...
}
```

---

## Fast Path Details

Fast path uses native Terrain APIs for maximum performance:

| Shape | API | Condition |
|-------|-----|-----------|
| Sphere | `Terrain:FillBall(center, radius, material)` | No hollow, uniform size |
| Cube | `Terrain:FillBlock(cframe, size, material)` | No hollow |
| Cylinder | `Terrain:FillCylinder(cframe, height, radius, material)` | No hollow |
| Wedge | `Terrain:FillWedge(cframe, size, material)` | No hollow |

Fast path is ~10x faster than per-voxel for large brushes.

**Disqualifying conditions:**
- `hollowEnabled = true`
- `autoMaterial = true`
- Non-uniform sizing for shapes that don't support it
- Rotation (for shapes that don't have rotated Fill APIs)

