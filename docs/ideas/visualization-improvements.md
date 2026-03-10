# Brush Visualization Improvements

Ideas noted while reviewing the codebase.

## Torus Mesh Visualization

**Current:** 12 discrete spheres arranged in a ring.

**Problem:** The preview doesn't match the actual torus equation used in terrain operations. The SDF in `OperationHelper` computes true torus math, but the visualization is an approximation.

**Proposed:** Replace with true mesh visualization using `EditableMesh` or `MeshPart`. Generate vertices from the torus parametric equation:
```
x = (R + r*cos(v)) * cos(u)
y = r * sin(v)
z = (R + r*cos(v)) * sin(u)
```

**Benefits:**
- Preview matches actual terrain result
- Cleaner appearance
- Same approach could apply to other shapes

## Dome Mesh

`DomeMeshGenerator.lua` already exists for dome visualization. Consider extending this pattern to all non-primitive shapes.

## Shape Wireframe Mode

Some shapes (Grid, ZigZag, Spikepad) have complex internal structures that are hard to preview with solid visualization. Consider:
- Wireframe mode option
- Semi-transparent mode with visible edges
- Cross-section views for hollow shapes

## Rotation Handle Colors

Currently using RGB axis colors (X=red, Y=green, Z=blue). This matches Roblox Studio conventions. Keep this pattern for any new handle types.

