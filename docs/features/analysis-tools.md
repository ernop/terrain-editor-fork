# Analysis Tools

Read-only inspection tools that don't modify terrain. Used for debugging and understanding terrain structure.

---

## VoxelInspect

**Purpose:** Examine individual voxel data under the cursor.

### UI Panel

Shows real-time information:
- **World Position**: Stud coordinates (X, Y, Z)
- **Voxel Grid Position**: Integer voxel coordinates
- **Material**: Current Enum.Material value
- **Occupancy**: 0-1 fill value with visual bar

### Features

1. **Hover mode**: Updates continuously as cursor moves
2. **Lock mode**: Click to lock to a specific voxel for detailed inspection
3. **Highlight**: Shows a transparent Part at the inspected voxel location
4. **Edit mode**: When locked, can modify occupancy/material (advanced)

### State Keys

- `S.voxelInspectLocked: boolean`
- `S.voxelInspectPosition: Vector3?`
- `S.voxelInspectGridPos: Vector3?`
- `S.voxelInspectOccupancy: number`
- `S.voxelInspectMaterial: Enum.Material`
- `S.voxelInspectHighlight: Part?`

---

## ComponentAnalyzer

**Purpose:** Find disconnected terrain regions ("islands").

### Algorithm

1. **Scan terrain bounds**: Find min/max extent of non-air voxels
2. **Flood fill**: Starting from any solid voxel, mark connected voxels
3. **Repeat**: Find next unmarked solid voxel, flood fill again
4. **Report**: List all disconnected components with size and bounding box

### UI Panel

- **Progress bar**: Shows scan progress on large maps
- **Results list**: Each island with voxel count and center position
- **Highlight**: Click an island to highlight it with SelectionBox
- **Scan/Clear buttons**: Start analysis or reset

### Performance Note

Can be slow on large terrains. Uses batched processing with `task.wait()` to avoid freezing Studio.

---

## OccupancyOverlay

**Purpose:** Visualize occupancy values as a color gradient on terrain.

### Visualization

Color mapping:
- **Red** (1.0): Fully solid
- **Yellow** (0.5): Half occupancy
- **Green** (0.0+): Low occupancy
- **Transparent** (0.0): Air

### UI Panel

- **Toggle button**: Enable/disable overlay
- **Range slider**: Control visualization depth/radius around camera

### Implementation

Uses `SurfaceGui` or `BoxHandleAdornment` parts placed at voxel positions with color based on `ReadVoxels` occupancy values.

---

## Tool Traits

All Analysis tools share:

```lua
traits = {
    category = "Analysis",
    executionType = "uiOnly",  -- No per-voxel execution
    modifiesOccupancy = false,
    modifiesMaterial = false,
    usesBrush = false,
    usesStrength = false,
    needsMaterial = false,
}
```

The `execute = nil` for Analysis tools - they don't participate in the brush operation loop.

---

## Usage

1. Select Analysis tool from toolbar
2. Tool-specific panel appears in config area
3. Interact with terrain (hover, click, scan)
4. Review information in panel
5. Switch to another tool when done

Analysis tools are useful for:
- Learning how Roblox terrain works
- Debugging unexpected tool behavior
- Finding floating terrain pieces
- Understanding smooth vs sharp edges

