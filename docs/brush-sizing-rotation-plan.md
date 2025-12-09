# Brush Multi-Axis Sizing & Rotation Plan

## Overview

This document outlines how to extend the terrain editor to support:
1. **Multi-axis sizing** — X, Y, Z dimensions per brush shape
2. **Brush rotation** — User-controlled orientation via a rotate gizmo

---

## Part 1: Multi-Axis Sizing

### Current State

Currently, the brush has a single `brushSize` value:

```lua
-- TerrainEditorModule.lua (line 39)
local brushSize: number = Constants.INITIAL_BRUSH_SIZE

-- Line 537-538: Both dimensions use the same value
cursorSize = brushSize,
cursorHeight = brushSize,
```

### Sizing Requirements by Shape

| Shape | Dimensions | Description |
|-------|------------|-------------|
| **Sphere** | 1 (uniform) | Single radius, X=Y=Z always |
| **Cube** | 3 (X, Y, Z) | Full box, each axis independent |
| **Cylinder** | 2 (radius, height) | Radius for X/Z, separate height for Y |
| **Wedge** | 3 (X, Y, Z) | Full wedge dimensions |
| **Cone** | 2 (radius, height) | Base radius, height |
| **Capsule** | 2 (radius, height) | Radius for caps, total height |
| **Dome** | 1 or 2 | Radius (and optional height stretch) |
| **Ellipsoid** | 3 (X, Y, Z) | Each axis independent |
| **Torus** | 2 (major, minor radius) | Ring radius + tube radius |

### Proposed State Variables

```lua
-- Replace single brushSize with per-axis values
local brushSizeX: number = Constants.INITIAL_BRUSH_SIZE
local brushSizeY: number = Constants.INITIAL_BRUSH_SIZE  
local brushSizeZ: number = Constants.INITIAL_BRUSH_SIZE

-- Or alternatively, keep a primary "size" and use ratios:
local brushSize: number = Constants.INITIAL_BRUSH_SIZE
local brushAspectY: number = 1.0  -- Y as ratio of X
local brushAspectZ: number = 1.0  -- Z as ratio of X (for non-symmetric shapes)
```

### Shape Dimension Configuration

```lua
-- Define which axes each shape exposes
local ShapeDimensions = {
    [BrushShape.Sphere] = { "uniform" },           -- Single slider, X=Y=Z
    [BrushShape.Cube] = { "x", "y", "z" },         -- Three sliders
    [BrushShape.Cylinder] = { "radius", "height" }, -- Two sliders (radius=X=Z, height=Y)
    [BrushShape.Wedge] = { "x", "y", "z" },
    [BrushShape.Cone] = { "radius", "height" },
    [BrushShape.Ellipsoid] = { "x", "y", "z" },
}
```

### UI Approach

**Option A: Dynamic Sliders**
Show 1, 2, or 3 sliders based on current shape:
- Sphere: Shows "Size" (single)
- Cylinder: Shows "Radius" + "Height"  
- Cube: Shows "X" + "Y" + "Z" (or "Width" + "Height" + "Depth")

**Option B: Always Show Three, Disable Unused**
Always show X/Y/Z sliders. For Sphere, they're linked (changing one changes all). For Cylinder, X/Z are linked.

**Recommendation:** Option A with graceful transitions. When switching shapes, preserve reasonable values.

### Changes to opSet

```lua
local opSet = {
    -- ... existing fields ...
    cursorSize = brushSizeX,      -- Legacy/primary size
    cursorHeight = brushSizeY,    -- Already exists
    cursorDepth = brushSizeZ,     -- NEW: depth for 3D shapes
    -- Or alternatively:
    cursorSizeVec = Vector3.new(brushSizeX, brushSizeY, brushSizeZ),
}
```

### Changes to Brush Operations

**Fast path** (`performTerrainBrushOperation.lua`):
```lua
if brushShape == BrushShape.Cube then
    terrain:FillBlock(
        CFrame.new(centerPoint), 
        Vector3.new(sizeX, sizeY, sizeZ),  -- Use separate dimensions
        desiredMaterial
    )
end
```

**Slow path** (`OperationHelper.calculateBrushPowerForCell`):
For shapes with non-uniform scaling, normalize the cell vector before distance check:
```lua
-- For ellipsoid: scale cell vector to unit sphere space
local normalizedX = cellVectorX / radiusX
local normalizedY = cellVectorY / radiusY  
local normalizedZ = cellVectorZ / radiusZ
local distance = math.sqrt(normalizedX^2 + normalizedY^2 + normalizedZ^2)
brushOccupancy = math.max(0, math.min(1, (1 - distance) * minRadius / Constants.VOXEL_RESOLUTION))
```

---

## Part 2: Brush Rotation

### Current State

Brushes are axis-aligned. The only rotation is hardcoded for cylinder visualization:
```lua
-- Line 382: Cylinder rotated 90° to stand upright
brushPart.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
```

### Proposed State Variables

```lua
-- Store rotation as CFrame (orientation only, no position)
local brushRotation: CFrame = CFrame.new()  -- Identity = no rotation

-- Or as Euler angles for easier UI binding:
local brushRotationX: number = 0  -- Pitch (degrees)
local brushRotationY: number = 0  -- Yaw (degrees)  
local brushRotationZ: number = 0  -- Roll (degrees)
```

### UI: Rotation Gizmo Widget

**Concept:** A small widget showing three rotation rings (like Roblox's Rotate tool), where the user can drag to rotate the brush preview.

**Implementation Options:**

#### Option 1: Embedded Mini-Gizmo
A 2D representation in the UI panel showing X/Y/Z rotation arcs. User drags arcs to rotate.

```lua
-- Create a Frame containing 3 arc visualizations
local rotationWidget = Instance.new("Frame")
rotationWidget.Size = UDim2.new(0, 100, 0, 100)

-- Visual: Three overlapping circles/arcs representing each axis
-- User clicks and drags on the colored arcs to rotate
```

**Pros:** Self-contained, always visible  
**Cons:** 2D representation can be confusing

#### Option 2: 3D Gizmo in Viewport (Recommended)
Show actual 3D rotation handles around the brush preview. When user clicks on a rotation ring, they drag to rotate.

```lua
-- Create three torus/ring parts around the brush
local rotationGizmo = {
    xRing = createRotationRing(Color3.new(1, 0, 0)),  -- Red = X rotation
    yRing = createRotationRing(Color3.new(0, 1, 0)),  -- Green = Y rotation
    zRing = createRotationRing(Color3.new(0, 0, 1)),  -- Blue = Z rotation
}

-- Position around brush
-- On mouse hover, highlight the ring
-- On mouse drag, calculate rotation delta and apply
```

**Pros:** Intuitive 3D interaction, matches Roblox rotate tool  
**Cons:** More complex to implement, needs mouse handling in viewport

#### Option 3: Toggle Rotate Mode
Add a button/icon that, when clicked, switches to "rotation mode". Then mouse dragging on the brush rotates it.

```lua
-- Add rotation icon button to UI
local rotateButton = createButton(
    panel, "🔄", UDim2.new(...),
    function()
        rotationModeActive = not rotationModeActive
        -- Show/hide rotation gizmo
    end
)

-- When active, capture mouse movement and apply rotation
```

**Pros:** Clean, uncluttered default view  
**Cons:** Extra click to enter mode

### Applying Rotation to Brush Preview

```lua
local function updateBrushVisualization(position: Vector3)
    -- ... existing code ...
    
    local baseCFrame = CFrame.new(position)
    
    -- Combine position with user rotation
    local finalCFrame = baseCFrame * brushRotation
    
    if brushShape == BrushShape.Cylinder then
        -- Cylinder needs additional 90° rotation to stand upright
        finalCFrame = finalCFrame * CFrame.Angles(0, 0, math.rad(90))
    end
    
    brushPart.CFrame = finalCFrame
    brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
end
```

### Applying Rotation to Brush Operations

#### Fast Path (Native API)
All `Fill*` methods accept a CFrame, so rotation is straightforward:

```lua
terrain:FillBlock(
    CFrame.new(centerPoint) * brushRotation,  -- Rotated CFrame
    Vector3.new(sizeX, sizeY, sizeZ),
    desiredMaterial
)

terrain:FillCylinder(
    CFrame.new(centerPoint) * brushRotation * CFrame.Angles(0, 0, math.rad(90)),
    height, radius,
    desiredMaterial
)
```

#### Slow Path (Per-Voxel)
Transform each voxel's position into brush-local space before calculating distance:

```lua
function OperationHelper.calculateBrushPowerForCell(cellVectorX, cellVectorY, cellVectorZ,
    selectionSize, brushShape, radiusOfRegion, scaleMagnitudePercent, brushRotation)
    
    -- Transform world-space cell offset into brush-local space
    local localCellVector = brushRotation:Inverse() * Vector3.new(cellVectorX, cellVectorY, cellVectorZ)
    local localX = localCellVector.X
    local localY = localCellVector.Y
    local localZ = localCellVector.Z
    
    -- Now compute distance using local coordinates
    if brushShape == BrushShape.Sphere then
        local distance = math.sqrt(localX^2 + localY^2 + localZ^2)
        -- ... rest of calculation
    elseif brushShape == BrushShape.Cylinder then
        local distance = math.sqrt(localX^2 + localZ^2)  -- Ignore local Y
        -- ... rest of calculation
    end
end
```

### Changes to opSet

```lua
local opSet = {
    -- ... existing fields ...
    brushRotation = brushRotation,  -- CFrame (orientation only)
}
```

---

## Part 3: Implementation Roadmap

### Phase 1: Multi-Axis Sizing (Simpler)

1. **State changes**
   - Add `brushSizeY` (height) and optionally `brushSizeZ` to state
   - Define `ShapeDimensions` lookup table

2. **UI changes**
   - Create conditional slider rendering based on shape
   - When shape changes, show/hide appropriate sliders
   - Link sliders for shapes that require it (Sphere = all linked)

3. **opSet changes**
   - Pass `cursorSizeX`, `cursorSizeY`, `cursorSizeZ` (or keep `cursorSize`/`cursorHeight` for backward compat)

4. **Operation changes**
   - Update fast-path to use per-axis sizes
   - Update `calculateBrushPowerForCell` for ellipsoid/scaled shapes

5. **Visualization changes**
   - `brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)`

### Phase 2: Rotation (More Complex)

1. **State changes**
   - Add `brushRotation: CFrame = CFrame.new()`

2. **UI: Rotation gizmo**
   - Create rotation ring Parts as children of workspace (near brush)
   - Handle mouse detection on rings
   - Calculate rotation from mouse drag delta
   - Update `brushRotation` state

3. **Visualization changes**
   - Apply `brushRotation` to `brushPart.CFrame`

4. **Operation changes**
   - Pass `brushRotation` through opSet
   - Update fast-path to include rotation in CFrame
   - Update slow-path to inverse-transform cellVector

5. **Edge cases**
   - Reset rotation when changing tools? Or preserve?
   - Show current rotation angles in UI?
   - Snap to 45°/90° increments? (optional)

---

## File Changes Summary

| File | Changes |
|------|---------|
| `TerrainEditorModule.lua` | State vars, UI panels, visualization |
| `Src/Util/TerrainEnums.lua` | (Optional) Add rotation mode enum |
| `Src/Util/Constants.lua` | Default sizes per axis |
| `Src/TerrainOperations/performTerrainBrushOperation.lua` | Accept rotation, pass to fill methods |
| `Src/TerrainOperations/OperationHelper.lua` | Transform cellVector by rotation |
| `Src/TerrainOperations/smartLargeSculptBrush.lua` | Pass rotation to helpers |
| `Src/TerrainOperations/smartColumnSculptBrush.lua` | Pass rotation to helpers |

---

## Open Questions

1. **Rotation persistence:** Should rotation reset when changing brush shapes, or persist?
2. **Snapping:** Should rotation snap to common angles (15°, 45°, 90°)?
3. **Plane lock interaction:** How does a rotated brush interact with plane lock? The plane should probably stay horizontal regardless of brush rotation.
4. **Height consistency:** For rotated cylinders/wedges, which axis is "height"? Should it always be the brush-local Y, even if rotated?
5. **Performance:** Inverse-transforming every voxel adds overhead. Profile to ensure acceptable performance at large brush sizes.

