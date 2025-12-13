# Tool Classification System

This document defines how terrain tools are classified and what traits they possess.

---

## Tool Categories (by primary function)

### 1. Shape Tools
Modify terrain occupancy (volume/geometry). Change what's solid vs air.

| Tool | Behavior |
|------|----------|
| **Add** | Fill brush area with material |
| **Subtract** | Remove terrain from brush area |
| **Grow** | Expand from existing surfaces outward |
| **Erode** | Shrink existing surfaces inward |
| **Smooth** | Average neighbor occupancies |
| **Flatten** | Level terrain to a plane |

### 2. Surface Tools  
Reshape terrain surface without bulk add/remove.

| Tool | Behavior |
|------|----------|
| **Noise** | Add procedural roughness to surface |
| **Terrace** | Create stepped horizontal layers |
| **Cliff** | Force vertical faces |
| **Path** | Carve directional channels |
| **Blobify** | Create organic bulging shapes |

### 3. Material Tools
Change material without changing geometry.

| Tool | Behavior |
|------|----------|
| **Paint** | Apply material to existing terrain |
| **SlopePaint** | Auto-paint based on surface angle |
| **Megarandomize** | Clustered random materials |
| **GradientPaint** | Smooth transition between two materials |
| **FloodPaint** | Fill area with material |
| **CavityFill** | Paint into depressions |

### 4. Generator Tools
Create complex procedural shapes.

| Tool | Behavior |
|------|----------|
| **Stalactite** | Hanging/protruding spikes |
| **Tendril** | Branching vine structures |
| **GrowthSim** | Organic terrain expansion |
| **VariationGrid** | Grid pattern with height variation |

### 5. Utility Tools
Special-purpose operations.

| Tool | Behavior |
|------|----------|
| **Clone** | Copy terrain from one place to another |
| **Bridge** | Connect two points with terrain |
| **Symmetry** | Mirror/radial copy within brush |
| **Melt** | Gravity-based flow simulation |

### 6. Analysis Tools
Read-only inspection (no terrain modification).

| Tool | Behavior |
|------|----------|
| **VoxelInspect** | Examine individual voxel data |
| **ComponentAnalyzer** | Find disconnected terrain islands |
| **OccupancyOverlay** | Visualize occupancy values |

---

## Tool Traits

Each tool has specific traits that affect how it executes:

### Execution Traits

| Trait | Values | Description |
|-------|--------|-------------|
| `executionType` | `perVoxel`, `columnBased`, `pointToPoint`, `uiOnly` | How the tool processes terrain |
| `modifiesOccupancy` | boolean | Changes terrain volume |
| `modifiesMaterial` | boolean | Changes terrain material |
| `hasFastPath` | boolean | Can use native Terrain API shortcuts |
| `hasLargeBrushPath` | boolean | Has optimized path for large brushes |

### State Traits

| Trait | Values | Description |
|-------|--------|-------------|
| `requiresGlobalState` | boolean | Needs persistent state (buffer, points) |
| `globalStateKeys` | string[] | Which state keys it uses |

### UI Traits

| Trait | Values | Description |
|-------|--------|-------------|
| `usesBrush` | boolean | Shows brush visualization |
| `usesStrength` | boolean | Strength slider affects operation |
| `needsMaterial` | boolean | Requires material selection |

---

## Tool Matrix

| Tool | Category | executionType | modOcc | modMat | fastPath | largeBrush | globalState |
|------|----------|---------------|--------|--------|----------|------------|-------------|
| Add | Shape | perVoxel | ✓ | ✓ | ✓ | - | - |
| Subtract | Shape | perVoxel | ✓ | ✓ | ✓ | - | - |
| Grow | Shape | perVoxel | ✓ | ✓ | - | ✓ | - |
| Erode | Shape | perVoxel | ✓ | ✓ | - | ✓ | - |
| Smooth | Shape | perVoxel | ✓ | ✓ | - | ✓ | - |
| Flatten | Shape | columnBased | ✓ | ✓ | - | - | - |
| Noise | Surface | perVoxel | ✓ | - | - | - | - |
| Terrace | Surface | perVoxel | ✓ | - | - | - | - |
| Cliff | Surface | perVoxel | ✓ | - | - | - | - |
| Path | Surface | perVoxel | ✓ | - | - | - | - |
| Blobify | Surface | perVoxel | ✓ | - | - | - | - |
| Clone | Utility | perVoxel | ✓ | ✓ | - | - | ✓ (buffer) |
| Paint | Material | perVoxel | - | ✓ | - | - | - |
| SlopePaint | Material | perVoxel | - | ✓ | - | - | - |
| Megarandomize | Material | perVoxel | - | ✓ | - | - | - |
| GradientPaint | Material | perVoxel | - | ✓ | - | - | ✓ (points) |
| FloodPaint | Material | perVoxel | - | ✓ | - | - | - |
| CavityFill | Material | perVoxel | ✓ | ✓ | - | - | - |
| Melt | Utility | perVoxel | ✓ | - | - | - | - |
| Stalactite | Generator | perVoxel | ✓ | ✓ | - | - | - |
| Tendril | Generator | perVoxel | ✓ | ✓ | - | - | - |
| GrowthSim | Generator | perVoxel | ✓ | ✓ | - | - | - |
| VariationGrid | Generator | perVoxel | ✓ | ✓ | - | - | - |
| Bridge | Utility | pointToPoint | ✓ | ✓ | - | - | ✓ (points) |
| Symmetry | Utility | perVoxel | ✓ | ✓ | - | - | - |
| VoxelInspect | Analysis | uiOnly | - | - | - | - | - |
| ComponentAnalyzer | Analysis | uiOnly | - | - | - | - | - |
| OccupancyOverlay | Analysis | uiOnly | - | - | - | - | - |

---

## Folder Structure (Fully Standardized)

```
Src/Tools/
├── Shape/           # Volume modification tools (6)
│   ├── AddTool.lua
│   ├── SubtractTool.lua
│   ├── GrowTool.lua
│   ├── ErodeTool.lua
│   ├── SmoothTool.lua
│   └── FlattenTool.lua
│
├── Surface/         # Surface reshaping tools (5)
│   ├── NoiseTool.lua
│   ├── TerraceTool.lua
│   ├── CliffTool.lua
│   ├── PathTool.lua
│   └── BlobifyTool.lua
│
├── Material/        # Material painting tools (6)
│   ├── PaintTool.lua
│   ├── SlopePaintTool.lua
│   ├── MegarandomizeTool.lua
│   ├── GradientPaintTool.lua
│   ├── FloodPaintTool.lua
│   └── CavityFillTool.lua
│
├── Generator/       # Procedural shape generators (4)
│   ├── StalactiteTool.lua
│   ├── TendrilTool.lua
│   ├── GrowthSimTool.lua
│   └── VariationGridTool.lua
│
├── Utility/         # Special operations (4)
│   ├── CloneTool.lua
│   ├── MeltTool.lua
│   ├── BridgeTool.lua
│   └── SymmetryTool.lua
│
├── Analysis/        # Read-only inspection tools (3)
│   ├── VoxelInspectTool.lua
│   ├── ComponentAnalyzerTool.lua
│   └── OccupancyOverlayTool.lua
│
├── ToolDocFormat.lua   # Type definitions
└── ToolRegistry.lua    # Tool discovery & queries
```

**Total: 28 tools across 6 categories**

Folder names now match trait categories exactly.

---

## Implementation Status ✓

- [x] **Traits defined in each tool file** - All 28 tools have traits
- [x] **ToolRegistry uses traits for routing** - Added trait query functions
- [x] **Analysis tools have tool files** - Created in Analysis/ folder
- [x] **ToolDocFormat has trait types** - Full type definitions and validation
- [x] **TerrainEnums has ToolCategory** - Official category constants

