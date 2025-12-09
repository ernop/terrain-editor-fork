# New Terrain Tools Implementation Plan

## Overview

This document outlines the implementation plan for 5 new terrain tools:

1. **Noise** - Add procedural displacement
2. **Terrace** - Create stepped layers
3. **Cliff** - Force vertical faces
4. **Path** - Carve directional channels
5. **Clone** - Copy terrain from one location to another

Each tool requires changes across multiple files following the existing architecture.

---

## Architecture Summary

```
TerrainEnums.lua        → Tool IDs and enums
TerrainEditorModule.lua → UI, state, brush visualization  
performTerrainBrushOperation.lua → Main operation dispatcher
SculptOperations.lua    → Per-voxel algorithms (grow, erode, smooth)
OperationHelper.lua     → Brush shape calculations, utility functions
```

**Data Flow:**
1. User clicks tool button → `selectTool(toolId)` updates `currentTool`
2. Mouse events → call `performTerrainBrushOperation()` with `opSet` parameters
3. Operation reads voxels → applies per-voxel algorithm → writes voxels

---

## Tool 1: Noise (Roughen)

### Purpose
Adds procedural displacement to terrain surfaces. Opposite of Smooth.

### Algorithm
```
For each voxel in brush:
  1. Generate noise value at (worldX, worldY, worldZ) using coherent noise
  2. Scale noise by strength and brush falloff
  3. Add/subtract from occupancy based on noise sign
  4. Only affect voxels near surfaces (0 < occupancy < 1 or neighbors differ)
```

### Files to Modify

#### 1. `Src/Util/TerrainEnums.lua`
```lua
ToolId = {
    ...
    Noise = "Noise",  -- ADD
    ...
}
```

#### 2. `TerrainEditorModule.lua`

**New State Variables:**
```lua
local noiseScale: number = 4         -- How "chunky" the noise is (1-20)
local noiseIntensity: number = 0.5   -- How strong the displacement (0-1)
local noiseSeed: number = 0          -- Random seed for reproducibility
```

**ToolConfigs:**
```lua
[ToolId.Noise] = {
    "brushShape",
    "handleHint", 
    "strength",
    "noiseScale",
    "noiseIntensity", 
    "noiseSeed",
    "pivot",
    "spin",
    "hollow",
    "planeLock",
    "ignoreWater",
},
```

**UI:** Add config panel with:
- Noise Scale slider (1-20, default 4)
- Noise Intensity slider (0.1-1.0, default 0.5)
- Seed text input or randomize button

**Tool Button:** Add to sculpt section between Smooth and Flatten

#### 3. `Src/TerrainOperations/SculptOperations.lua`

**Add new function:**
```lua
local function noise(options)
    local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
    local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
    local voxelX, voxelY, voxelZ = options.x, options.y, options.z
    local worldX, worldY, worldZ = options.worldX, options.worldY, options.worldZ
    local brushOccupancy = options.brushOccupancy
    local magnitudePercent = options.magnitudePercent
    local cellOccupancy = options.cellOccupancy
    local strength = options.strength
    local noiseScale = options.noiseScale or 4
    local noiseIntensity = options.noiseIntensity or 0.5
    local seed = options.noiseSeed or 0
    
    if brushOccupancy < 0.5 then return end
    
    -- Only affect surface voxels (near boundaries)
    local isSurface = cellOccupancy > 0.1 and cellOccupancy < 0.9
    -- Also check if any neighbor is air
    if not isSurface then
        for i = 1, 6 do
            local nx, ny, nz = voxelX + xOffset[i], voxelY + yOffset[i], voxelZ + zOffset[i]
            if nx > 0 and nx <= sizeX and ny > 0 and ny <= sizeY and nz > 0 and nz <= sizeZ then
                if readOccupancies[nx][ny][nz] < 0.5 then
                    isSurface = true
                    break
                end
            end
        end
    end
    
    if not isSurface then return end
    
    -- Generate 3D Perlin-like noise using sin/cos approximation
    -- (Roblox doesn't have built-in Perlin, so we use a hash-based approach)
    local noiseVal = perlin3D(worldX / noiseScale, worldY / noiseScale, worldZ / noiseScale, seed)
    
    -- Apply noise displacement
    local displacement = noiseVal * noiseIntensity * strength * brushOccupancy * magnitudePercent
    local newOccupancy = math.clamp(cellOccupancy + displacement, 0, 1)
    
    if newOccupancy ~= cellOccupancy then
        writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy
        -- Handle material transitions
        if newOccupancy <= OperationHelper.one256th then
            writeMaterials[voxelX][voxelY][voxelZ] = airFillerMaterial
        end
    end
end
```

**Perlin Noise Implementation** (add to OperationHelper or inline):
```lua
-- Simple 3D noise using hash function
local function hash3D(x, y, z, seed)
    local n = x * 374761393 + y * 668265263 + z * 1274126177 + seed
    n = bit32.bxor(n, bit32.rshift(n, 13))
    n = n * 1274126177
    return (bit32.bxor(n, bit32.rshift(n, 16)) % 1000000) / 1000000
end

local function perlin3D(x, y, z, seed)
    -- Simplified smooth noise with interpolation
    local x0, y0, z0 = math.floor(x), math.floor(y), math.floor(z)
    local fx, fy, fz = x - x0, y - y0, z - z0
    
    -- Smoothstep interpolation weights
    local sx = fx * fx * (3 - 2 * fx)
    local sy = fy * fy * (3 - 2 * fy)
    local sz = fz * fz * (3 - 2 * fz)
    
    -- Sample 8 corners
    local n000 = hash3D(x0, y0, z0, seed)
    local n100 = hash3D(x0+1, y0, z0, seed)
    local n010 = hash3D(x0, y0+1, z0, seed)
    local n110 = hash3D(x0+1, y0+1, z0, seed)
    local n001 = hash3D(x0, y0, z0+1, seed)
    local n101 = hash3D(x0+1, y0, z0+1, seed)
    local n011 = hash3D(x0, y0+1, z0+1, seed)
    local n111 = hash3D(x0+1, y0+1, z0+1, seed)
    
    -- Trilinear interpolation
    local nx00 = n000 + sx * (n100 - n000)
    local nx10 = n010 + sx * (n110 - n010)
    local nx01 = n001 + sx * (n101 - n001)
    local nx11 = n011 + sx * (n111 - n011)
    
    local nxy0 = nx00 + sy * (nx10 - nx00)
    local nxy1 = nx01 + sy * (nx11 - nx01)
    
    return (nxy0 + sz * (nxy1 - nxy0)) * 2 - 1  -- Return -1 to 1
end
```

#### 4. `Src/TerrainOperations/performTerrainBrushOperation.lua`

**Add in main loop:**
```lua
elseif tool == ToolId.Noise then
    sculptSettings.worldX = worldVectorX
    sculptSettings.worldY = worldVectorY
    sculptSettings.worldZ = worldVectorZ
    sculptSettings.noiseScale = opSet.noiseScale
    sculptSettings.noiseIntensity = opSet.noiseIntensity
    sculptSettings.noiseSeed = opSet.noiseSeed
    SculptOperations.noise(sculptSettings)
```

---

## Tool 2: Terrace

### Purpose
Creates horizontal stepped layers while preserving overall slope direction.

### Algorithm
```
For each voxel in brush:
  1. Calculate height relative to brush center or plane
  2. Quantize height to step intervals
  3. For voxels between steps:
     - If in "riser" zone (vertical face between steps): erode to create vertical
     - If in "tread" zone (horizontal surface): flatten to step height
  4. Transition sharpness controls blend between steps
```

### Files to Modify

#### 1. `Src/Util/TerrainEnums.lua`
```lua
ToolId = {
    ...
    Terrace = "Terrace",  -- ADD
    ...
}
```

#### 2. `TerrainEditorModule.lua`

**New State Variables:**
```lua
local stepHeight: number = 8         -- Height of each step in studs
local stepSharpness: number = 0.8    -- How sharp the step edges are (0-1)
```

**ToolConfigs:**
```lua
[ToolId.Terrace] = {
    "brushShape",
    "handleHint",
    "strength",
    "stepHeight",
    "stepSharpness",
    "pivot",
    "spin",
    "hollow",
    "planeLock",
    "ignoreWater",
},
```

**UI:**
- Step Height slider (4-32, default 8)
- Step Sharpness slider (0.1-1.0, default 0.8)

#### 3. `Src/TerrainOperations/SculptOperations.lua`

**Add new function:**
```lua
local function terrace(options)
    local readOccupancies = options.readOccupancies
    local writeOccupancies = options.writeOccupancies
    local voxelX, voxelY, voxelZ = options.x, options.y, options.z
    local worldY = options.worldY
    local brushOccupancy = options.brushOccupancy
    local cellOccupancy = options.cellOccupancy
    local strength = options.strength
    local stepHeight = options.stepHeight or 8
    local stepSharpness = options.stepSharpness or 0.8
    
    if brushOccupancy < 0.5 then return end
    if cellOccupancy <= 0 or cellOccupancy >= 1 then return end
    
    -- Find which step this Y coordinate belongs to
    local stepIndex = math.floor(worldY / stepHeight)
    local stepBase = stepIndex * stepHeight
    local heightInStep = worldY - stepBase
    local stepProgress = heightInStep / stepHeight  -- 0 at step base, 1 at top
    
    -- Determine target occupancy based on step position
    local riserZone = stepSharpness * 0.3  -- Portion of step that's vertical
    local targetOccupancy
    
    if stepProgress < riserZone then
        -- Riser (vertical portion) - should be solid below, air above
        targetOccupancy = 1 - (stepProgress / riserZone)
    else
        -- Tread (horizontal portion) - should be solid
        targetOccupancy = 1
    end
    
    -- Blend toward target based on strength
    local blendFactor = strength * brushOccupancy * 0.3
    local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor
    newOccupancy = math.clamp(newOccupancy, 0, 1)
    
    if math.abs(newOccupancy - cellOccupancy) > 0.01 then
        writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy
    end
end
```

---

## Tool 3: Cliff

### Purpose
Forces terrain toward vertical (or steep-angle) faces in the brush direction.

### Algorithm
```
For each voxel in brush:
  1. Determine the "cliff plane" based on brush direction (usually horizontal mouse movement)
  2. Calculate distance from cliff plane
  3. If behind plane: erode toward air
  4. If in front of plane: grow toward solid
  5. Creates sharp vertical transition at the plane
```

### Files to Modify

#### 1. `Src/Util/TerrainEnums.lua`
```lua
ToolId = {
    ...
    Cliff = "Cliff",  -- ADD
    ...
}
```

#### 2. `TerrainEditorModule.lua`

**New State Variables:**
```lua
local cliffAngle: number = 90        -- Target angle (90 = vertical, 60 = steep slope)
local cliffDirection: Vector3 = Vector3.new(1, 0, 0)  -- Computed from mouse movement
```

**ToolConfigs:**
```lua
[ToolId.Cliff] = {
    "brushShape",
    "handleHint",
    "strength",
    "cliffAngle",
    "pivot",
    "spin",
    "hollow",
    "planeLock",
    "ignoreWater",
},
```

**UI:**
- Cliff Angle slider (45-90, default 90) with label "Steepness"
- Note: Direction is determined automatically from mouse movement

**Mouse Movement Tracking:**
```lua
-- Track mouse direction to determine cliff face orientation
local lastMouseWorldPos: Vector3? = nil

-- In mouse move handler:
if isMouseDown and lastMouseWorldPos then
    local delta = mouseWorldPos - lastMouseWorldPos
    delta = Vector3.new(delta.X, 0, delta.Z)  -- Horizontal only
    if delta.Magnitude > 0.1 then
        cliffDirection = delta.Unit
    end
end
lastMouseWorldPos = mouseWorldPos
```

#### 3. `Src/TerrainOperations/SculptOperations.lua`

**Add new function:**
```lua
local function cliff(options)
    local readOccupancies = options.readOccupancies
    local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
    local voxelX, voxelY, voxelZ = options.x, options.y, options.z
    local cellVectorX, cellVectorZ = options.cellVectorX, options.cellVectorZ
    local brushOccupancy = options.brushOccupancy
    local cellOccupancy = options.cellOccupancy
    local strength = options.strength
    local cliffDirection = options.cliffDirection  -- Vector3 unit
    local cliffAngle = options.cliffAngle or 90
    
    if brushOccupancy < 0.5 then return end
    
    -- Calculate distance from cliff plane (plane passes through brush center)
    -- Plane normal is the cliff direction (horizontal)
    local distFromPlane = cellVectorX * cliffDirection.X + cellVectorZ * cliffDirection.Z
    
    -- Width of the transition zone
    local transitionWidth = Constants.VOXEL_RESOLUTION * 2
    
    local targetOccupancy
    if distFromPlane < -transitionWidth then
        -- Far behind the cliff - should be solid
        targetOccupancy = 1
    elseif distFromPlane > transitionWidth then
        -- Far in front of cliff - should be air
        targetOccupancy = 0
    else
        -- In transition zone - gradient
        targetOccupancy = 0.5 - (distFromPlane / (transitionWidth * 2))
    end
    
    -- Blend toward target
    local blendFactor = strength * brushOccupancy * 0.4
    local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor
    newOccupancy = math.clamp(newOccupancy, 0, 1)
    
    if newOccupancy ~= cellOccupancy then
        writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy
        if newOccupancy <= OperationHelper.one256th then
            writeMaterials[voxelX][voxelY][voxelZ] = options.airFillerMaterial
        end
    end
end
```

---

## Tool 4: Path (Trench/Channel)

### Purpose
Carves directional channels through terrain with configurable cross-section profile.

### Algorithm
```
For each voxel in brush:
  1. Project voxel onto path direction line
  2. Calculate perpendicular distance from path center
  3. Apply cross-section profile (V, U, or flat bottom)
  4. Determine target depth based on profile
  5. Erode terrain to match target depth
```

### Files to Modify

#### 1. `Src/Util/TerrainEnums.lua`
```lua
ToolId = {
    ...
    Path = "Path",  -- ADD
    ...
}

-- ADD new enum
TerrainEnums.PathProfile = {
    V = "V",           -- V-shaped valley
    U = "U",           -- U-shaped (flat bottom with walls)
    Flat = "Flat",     -- Flat bottom, sloped walls
}
```

#### 2. `TerrainEditorModule.lua`

**New State Variables:**
```lua
local pathDepth: number = 6          -- How deep the channel is
local pathProfile: string = "U"      -- V, U, or Flat
local pathDirection: Vector3 = Vector3.new(0, 0, 1)  -- Computed from mouse movement
```

**ToolConfigs:**
```lua
[ToolId.Path] = {
    "brushShape",
    "handleHint",
    "strength",
    "pathDepth",
    "pathProfile",
    "pivot",
    "spin",
    "planeLock",
    "ignoreWater",
},
```

**UI:**
- Path Depth slider (2-20, default 6)
- Path Profile selector (V / U / Flat buttons, default U)
- Note: Direction follows mouse drag

#### 3. `Src/TerrainOperations/SculptOperations.lua`

**Add new function:**
```lua
local function path(options)
    local readMaterials, readOccupancies = options.readMaterials, options.readOccupancies
    local writeMaterials, writeOccupancies = options.writeMaterials, options.writeOccupancies
    local voxelX, voxelY, voxelZ = options.x, options.y, options.z
    local cellVectorX, cellVectorY, cellVectorZ = options.cellVectorX, options.cellVectorY, options.cellVectorZ
    local worldY = options.worldY
    local brushOccupancy = options.brushOccupancy
    local cellOccupancy = options.cellOccupancy
    local strength = options.strength
    local pathDirection = options.pathDirection  -- Vector3 unit
    local pathDepth = options.pathDepth or 6
    local pathProfile = options.pathProfile or "U"
    local pathWidth = options.pathWidth or options.radiusX  -- Half-width from center
    
    if brushOccupancy < 0.5 then return end
    
    -- Calculate perpendicular distance from path centerline
    -- Path direction is horizontal, perpendicular is also horizontal
    local perpX = -pathDirection.Z
    local perpZ = pathDirection.X
    local perpDist = math.abs(cellVectorX * perpX + cellVectorZ * perpZ)
    local normalizedPerp = perpDist / pathWidth
    
    if normalizedPerp > 1 then return end  -- Outside the path width
    
    -- Calculate target depth based on profile
    local depthAtPosition
    if pathProfile == "V" then
        -- V-shape: deepest at center, rises linearly to edges
        depthAtPosition = pathDepth * (1 - normalizedPerp)
    elseif pathProfile == "U" then
        -- U-shape: flat bottom (80% width), then rises at edges
        local flatPortion = 0.6
        if normalizedPerp < flatPortion then
            depthAtPosition = pathDepth
        else
            local edgeProgress = (normalizedPerp - flatPortion) / (1 - flatPortion)
            depthAtPosition = pathDepth * (1 - edgeProgress)
        end
    else  -- Flat
        -- Flat: full depth with steep walls
        depthAtPosition = pathDepth
    end
    
    -- The path "floor" is at (brush center Y - depthAtPosition)
    local floorY = options.centerY - depthAtPosition
    local targetOccupancy = cellOccupancy
    
    if worldY > floorY then
        -- Above the floor - should be air (erode)
        local distAboveFloor = worldY - floorY
        if distAboveFloor < Constants.VOXEL_RESOLUTION then
            targetOccupancy = 1 - (distAboveFloor / Constants.VOXEL_RESOLUTION)
        else
            targetOccupancy = 0
        end
    end
    
    -- Only erode, never add
    if targetOccupancy < cellOccupancy then
        local blendFactor = strength * brushOccupancy * 0.5
        local newOccupancy = cellOccupancy + (targetOccupancy - cellOccupancy) * blendFactor
        newOccupancy = math.clamp(newOccupancy, 0, 1)
        
        if newOccupancy <= OperationHelper.one256th then
            writeOccupancies[voxelX][voxelY][voxelZ] = options.airFillerMaterial == materialWater and 1 or 0
            writeMaterials[voxelX][voxelY][voxelZ] = options.airFillerMaterial
        else
            writeOccupancies[voxelX][voxelY][voxelZ] = newOccupancy
        end
    end
end
```

---

## Tool 5: Clone (Stamp)

### Purpose
Samples terrain from a source area and stamps it to the target location.

### Algorithm
```
Phase 1 (Alt+Click or secondary action): Sample source
  1. Read voxels in brush region at source point
  2. Store materials and occupancies in sourceBuffer
  3. Store relative offsets from center

Phase 2 (Click): Stamp to target
  1. Calculate offset from source center to target center
  2. For each voxel in brush:
     - Look up corresponding source voxel from buffer
     - Apply blend mode (replace/add/blend)
     - Write to terrain
```

### Files to Modify

#### 1. `Src/Util/TerrainEnums.lua`
```lua
ToolId = {
    ...
    Clone = "Clone",  -- ADD
    ...
}

-- ADD new enum
TerrainEnums.CloneBlendMode = {
    Replace = "Replace",   -- Full replacement
    Add = "Add",           -- Only add where target is air
    Blend = "Blend",       -- Average source and target
}
```

#### 2. `TerrainEditorModule.lua`

**New State Variables:**
```lua
local cloneSource: Vector3? = nil               -- Center of sampled region
local cloneSourceBuffer: {
    materials: { { { Enum.Material } } },
    occupancies: { { { number } } },
    size: Vector3,
}? = nil
local cloneBlendMode: string = "Replace"
local cloneSourcePart: Part? = nil              -- Visual indicator of source
```

**ToolConfigs:**
```lua
[ToolId.Clone] = {
    "brushShape",
    "handleHint",
    "strength",
    "cloneInfo",        -- Shows source status
    "cloneBlendMode",
    "cloneSample",      -- Button to sample source
    "pivot",
    "spin",
    "ignoreWater",
},
```

**UI:**
- "Sample Source" button (or show instruction "Alt+Click to sample")
- Source indicator (shows "No source" or position of source)
- Blend Mode selector (Replace / Add / Blend)
- Visual: Semi-transparent box showing source location

**Input Handling:**
```lua
-- Alt+Click samples source
if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
    sampleCloneSource(brushPosition)
else
    applyCloneStamp(brushPosition)
end
```

**Sample Function:**
```lua
local function sampleCloneSource(centerPoint: Vector3)
    -- Calculate region bounds
    local radiusX = brushSizeX * Constants.VOXEL_RESOLUTION * 0.5
    local radiusY = brushSizeY * Constants.VOXEL_RESOLUTION * 0.5
    local radiusZ = brushSizeZ * Constants.VOXEL_RESOLUTION * 0.5
    
    local minBounds = Vector3.new(
        OperationHelper.clampDownToVoxel(centerPoint.X - radiusX),
        OperationHelper.clampDownToVoxel(centerPoint.Y - radiusY),
        OperationHelper.clampDownToVoxel(centerPoint.Z - radiusZ)
    )
    local maxBounds = Vector3.new(
        OperationHelper.clampUpToVoxel(centerPoint.X + radiusX),
        OperationHelper.clampUpToVoxel(centerPoint.Y + radiusY),
        OperationHelper.clampUpToVoxel(centerPoint.Z + radiusZ)
    )
    
    local region = Region3.new(minBounds, maxBounds)
    local materials, occupancies = terrain:ReadVoxels(region, Constants.VOXEL_RESOLUTION)
    
    cloneSource = centerPoint
    cloneSourceBuffer = {
        materials = materials,
        occupancies = occupancies,
        size = maxBounds - minBounds,
        minBounds = minBounds,
    }
    
    -- Update visual indicator
    updateCloneSourceVisual(centerPoint, maxBounds - minBounds)
end
```

#### 3. `Src/TerrainOperations/performTerrainBrushOperation.lua`

**Add special handling for Clone:**
```lua
if tool == ToolId.Clone then
    -- Clone operates differently - it uses the source buffer
    local sourceBuffer = opSet.cloneSourceBuffer
    if not sourceBuffer then return end
    
    local sourceCenter = opSet.cloneSourceCenter
    local targetCenter = centerPoint
    local offset = targetCenter - sourceCenter
    
    local blendMode = opSet.cloneBlendMode or "Replace"
    
    -- Read target region
    local writeMaterials, writeOccupancies = terrain:ReadVoxels(region, Constants.VOXEL_RESOLUTION)
    
    -- Apply source buffer to target with offset
    for voxelX, occupanciesX in ipairs(sourceBuffer.occupancies) do
        for voxelY, occupanciesY in ipairs(occupanciesX) do
            for voxelZ, sourceOcc in ipairs(occupanciesY) do
                local sourceMat = sourceBuffer.materials[voxelX][voxelY][voxelZ]
                
                -- Calculate world position of this source voxel
                local sourceWorldPos = sourceBuffer.minBounds + Vector3.new(
                    (voxelX - 0.5) * Constants.VOXEL_RESOLUTION,
                    (voxelY - 0.5) * Constants.VOXEL_RESOLUTION,
                    (voxelZ - 0.5) * Constants.VOXEL_RESOLUTION
                )
                
                -- Calculate corresponding target voxel
                local targetWorldPos = sourceWorldPos + offset
                local targetVoxelX = math.floor((targetWorldPos.X - minBounds.X) / Constants.VOXEL_RESOLUTION) + 1
                local targetVoxelY = math.floor((targetWorldPos.Y - minBounds.Y) / Constants.VOXEL_RESOLUTION) + 1
                local targetVoxelZ = math.floor((targetWorldPos.Z - minBounds.Z) / Constants.VOXEL_RESOLUTION) + 1
                
                -- Check bounds
                if targetVoxelX >= 1 and targetVoxelX <= #writeOccupancies
                    and targetVoxelY >= 1 and targetVoxelY <= #writeOccupancies[1]
                    and targetVoxelZ >= 1 and targetVoxelZ <= #writeOccupancies[1][1] then
                    
                    local targetOcc = writeOccupancies[targetVoxelX][targetVoxelY][targetVoxelZ]
                    
                    if blendMode == "Replace" then
                        writeOccupancies[targetVoxelX][targetVoxelY][targetVoxelZ] = sourceOcc
                        writeMaterials[targetVoxelX][targetVoxelY][targetVoxelZ] = sourceMat
                    elseif blendMode == "Add" then
                        if targetOcc < sourceOcc then
                            writeOccupancies[targetVoxelX][targetVoxelY][targetVoxelZ] = sourceOcc
                            writeMaterials[targetVoxelX][targetVoxelY][targetVoxelZ] = sourceMat
                        end
                    elseif blendMode == "Blend" then
                        local blendedOcc = (sourceOcc + targetOcc) / 2
                        writeOccupancies[targetVoxelX][targetVoxelY][targetVoxelZ] = blendedOcc
                        if blendedOcc > 0.5 then
                            writeMaterials[targetVoxelX][targetVoxelY][targetVoxelZ] = sourceMat
                        end
                    end
                end
            end
        end
    end
    
    terrain:WriteVoxels(region, Constants.VOXEL_RESOLUTION, writeMaterials, writeOccupancies)
    return
end
```

---

## Implementation Order

Recommended order based on complexity and dependencies:

### Phase 1: Foundation (Noise)
1. **Noise tool** - Good starting point because:
   - Requires implementing noise function (reusable)
   - Similar structure to existing Smooth tool
   - Tests the tool-adding pipeline

### Phase 2: Height-based (Terrace)
2. **Terrace tool** - Next because:
   - Height-based quantization is self-contained
   - No directional tracking needed
   - Moderate complexity

### Phase 3: Directional Tools (Cliff, Path)
3. **Cliff tool** - Introduces direction tracking
4. **Path tool** - Uses direction + cross-section profiles

### Phase 4: Multi-phase (Clone)
5. **Clone tool** - Most complex because:
   - Two-phase operation (sample + stamp)
   - Buffer management
   - Visual feedback for source

---

## Checklist Per Tool

For each tool, complete these steps:

- [ ] Add `ToolId` to `TerrainEnums.lua`
- [ ] Add any new enums (e.g., PathProfile, CloneBlendMode)
- [ ] Add state variables in `TerrainEditorModule.lua`
- [ ] Add `ToolConfigs` entry
- [ ] Create UI config panel with sliders/buttons
- [ ] Add tool button to UI
- [ ] Implement operation function in `SculptOperations.lua`
- [ ] Add case in `performTerrainBrushOperation.lua`
- [ ] Test with different brush shapes
- [ ] Test with rotation and hollow modifiers
- [ ] Verify undo/redo works (ChangeHistoryService)

---

## Estimated Effort

| Tool | Lines of Code | Complexity | Time Estimate |
|------|--------------|------------|---------------|
| Noise | ~150 | Medium | 2-3 hours |
| Terrace | ~100 | Low-Medium | 1-2 hours |
| Cliff | ~120 | Medium | 2 hours |
| Path | ~140 | Medium-High | 2-3 hours |
| Clone | ~200 | High | 3-4 hours |

**Total: 10-14 hours of implementation**

---

## Testing Notes

For each tool, test:
1. Small brush (2-4 studs)
2. Large brush (32+ studs)
3. All brush shapes (especially Sphere, Cube, Cylinder)
4. With rotation enabled
5. With hollow enabled
6. With Ignore Water on/off
7. Near terrain boundaries
8. On flat terrain
9. On already-sculpted terrain
10. Undo/Redo functionality

