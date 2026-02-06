# Terrain Editor Overhaul Plan

Full-scope improvement plan for the terrain editor plugin. Covers every layer: architecture, code quality, performance, reliability, product, and UI.

## Progress

| Phase | Status | Commits |
|-------|--------|---------|
| Phase A: Consistency sweep | DONE | `a9088e7` |
| Phase B: Duplication elimination | DONE | `1fcd851` |
| Phase C: Shape SDF fixes | DONE | `45f7a7e` |
| Phase D: Performance | DONE | `06d659f` |
| Phase E: Bridge overhaul | DONE | `be99ea1` |
| Phase F: UI/UX polish | DONE | `dd64e26` |
| Phase G: Architecture | NOT STARTED | Needs discussion |

---

## System Audit Summary

| Layer | Files | Lines | State |
|-------|-------|-------|-------|
| Main module | TerrainEditorModule.lua | 2,655 | Monolithic; S table with ~150 properties |
| Terrain operations | 6 files in TerrainOperations/ | 3,922 | Solid math core; duplication in helpers |
| Tool definitions | 28 tools across 6 categories | ~4,200 | Functional; 10 have inconsistent requires |
| UI panels | 6 panel files + ConfigPanels orchestrator | ~3,300 | Modular; some files oversized |
| Utilities | 10 files in Util/ | ~2,800 | Good utilities; some unused/duplicated |
| Total | ~55 source files | ~17,000 | Working product with polish gaps |

---

## Issues Found

### Critical Bugs (crash or incorrect behavior)

| # | Issue | Location | Impact |
|---|-------|----------|--------|
| B1 | Bridge zero-distance crash on `.Unit` of zero vector | BridgePanel.lua | **FIXED** (staged) |
| B2 | Bridge preview/build segment mismatch (2x density difference) | BridgePanel.lua | **FIXED** (staged) |
| B3 | Bridge preview skips endpoints that build includes | BridgePanel.lua | **FIXED** (staged) |
| B4 | Bridge `perpDirZ` computes duplicate of RightVector | BridgePanel.lua | **FIXED** (staged) |
| B5 | `CFrame.new()` identity comparison may be fragile | performTerrainBrushOperation.lua:83 | Low; works in practice |
| B6 | Smooth: `occupancy * 1.5 - 0.25` lies to the algorithm | SculptOperations.lua:299 | **DOCUMENTED** - intentional range expansion |
| B7 | Ring innerRadius hardcoded to `outerRadius * 0.6` | OperationHelper.lua:400 | **TODO added** - needs UI slider |
| B8 | ZigZag hardcoded `brushOccupancy = 0.8` | OperationHelper.lua:422 | **FIXED** - proper edge falloff |
| B9 | Sheet hardcoded arc angle `0.6 * pi` | OperationHelper.lua:466 | **TODO added** - needs UI slider |
| B10 | Hollow mode uses ellipsoid distance for box shapes | OperationHelper.lua:621 | Already handled (uses max() for box shapes) |

### Code Duplication

| # | What's duplicated | Where | Lines saved |
|---|-------------------|-------|-------------|
| D1 | Bridge preview and build path generation | BridgePanel.lua | **FIXED** - unified `BridgePathGenerator.generatePath()` |
| D2 | Surface detection (6-neighbor empty check) | SculptOperations.lua in noise, terrace, cliff | ~60 (future) |
| D3 | Water handling (`if ignoreWater and material == Water`) | SculptOperations.lua across 8+ functions | ~40 (future) |
| D4 | Material transition logic (air check, autoMaterial) | SculptOperations.lua across 10+ functions | ~30 (future) |
| D5 | Slider creation | CorePanels `createInlineSlider` vs UIHelpers `createSlider` | ~100 (future) |
| D6 | `getTerrainHit` and `getTerrainHitRaw` nearly identical | TerrainEditorModule.lua | **FIXED** - merged with `skipPlaneLock` param |
| D7 | Noise functions in SculptOperations vs Noise.lua | SculptOperations.lua top section | ~50 (future) |

### Inconsistencies

| # | Issue | Scope |
|---|-------|-------|
| I1 | 10 tools use `script.Parent.Parent.ToolDocFormat` instead of canonical `Src.Tools.ToolDocFormat` | TerraceTool, CliffTool, PathTool, PaintTool, SlopePaintTool, FloodPaintTool, CavityFillTool, CloneTool, SymmetryTool, MeltTool |
| I2 | Analysis tools use non-standard docs format (`purpose/usage/tips` vs `sections`) | VoxelInspectTool, ComponentAnalyzerTool, OccupancyOverlayTool |
| I3 | ToolSelector.lua uses hardcoded colors instead of Theme | ToolSelector.lua |
| I4 | Some shape icons use hardcoded colors instead of Theme | CorePanels.lua 347-354, UIComponents.lua 929, 960 |
| I5 | Lock button uses emoji, rest of UI is text-only | CorePanels.lua |
| I6 | Some tool panels have help descriptions, others don't | ToolPanels.lua, AdvancedPanels.lua |

### Dead Code

| # | What | Location |
|---|------|----------|
| X1 | `getBridgeOffsetTerrainAware()` never called | BrushData.lua:571-607 |
| X2 | `OctreeFillOptimization.lua` (experimental, unused) | TerrainOperations/ |
| X3 | `bridgeEditMode` and `bridgeSelectedConnection` state | TerrainEditorModule.lua:189-190 |
| X4 | `BridgePathGenerator.isNearTerrain()` unused | BridgePathGenerator.lua:57-64 |
| X5 | `HandleRotation` color marked legacy | Theme.lua:52 |
| X6 | TODO: remove old Build/Sculpt/Paint tabs | TerrainEnums.lua:78-80 |
| X7 | `_FalloffType` import (intentionally prefixed) | TerrainEditorModule.lua:40 |

### Performance

| # | Issue | Impact | Location |
|---|-------|--------|----------|
| P1 | Double ReadVoxels (read-only + writable copies) | 2x memory, 2x API calls per operation | performTerrainBrushOperation.lua:171-176 |
| P2 | Triple nested loop processes all voxels in bounds | Processes air voxels far from brush | performTerrainBrushOperation.lua:331-406 |
| P3 | Bridge preview creates/destroys Parts every mouse move | Hundreds of Instance.new/Destroy per frame | BridgePanel.lua:284-287 |
| P4 | smartLargeSculptBrush only used for 3 tools | Grow/Erode/Smooth benefit; others don't | performTerrainBrushOperation.lua:187 |
| P5 | Smooth: 27 neighbor samples per voxel | O(27n) where n = voxels in brush | SculptOperations.lua:243-332 |
| P6 | Bridge terrain awareness does grid raycasts | Up to 400 raycasts per point | BridgePathGenerator.lua:76-93 |
| P7 | sculptSettings table (~90 fields) allocated per operation | Allocation pressure | performTerrainBrushOperation.lua:231-325 |
| P8 | Bridge build is synchronous; freezes viewport for large bridges | UX freeze for 500+ segments | BridgePanel.lua:437-536 |

### Deprecated APIs

| # | API | Replacement | Location |
|---|-----|-------------|----------|
| A1 | `RaycastFilterType.Whitelist` | `RaycastFilterType.Include` | BridgePathGenerator.lua:47 |

---

## Overhaul Phases

### Phase A: Consistency Sweep (low risk, high signal)

Standardize everything that's inconsistent. No behavior changes.

1. **Fix require paths** in 10 tool files (I1)
2. **Standardize Analysis tool docs** to use `sections` format (I2)
3. **Replace hardcoded colors** with Theme references (I3, I4)
4. **Replace deprecated `Whitelist`** with `Include` (A1)
5. **Remove dead code**: unused state variables, unused functions, experimental file (X1-X7)
6. **Resolve TODO** about old tabs in TerrainEnums (X6)
7. **Add missing panel descriptions** where other tools have them (I6)

### Phase B: Duplication Elimination (medium risk)

Extract shared code into helpers. Behavior should be identical.

1. **Bridge path generation**: Extract `generateBridgePath(startPoint, endPoint, settings) -> {Vector3}`, used by both preview and build (D1)
2. **Surface detection helper**: `isSurfaceVoxel(readOccupancies, x, y, z, ignoreWater, readMaterials)` shared by noise, terrace, cliff, etc. (D2)
3. **Water-aware occupancy helper**: `getEffectiveOccupancy(occupancy, material, ignoreWater)` (D3)
4. **Material transition helper**: `resolveNewMaterial(cellMaterial, brushMaterial, autoMaterial, neighbors)` (D4)
5. **Consolidate slider creation**: Remove `createInlineSlider`, use `UIHelpers.createSlider` with compact mode (D5)
6. **Consolidate terrain raycast**: Merge `getTerrainHit` and `getTerrainHitRaw` with parameter (D6)
7. **Remove noise duplication**: SculptOperations should use `Noise.lua` exclusively (D7)

### Phase C: Shape SDF Fixes (medium risk)

Fix shapes that have hardcoded parameters.

1. **Ring**: Make inner radius ratio configurable via brush state (B7)
2. **ZigZag**: Add proper falloff and strength support (B8)
3. **Sheet**: Make arc angle configurable (B9)
4. **Hollow mode**: Use box distance for box shapes, ellipsoid for round shapes (B10)
5. **Smooth hack**: Either document the `1.5 - 0.25` trick properly or replace with honest math (B6)

### Phase D: Performance (medium-high risk)

Speed improvements for the brush loop and preview.

1. **Bridge preview pooling**: Reuse preview Parts instead of destroy/create cycle (P3)
2. **Bridge preview caching**: Implement the existing `bridgeLastPreviewParams` mechanism (P3)
3. **Bridge build yielding**: `task.wait()` every N segments for large bridges (P8)
4. **Raycast budget**: Cap terrain awareness raycasts, interpolate between samples (P6)
5. **Evaluate single ReadVoxels**: Test if one copy + careful read patterns can replace double-read (P1)
6. **Extend smart brush**: Evaluate smartLargeSculptBrush for Noise, Paint, and other tools (P4)

### Phase E: Bridge System Overhaul

Comprehensive bridge improvements (builds on Phase B extraction).

1. **Rebuild workflow**: Keep start/end after build, add "Rebuild" and "Clear" as separate actions
2. **Variant categories**: Group 17 variants into Classic/Mathematical/Fun sections in UI
3. **MegaMeander unification**: Bring into the same path generation pipeline as other variants
4. **Remove dead terrain awareness function** from BrushData.lua (use the inline version)
5. **Width variation along path**: Thicker at anchors, thinner mid-span (future)

### Phase F: UI/UX Polish

1. **File splitting**: Break UIComponents.lua (1174 lines) into focused modules
2. **File splitting**: Extract analysis tool panels from AdvancedPanels.lua (926 lines)
3. **Lock button**: Replace emoji with text or icon consistent with UI style
4. **ConfigPanels ordering**: Auto-generate panel order from tool declarations instead of hardcoded list
5. **Grid shape special case**: Generalize the shape-specific panel visibility
6. **Docs panel validation**: Validate docs structure matches expectations

### Phase G: Architecture (high risk, high reward)

Structural improvements to the monolithic main module.

1. **State organization**: Group S table into logical namespaces (brush, tool, ui, analysis)
2. **Brush visualization extraction**: Extract 500+ line `updateBrushVisualization()` into module
3. **Tool-specific click handlers**: Extract Bridge/Gradient/Clone click logic from mouse handler
4. **Input handler module**: Extract keyboard/scroll/mouse logic
5. **Magic numbers**: Move all thresholds to Constants.lua

---

## Priority Order

For maximum impact with minimum risk:

```
Phase A (consistency)     -- 1-2 hours, zero risk
Phase B (deduplication)   -- 2-3 hours, low risk
Phase C (shape fixes)     -- 1-2 hours, medium risk
Phase D (performance)     -- 2-3 hours, medium risk
Phase E (bridge overhaul) -- 2-3 hours, medium risk
Phase F (UI polish)       -- 2-3 hours, low risk
Phase G (architecture)    -- 4-6 hours, high risk, needs discussion
```

Total estimated effort: ~15-22 hours across all phases.

---

## Files Modified Per Phase

### Phase A
- 10 tool files (require paths)
- 3 analysis tool files (docs format)
- ToolSelector.lua, CorePanels.lua, UIComponents.lua (colors)
- BridgePathGenerator.lua (deprecated API)
- TerrainEditorModule.lua (dead state)
- BrushData.lua (dead function)
- TerrainEnums.lua (old tabs)
- OctreeFillOptimization.lua (remove or mark clearly)

### Phase B
- BridgePanel.lua (extract shared path gen)
- SculptOperations.lua (extract helpers)
- CorePanels.lua (consolidate slider)
- TerrainEditorModule.lua (consolidate raycast)
- New: Src/TerrainOperations/SculptHelpers.lua (shared helpers)

### Phase C
- OperationHelper.lua (Ring, ZigZag, Sheet, Hollow fixes)
- SculptOperations.lua (Smooth documentation)
- TerrainEditorModule.lua or BrushData.lua (new state for Ring/Sheet params)

### Phase D
- BridgePanel.lua (pooling, caching, yielding)
- BridgePathGenerator.lua (raycast budget)
- performTerrainBrushOperation.lua (single ReadVoxels, smart brush expansion)

### Phase E
- BridgePanel.lua (rebuild workflow, variant categories)
- BrushData.lua (cleanup, MegaMeander unification)
- BridgePathGenerator.lua (cleanup)

### Phase F
- UIComponents.lua (split)
- AdvancedPanels.lua (split)
- CorePanels.lua (lock button)
- ConfigPanels.lua (auto-ordering)

### Phase G
- TerrainEditorModule.lua (major restructuring)
- Potentially new modules extracted from it
