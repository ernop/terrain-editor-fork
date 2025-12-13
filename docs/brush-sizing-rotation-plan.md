# Brush Multi-Axis Sizing & Rotation

## ✅ IMPLEMENTED (v0.0.00000028)

This document describes the multi-axis sizing and rotation features that have been implemented for the terrain editor brushes.

---

## Features Overview

### Available Brush Shapes
| Shape | Description | Sizing | Rotation |
|-------|-------------|--------|----------|
| **Sphere** | Round ball | Uniform (X=Y=Z) | ❌ No |
| **Cube** | Box/block | X, Y, Z independent | ✅ Yes |
| **Cylinder** | Vertical cylinder | Radius + Height | ✅ Yes |
| **Wedge** | Ramp/slope | X, Y, Z independent | ✅ Yes |
| **Corner** | Corner wedge/ramp | X, Y, Z independent | ✅ Yes |
| **Dome** | Half-sphere (top) | Radius + Height | ❌ No |

### Multi-Axis Sizing
Each brush shape now supports appropriate per-axis sizing based on its geometry.

### Brush Rotation
Most brushes can be rotated in 3D space using intuitive handle controls (except Sphere and Dome which are rotationally symmetric).

### Lock Mode
Press **R** to lock the brush in place for handle interaction.

---

## How to Use

### Basic Workflow

1. **Select a tool** (Add, Sculpt, Subtract, etc.)
2. **Choose a shape** (Sphere, Cube, or Cylinder)
3. **Hover over terrain** to see the brush preview
4. **Press R** to lock the brush in place
   - Brush turns **orange** when locked
   - Brush no longer follows mouse
   - Painting is disabled while locked
5. **Drag the handles**:
   - **Orange rings** (ArcHandles) = Rotation
   - **Cyan arrows** (Handles) = Resize
6. **Press R again** to unlock
   - Brush turns **blue** and follows mouse
   - Painting resumes

### Visual Feedback

| State | Brush Color | Mouse Behavior | Can Paint |
|-------|-------------|----------------|-----------|
| Normal | 🔵 Blue | Follows mouse | ✅ Yes |
| Locked | 🟠 Orange | Stationary | ❌ No |

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **R** | Toggle brush lock mode |
| **Shift+Scroll** | Adjust primary dimension (or uniform) |
| **Shift+Alt+Scroll** | Adjust secondary dimension |
| **Ctrl+Scroll** | Adjust brush strength |

#### Shape-Specific Scroll Behavior

Each shape has intelligently chosen primary/secondary dimensions for quick resizing:

| Shape | Shift+Scroll (Primary) | Shift+Alt+Scroll (Secondary) |
|-------|------------------------|------------------------------|
| Sphere | Size (all) | — |
| Cube | XZ (footprint) | Y (height) |
| Cylinder | Radius (X=Z) | Height (Y) |
| Wedge | XZ (footprint) | Y (height) |
| CornerWedge | XZ (footprint) | Y (height) |
| Dome | Radius (X=Z) | Height (Y) |
| Torus | Ring Radius (X) | Tube Radius (Y) |
| Ring | Radius (X) | Thickness (Y) |
| ZigZag | XZ (footprint) | Y (height) |
| Sheet | Arc Radius (X) | Thickness (Y) |
| Grid | Size (all) | — |
| Stick | Length (Y) | Thickness (X=Z) |
| Spinner | Size (all) | — |
| Spikepad | Base Size (X=Z) | Spike Height (Y) |

---

## Shape-Specific Behavior

### Sphere
- **Sizing**: Uniform (single value controls all axes)
- **Rotation**: Not supported (sphere is rotationally symmetric)
- **Handles**: Size handles only, all axes linked
- **Fast Path**: Uses `FillBall` API

### Cube
- **Sizing**: Independent X, Y, Z
- **Rotation**: Full 3D rotation supported
- **Handles**: Both rotation rings and size handles
- **UI Sliders**: Shows X, Y, Z separately
- **Fast Path**: Uses `FillBlock` API

### Cylinder
- **Sizing**: Radius (X=Z linked) + Height (Y)
- **Rotation**: Full 3D rotation supported
- **Handles**: Both rotation rings and size handles
- **UI Sliders**: Shows Radius and Height
- **Note**: Cylinder stands upright by default (height along Y axis)
- **Fast Path**: Uses `FillCylinder` API

### Wedge
- **Sizing**: Independent X, Y, Z
- **Rotation**: Full 3D rotation supported
- **Handles**: Both rotation rings and size handles
- **UI Sliders**: Shows X, Y, Z separately
- **Use Case**: Creating ramps, slopes, diagonal terrain cuts
- **Fast Path**: Uses `FillWedge` API

### Corner Wedge
- **Sizing**: Independent X, Y, Z
- **Rotation**: Full 3D rotation supported
- **Handles**: Both rotation rings and size handles
- **UI Sliders**: Shows X, Y, Z separately
- **Use Case**: Corner ramps, natural cliff transitions
- **Implementation**: Per-voxel processing (no native API)

### Dome
- **Sizing**: Radius (X=Z linked) + Height (Y)
- **Rotation**: Not supported (dome is symmetric around Y axis)
- **Handles**: Size handles only
- **UI Sliders**: Shows Radius and Height
- **Use Case**: Hills with flat bases, domes, craters (inverted)
- **Implementation**: Per-voxel processing (half-sphere, top only)

---

## Technical Implementation

### State Variables

```lua
-- Per-axis sizing
local brushSizeX: number = Constants.INITIAL_BRUSH_SIZE
local brushSizeY: number = Constants.INITIAL_BRUSH_SIZE
local brushSizeZ: number = Constants.INITIAL_BRUSH_SIZE

-- Rotation (CFrame, orientation only)
local brushRotation: CFrame = CFrame.new()

-- Lock mode
local brushLocked: boolean = false
local lockedBrushPosition: Vector3? = nil

-- Handle interaction
local isHandleDragging: boolean = false
```

### Shape Capability Tables

```lua
-- Which shapes support rotation
local ShapeSupportsRotation = {
    [BrushShape.Sphere] = false,       -- No point rotating a sphere
    [BrushShape.Cube] = true,
    [BrushShape.Cylinder] = true,
    [BrushShape.Wedge] = true,
    [BrushShape.CornerWedge] = true,
    [BrushShape.Dome] = false,         -- Symmetric around Y axis
}

-- How each shape handles sizing
local ShapeSizingMode = {
    [BrushShape.Sphere] = "uniform",    -- X=Y=Z always
    [BrushShape.Cube] = "box",          -- X, Y, Z independent
    [BrushShape.Cylinder] = "cylinder", -- X=Z (radius), Y (height)
    [BrushShape.Wedge] = "box",         -- X, Y, Z independent
    [BrushShape.CornerWedge] = "box",   -- X, Y, Z independent
    [BrushShape.Dome] = "cylinder",     -- X=Z (radius), Y (height)
}
```

### 3D Handles

**Rotation Handles (ArcHandles)**
- Orange colored
- Parented to CoreGui
- Adornee set to brushPart
- Only visible for shapes that support rotation
- Events: MouseButton1Down, MouseButton1Up, MouseDrag

**Size Handles (Handles)**
- Cyan colored
- Style: Resize
- Parented to CoreGui
- Adornee set to brushPart
- Visible for all shapes
- Behavior varies by ShapeSizingMode

### Operation Changes

The terrain brush operations now receive:

```lua
local opSet = {
    cursorSizeX = brushSizeX,
    cursorSizeY = brushSizeY,
    cursorSizeZ = brushSizeZ,
    brushRotation = brushRotation,
    -- ... other fields
}
```

**Fast Path** (native Roblox API):
- `FillBlock` uses rotated CFrame directly
- `FillCylinder` uses rotated CFrame
- `FillBall` ignores rotation (sphere)

**Slow Path** (per-voxel processing):
- `OperationHelper.calculateBrushPowerForCellRotated` transforms voxel coordinates into brush-local space before calculating influence

---

## Files Modified

| File | Changes |
|------|---------|
| `TerrainEditorModule.lua` | State vars, lock mode, handles, UI sliders, keyboard input |
| `Src/TerrainOperations/performTerrainBrushOperation.lua` | Accept per-axis sizes and rotation |
| `Src/TerrainOperations/OperationHelper.lua` | New functions for rotated/axis-aligned brush power |
| `Src/TerrainOperations/smartLargeSculptBrush.lua` | Pass rotation to helpers |
| `Src/TerrainOperations/smartColumnSculptBrush.lua` | Pass rotation to helpers |

---

## Future Enhancements

Potential improvements for later:
- [ ] Snap rotation to 15°/45°/90° increments (hold Shift while dragging?)
- [ ] Show current rotation angles in UI
- [ ] Reset rotation button
- [ ] Remember rotation per-shape
- [ ] Keyboard shortcuts for quick 90° rotations
- [ ] Visual axis indicators on locked brush

---

## Original Planning Document

The sections below contain the original planning notes that led to this implementation.

<details>
<summary>Click to expand original planning notes</summary>

### Original Sizing Requirements by Shape

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

### Original UI Options Considered

**Option A: Dynamic Sliders** (Implemented)
Show 1, 2, or 3 sliders based on current shape.

**Option B: Always Show Three**
Always show X/Y/Z sliders, link them for some shapes.

### Original Rotation Options Considered

**Option 1: Embedded Mini-Gizmo**
2D representation in UI panel - rejected as confusing.

**Option 2: 3D Gizmo in Viewport** (Implemented via ArcHandles)
Actual 3D rotation handles around the brush preview.

**Option 3: Toggle Rotate Mode**
Button to enter rotation mode - partially implemented as Lock Mode.

</details>
