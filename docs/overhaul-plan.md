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
| SculptOps cleanup: noise + helpers | DONE | `f8b3bdf` |
| File splitting: ShapeIcon + AnalysisPanels | DONE | `1c330fc` |
| Core ops: metatable passthrough + effectiveOccupancy | DONE | `d05ac18` |
| Lint fixes: 3 errors + shadowing + table.clone | DONE | `703f6ce` |
| Theme centralization + tool trait fixes | DONE | `1ba40e1` |
| Phase G: Architecture | NOT STARTED | Needs discussion |

---

## System Audit Summary

| Layer | Files | Lines | State |
|-------|-------|-------|-------|
| Main module | TerrainEditorModule.lua | 2,625 | Monolithic; S table with ~150 properties |
| Terrain operations | 6 files in TerrainOperations/ | ~3,600 | Solid math core; helpers extracted |
| Tool definitions | 28 tools across 6 categories | ~4,200 | Functional; consistent requires |
| UI panels | 7 panel files + ConfigPanels orchestrator | ~3,300 | Modular; analysis panels split out |
| Utilities | 11 files in Util/ | ~2,800 | Good utilities; ShapeIcon extracted |
| Total | ~57 source files | ~16,500 | Working product, improved from ~17,000 |

---

## Issues Found

### Critical Bugs (crash or incorrect behavior)

| # | Issue | Location | Impact |
|---|-------|----------|--------|
| B1 | Bridge zero-distance crash on `.Unit` of zero vector | BridgePanel.lua | **FIXED** |
| B2 | Bridge preview/build segment mismatch (2x density difference) | BridgePanel.lua | **FIXED** |
| B3 | Bridge preview skips endpoints that build includes | BridgePanel.lua | **FIXED** |
| B4 | Bridge `perpDirZ` computes duplicate of RightVector | BridgePanel.lua | **FIXED** |
| B5 | `CFrame.new()` identity comparison may be fragile | performTerrainBrushOperation.lua:83 | Low; works in practice |
| B6 | Smooth: `occupancy * 1.5 - 0.25` lies to the algorithm | SculptOperations.lua | **DOCUMENTED** - intentional range expansion |
| B7 | Ring innerRadius hardcoded to `outerRadius * 0.6` | OperationHelper.lua | **TODO added** - needs UI slider |
| B8 | ZigZag hardcoded `brushOccupancy = 0.8` | OperationHelper.lua | **FIXED** - proper edge falloff |
| B9 | Sheet hardcoded arc angle `0.6 * pi` | OperationHelper.lua | **TODO added** - needs UI slider |
| B10 | Hollow mode uses ellipsoid distance for box shapes | OperationHelper.lua | Already handled (uses max() for box shapes) |

### Code Duplication

| # | What | Status |
|---|------|--------|
| D1 | Bridge preview/build path generation | **FIXED** - `BridgePathGenerator.generatePath()` |
| D2 | Surface detection (6-neighbor check) in noise, terrace, cliff | **FIXED** - `isSurfaceVoxel()` helper |
| D3 | Water handling (`ignoreWater` checks) across 8+ functions | **FIXED** - `effectiveOccupancy()` in OperationHelper |
| D4 | Material transition logic | Deferred (low priority, ~30 lines across 10 functions) |
| D5 | Slider creation (CorePanels vs UIHelpers) | **CANCELLED** - genuinely different layouts |
| D6 | `getTerrainHit` / `getTerrainHitRaw` duplication | **FIXED** - merged with `skipPlaneLock` param |
| D7 | Noise functions in SculptOperations vs Noise.lua | **FIXED** - delegated to `Noise.lua` |
| D8 | sculptSettings manual field copying (~60 fields) | **FIXED** - metatable passthrough from opSet |

### Inconsistencies

| # | Issue | Status |
|---|-------|--------|
| I1 | 10 tools use non-canonical require paths | **FIXED** |
| I2 | Analysis tools use non-standard docs format | **FIXED** |
| I3 | ToolSelector.lua uses hardcoded colors | **FIXED** |
| I4 | Shape icons use hardcoded colors | **FIXED** |
| I5 | Lock button uses emoji | **FIXED** - text labels |
| I6 | Inconsistent help descriptions | Deferred |
| I7 | GrowthSimTool `needsMaterial=false` but uses material panel | **FIXED** - set to true |
| I8 | SymmetryTool `usesStrength=false` but has strength panel | **FIXED** - set to true |
| I9 | Hardcoded colors in AnalysisPanels, ToolDocsPanel, UIHelpers | **FIXED** - moved to Theme |
| I10 | Missing `ignoreWater` in terrace/cliff functions | **FIXED** - added parameter extraction |

### Dead Code

| # | What | Status |
|---|------|--------|
| X1 | `getBridgeOffsetTerrainAware()` | **REMOVED** |
| X2 | `OctreeFillOptimization.lua` | Present (experimental) |
| X3 | `bridgeEditMode` / `bridgeSelectedConnection` | **REMOVED** |
| X4 | `BridgePathGenerator.isNearTerrain()` | **REMOVED** |
| X5 | `HandleRotation` color | **REMOVED** |
| X6 | Old Build/Sculpt/Paint tabs | **REMOVED** |

### Performance

| # | Issue | Status |
|---|-------|--------|
| P1 | Double ReadVoxels per operation | Present (needs careful testing) |
| P2 | All voxels in bounds processed | Present (standard approach) |
| P3 | Bridge preview Instance churn | **FIXED** - object pooling |
| P4 | smartLargeSculptBrush only for 3 tools | Deferred |
| P5 | Smooth: 27 neighbor samples per voxel | Present (inherent to algorithm) |
| P6 | Bridge terrain awareness raycasts | Deferred |
| P7 | sculptSettings allocation pressure | **FIXED** - metatable reduces field count |
| P8 | Bridge build synchronous freeze | **FIXED** - yield every 50 segments |

### Deprecated APIs

| # | API | Status |
|---|-----|--------|
| A1 | `RaycastFilterType.Whitelist` | **FIXED** - replaced with `Include` |

---

## Remaining Work

### Phase G: Architecture (needs discussion)

Structural improvements to the monolithic main module (2,625 lines):

1. **State organization**: Group S table into logical namespaces (brush, tool, ui, analysis)
2. **Brush visualization extraction**: Extract `updateBrushVisualization()` (~300 lines) into module
3. **Input handler module**: Extract keyboard/scroll/mouse logic
4. **Tool-specific click handlers**: Extract Bridge/Gradient/Clone click logic
5. **Magic numbers**: Move thresholds to Constants.lua

Risk: High. These changes deeply affect the main module and require Studio testing.

### Future Improvements

- Make Ring inner radius configurable via UI slider (B7)
- Make Sheet arc angle configurable (B9)
- Evaluate smartLargeSculptBrush for more tools (P4)
- Material transition helper (D4)
- ConfigPanels auto-ordering from tool declarations
- Single ReadVoxels optimization (P1, needs careful testing)
- Bridge terrain awareness raycast budget (P6)

---

## New Files Created

| File | Purpose | Extracted from |
|------|---------|----------------|
| `Src/Util/ShapeIcon.lua` | GUI-based brush shape icons | UIComponents.lua |
| `Src/UI/Panels/AnalysisPanels.lua` | VoxelInspect, ComponentAnalyzer, OccupancyOverlay | AdvancedPanels.lua |

## Key Architectural Changes

| Change | Impact |
|--------|--------|
| `BridgePathGenerator.generatePath()` | Single path generation for preview and build |
| `OperationHelper.effectiveOccupancy()` | Canonical water-aware occupancy check |
| `isSurfaceVoxel()` in SculptOperations | Shared surface detection for Noise/Terrace/Cliff |
| `sculptSettings` metatable passthrough | New tool parameters pass through automatically |
| ShapeIcon extraction | UIComponents.lua reduced by 330 lines |
| AnalysisPanels extraction | AdvancedPanels.lua reduced by 574 lines |
| Noise.lua consolidation | SculptOperations uses canonical Noise module |
