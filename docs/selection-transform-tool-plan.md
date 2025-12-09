# Selection & Transform Tool Implementation Plan

## Overview

A new tool that allows users to:
1. **Draw a cube** to select a terrain region
2. **Transform the selection** with rotation handles, move handles
3. **Copy/paste** terrain regions
4. **Smooth, intuitive controls** for all operations

This tool combines selection, transformation, and clipboard operations into a unified workflow.

---

## Architecture

### Tool Flow

```
1. User selects "Transform" tool
2. Click + drag to draw selection cube
3. Selection cube shows with handles:
   - Rotation handles (ArcHandles) - 3 rings for X/Y/Z rotation
   - Move handles (Handles) - arrows for translation
   - Corner/edge handles - for resizing selection
4. User manipulates handles → transforms terrain in real-time
5. Copy/paste operations work on selection
```

### Data Structure

```lua
-- State in TerrainEditorModule.lua
S.selectionRegion = nil :: Region3?          -- Current selection bounds
S.selectionCFrame = nil :: CFrame?           -- Selection transform (position + rotation)
S.selectionSize = nil :: Vector3?            -- Selection dimensions
S.selectionData = nil :: {                    -- Cached voxel data
    materials: {[number]: {[number]: {[number]: Material}}},
    occupancies: {[number]: {[number]: {[number]: number}}},
    region: Region3,
    originalCFrame: CFrame,  -- Original position when selected
}
S.selectionVisualization = nil :: Part?      -- Visual cube showing selection
S.selectionHandles = nil :: ArcHandles?      -- Rotation handles
S.selectionMoveHandles = nil :: Handles?     -- Move handles
S.selectionResizeHandles = nil :: Handles?   -- Resize handles
S.isDrawingSelection = false                 -- Currently drawing new selection
S.clipboardData = nil :: {...}?              -- Copied selection data
```

---

## Implementation Steps

### Phase 1: Selection Drawing

#### 1.1 Add Tool to UI
- Add "Transform" button to tool panel
- Wire up `selectTool(ToolId.Transform)` handler

#### 1.2 Selection Drawing Logic
- On mouse down: start drawing selection
- On mouse drag: update selection cube size
- On mouse up: finalize selection, read voxel data
- Visual feedback: semi-transparent cube showing selection bounds

**Key Code Location:** `TerrainEditorModule.lua` mouse event handlers

#### 1.3 Read Selection Data
```lua
local function captureSelection(region: Region3)
    local materials, occupancies = terrain:ReadVoxels(region, Constants.VOXEL_RESOLUTION)
    S.selectionData = {
        materials = materials,
        occupancies = occupancies,
        region = region,
        originalCFrame = CFrame.new(region.CFrame.Position),
    }
end
```

---

### Phase 2: Visualization & Handles

#### 2.1 Selection Cube Visualization
- Create wireframe or semi-transparent cube part
- Update position/size/rotation based on selection
- Color: cyan/blue when active, orange when transforming

**Reference:** Existing brush visualization code (lines 164-410 in TerrainEditorModule.lua)

#### 2.2 Rotation Handles (ArcHandles)
- Create `ArcHandles` instance (similar to brush rotation handles)
- Attach to selection cube
- On drag: update `S.selectionCFrame` rotation
- Show preview of rotated terrain (optional, for performance)

**Reference:** Existing rotation handles (lines 418-445)

#### 2.3 Move Handles
- Create `Handles` instance with `Style = Enum.HandlesStyle.Movement`
- On drag: translate selection position
- Update `S.selectionCFrame` position

#### 2.4 Resize Handles (Optional)
- Additional `Handles` for resizing selection
- When resized, re-read voxel data from new region
- Or: just allow moving corners to adjust selection bounds

---

### Phase 3: Terrain Transformation

#### 3.1 Rotation Algorithm
```lua
local function applyRotation(region: Region3, rotation: CFrame)
    -- 1. Read voxels from original region
    -- 2. For each voxel:
    --    a. Calculate world position
    --    b. Apply inverse rotation to get position in original space
    --    c. Sample from original voxel data (interpolate if needed)
    --    d. Write to new rotated position
    -- 3. Clear original region
    -- 4. Write transformed voxels
end
```

**Challenge:** Voxel rotation requires interpolation or nearest-neighbor sampling. For smooth results, we may need to:
- Use bilinear/trilinear interpolation for occupancy values
- Handle material boundaries carefully
- Consider performance for large selections

**Simpler approach:** Use `Region3:ExpandToGrid()` and sample nearest voxel (faster, slightly blocky)

#### 3.2 Translation Algorithm
```lua
local function applyTranslation(region: Region3, offset: Vector3)
    -- 1. Read voxels from original region
    -- 2. Clear original region (set to air)
    -- 3. Write voxels to new position (region + offset)
end
```

**Note:** Must ensure new region doesn't overlap with original during operation.

#### 3.3 Combined Transform
- Apply rotation first, then translation
- Or: use CFrame math to combine transforms
- Clear original region after transformation

---

### Phase 4: Copy/Paste

#### 4.1 Copy Operation
```lua
local function copySelection()
    if S.selectionData then
        S.clipboardData = {
            materials = deepCopy(S.selectionData.materials),
            occupancies = deepCopy(S.selectionData.occupancies),
            size = S.selectionSize,
            originalCFrame = S.selectionCFrame,
        }
    end
end
```

#### 4.2 Paste Operation
```lua
local function pasteSelection(targetPosition: Vector3)
    if S.clipboardData then
        -- 1. Calculate target region from clipboard size
        -- 2. Write clipboard voxels to target region
        -- 3. Optionally: select the pasted region
    end
end
```

**UI:** Copy/Paste buttons in tool panel, or keyboard shortcuts (Ctrl+C, Ctrl+V)

---

### Phase 5: Polish & Edge Cases

#### 5.1 Handle Cleanup
- Destroy handles when switching tools
- Clear selection visualization
- Clean up connections

#### 5.2 Undo/Redo
- Use `ChangeHistoryService:SetWaypoint()` after transformations
- Store state for undo operations

#### 5.3 Performance
- For large selections, show progress indicator
- Consider chunking large operations
- Optimize voxel sampling for rotation

#### 5.4 Edge Cases
- Selection at terrain boundaries
- Empty selections (all air)
- Overlapping paste operations
- Rotation near 90/180/270 degrees (snap to grid?)

---

## File Changes

### New Files
```
Src/TerrainOperations/TransformOperations.lua
  - applyRotation()
  - applyTranslation()
  - applyTransform()
  - sampleVoxelData()  -- For rotation interpolation
```

### Modified Files

#### `TerrainEditorModule.lua`
- Add selection state variables to `S` table
- Add mouse handlers for selection drawing
- Add visualization functions for selection cube
- Add handle creation/update logic
- Add copy/paste handlers
- Wire up transform tool button

#### `Src/Util/TerrainEnums.lua`
- Add `ToolId.Transform = "Transform"` (or reuse existing Select/Move/Rotate)

#### `Src/Util/Constants.lua`
- Add `ToolActivatesPlugin[ToolId.Transform] = true`

---

## UI Design

### Tool Button
- Icon: Cube with rotation arrows, or transform icon
- Label: "Transform" or "Select & Transform"

### Selection Visualization
- **Wireframe cube** with edges (use `SelectionBox` or custom parts)
- **Color:** Cyan (0, 200, 255) when selected, Orange when transforming
- **Transparency:** 0.7-0.8 for visibility

### Handles
- **Rotation:** ArcHandles (3 rings) - Orange color
- **Move:** Handles with arrows - Cyan color  
- **Resize:** Handles on corners/edges - Yellow color (optional)

### Controls Panel
- "Clear Selection" button
- "Copy" button (or Ctrl+C)
- "Paste" button (or Ctrl+V)
- Transform info display (position, rotation, size)

---

## Technical Considerations

### Voxel Rotation Interpolation

**Option A: Nearest Neighbor (Fast)**
```lua
-- Simple, but can cause aliasing
local sourceVoxel = findNearestVoxel(rotatedPosition)
```

**Option B: Trilinear Interpolation (Smooth)**
```lua
-- Interpolate occupancy and material from 8 surrounding voxels
-- More accurate but slower
```

**Recommendation:** Start with Option A, add Option B as quality setting.

### Performance Optimization

1. **Chunking:** For selections > 1000 voxels, process in chunks
2. **Preview Mode:** Show wireframe preview during drag, apply on release
3. **LOD:** For very large selections, use lower resolution during rotation

### Coordinate Systems

- **World Space:** Terrain voxel positions
- **Selection Space:** Local to selection (origin at center)
- **Transform:** Apply CFrame to convert between spaces

---

## Testing Checklist

- [ ] Draw selection cube works correctly
- [ ] Selection visualization updates smoothly
- [ ] Rotation handles appear and respond
- [ ] Move handles work correctly
- [ ] Rotation transforms terrain accurately
- [ ] Translation moves terrain without artifacts
- [ ] Copy stores selection data
- [ ] Paste places terrain correctly
- [ ] Undo/redo works
- [ ] Large selections perform acceptably
- [ ] Edge cases handled (boundaries, empty regions)
- [ ] Cleanup on tool switch
- [ ] Keyboard shortcuts work

---

## Future Enhancements

1. **Multi-select:** Select multiple regions
2. **Mirror/Flip:** Flip selection along axis
3. **Scale:** Non-uniform scaling
4. **Snap to Grid:** Align rotations to 15/30/45/90 degree increments
5. **Preview Mode:** Show transformation before applying
6. **Material Preservation:** Better handling of material boundaries during rotation
7. **History:** Undo stack for multiple operations

---

## Implementation Order

1. **Week 1:** Selection drawing + visualization
2. **Week 2:** Rotation handles + basic rotation
3. **Week 3:** Move handles + translation
4. **Week 4:** Copy/paste functionality
5. **Week 5:** Polish, edge cases, performance

---

## Notes

- This tool is similar to existing "Select", "Move", "Rotate" tools in TerrainEnums, but combines them into one unified workflow
- Consider whether to replace those tools or add this as a new "Transform" tool
- The rotation algorithm is the most complex part - start simple, iterate
- Performance will be critical for large selections - profile early and often

