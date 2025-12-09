# Brush System Analysis & Expansion Options

## Current Architecture

### Brush Shapes Defined

From `TerrainEnums.lua`:

```lua
TerrainEnums.BrushShape = {
	Sphere = "Sphere",
	Cube = "Cube",
	Cylinder = "Cylinder",
}
```

### How Brush Shapes Are Used

The brush system operates in two distinct modes:

#### 1. Fast Path (Direct API Calls)

For simple Add/Subtract operations without auto-material, the code uses Roblox's native terrain fill methods directly:

```lua
if brushShape == BrushShape.Sphere then
    terrain:FillBall(centerPoint, radius, desiredMaterial)
elseif brushShape == BrushShape.Cube then
    terrain:FillBlock(CFrame.new(centerPoint), Vector3.new(size, height, size), desiredMaterial)
elseif brushShape == BrushShape.Cylinder then
    terrain:FillCylinder(CFrame.new(centerPoint), height, radius, desiredMaterial)
end
```

#### 2. Slow Path (Per-Voxel Processing)

For Grow, Erode, Smooth, Flatten, Paint, and Replace operations, the code:
1. Reads voxels from a region (`terrain:ReadVoxels`)
2. Iterates over each voxel
3. Calculates brush influence via `OperationHelper.calculateBrushPowerForCell()`
4. Applies the sculpt operation
5. Writes voxels back (`terrain:WriteVoxels`)

### The Critical Function: `calculateBrushPowerForCell`

This function determines how much influence the brush has on each voxel:

```lua
function OperationHelper.calculateBrushPowerForCell(cellVectorX, cellVectorY, cellVectorZ,
	selectionSize, brushShape, radiusOfRegion, scaleMagnitudePercent)
	local brushOccupancy = 1
	local magnitudePercent = 1

	if selectionSize > 2 then
		if brushShape == BrushShape.Sphere then
			local distance = math.sqrt(cellVectorX * cellVectorX
				+ cellVectorY * cellVectorY
				+ cellVectorZ * cellVectorZ)
			magnitudePercent = math.cos(math.min(1, distance / radiusOfRegion) * math.pi * 0.5)
			brushOccupancy = math.max(0, math.min(1, (radiusOfRegion - distance) / Constants.VOXEL_RESOLUTION))
		elseif brushShape == BrushShape.Cylinder then
			local distance = math.sqrt(cellVectorX * cellVectorX
				+ cellVectorZ * cellVectorZ)
			magnitudePercent = math.cos(math.min(1, distance / radiusOfRegion) * math.pi * 0.5)
			brushOccupancy = math.max(0, math.min(1, (radiusOfRegion - distance) / Constants.VOXEL_RESOLUTION))
		end
	end
	-- ... magnitude scaling ...
end
```

**Key observations:**
- **Sphere:** Uses 3D Euclidean distance (X, Y, Z)
- **Cylinder:** Uses 2D distance (X, Z only), ignoring Y — infinite vertical extent
- **Cube:** Returns `brushOccupancy = 1` for everything inside the bounds (no gradual falloff)

---

## Roblox Terrain API Capabilities

Based on the codebase, Roblox's Terrain object provides these fill methods:

| Method | Parameters | Description |
|--------|------------|-------------|
| `FillBall` | centerPoint, radius, material | Sphere fill |
| `FillBlock` | cframe, size, material | Box fill |
| `FillCylinder` | cframe, height, radius, material | Cylinder fill |
| `FillWedge` | cframe, size, material | Wedge fill (exists per `TerrainEnums.Shape`) |
| `ReadVoxels` / `WriteVoxels` | region, resolution | Direct voxel access |

---

## Potential New Brush Shapes

### Tier 1: Easy to Add (Native API Support)

#### **1. Wedge**
Roblox has `FillWedge` natively. A wedge brush would be excellent for:
- Creating ramps and slopes
- Diagonal cuts into terrain
- Road construction on hills

**Implementation complexity:** Low  
**Fast path:** Yes (`terrain:FillWedge`)  
**Visualization:** Use `Enum.PartType.Wedge`

#### **2. Corner Wedge**  
A corner wedge (quarter ramp) could be useful for:
- Natural cliff transitions
- Corner ramps

**Implementation complexity:** Medium (may need `FillRegion` with custom voxel data)  
**Fast path:** Possible with direct voxel writing

---

### Tier 2: Medium Complexity (Custom Per-Voxel Math)

#### **3. Cone / Tapered Cylinder**
A cylinder that tapers from full radius at top to zero at bottom (or vice versa).

**Use cases:**
- Mountain peaks
- Pillars that narrow
- Stalactites/stalagmites

**Implementation:**
```lua
-- In calculateBrushPowerForCell
elseif brushShape == BrushShape.Cone then
    -- Taper factor: 0 at bottom, 1 at top
    local taperFactor = (cellVectorY + (height/2)) / height
    local effectiveRadius = radiusOfRegion * taperFactor
    local distance = math.sqrt(cellVectorX^2 + cellVectorZ^2)
    brushOccupancy = math.max(0, math.min(1, (effectiveRadius - distance) / Constants.VOXEL_RESOLUTION))
end
```

**Fast path:** No (voxel-by-voxel)  
**Visualization:** Could use a custom mesh or scaled cone part

#### **4. Capsule (Rounded Cylinder)**
A cylinder with hemispherical caps — like a pill shape.

**Use cases:**
- Organic terrain features
- Smooth tunnels
- Natural pillars

**Implementation:** Combine sphere distance check for caps with cylinder distance for middle.

**Fast path:** No  

#### **5. Half-Sphere / Dome**
A sphere cut in half horizontally.

**Use cases:**
- Hills with flat bases
- Domes
- Craters (inverted)

**Implementation:**
```lua
elseif brushShape == BrushShape.Dome then
    if cellVectorY >= 0 then
        local distance = math.sqrt(cellVectorX^2 + cellVectorY^2 + cellVectorZ^2)
        brushOccupancy = math.max(0, math.min(1, (radiusOfRegion - distance) / Constants.VOXEL_RESOLUTION))
    else
        brushOccupancy = 0
    end
end
```

**Fast path:** No

#### **6. Ellipsoid (Stretched Sphere)**
A sphere with independent X, Y, Z radii.

**Use cases:**
- Elongated hills
- Stretched valleys
- More natural terrain blobs

**Implementation:** Scale the distance calculation by axis ratios.

**Fast path:** No  
**UI complexity:** Would need separate X/Y/Z size controls

---

### Tier 3: Advanced (Significant Work)

#### **7. Torus (Ring/Donut)**
**Use cases:**
- Volcanic craters
- Ring fortifications
- Decorative features

**Implementation:** The distance formula for a torus is more complex:
```lua
local R = majorRadius  -- distance from center to tube center
local r = minorRadius  -- tube radius
local horizontalDist = math.sqrt(cellVectorX^2 + cellVectorZ^2)
local distance = math.sqrt((horizontalDist - R)^2 + cellVectorY^2)
brushOccupancy = math.max(0, math.min(1, (r - distance) / Constants.VOXEL_RESOLUTION))
```

**Fast path:** No  
**UI complexity:** Needs two radius parameters (major + minor)

#### **8. Custom/Noise-Based Brush**
A brush whose shape is modified by Perlin noise for organic edges.

**Use cases:**
- Natural rock formations
- Realistic terrain blending
- Erosion-like edges

**Implementation:** Apply noise offset to the distance calculation.

**Fast path:** No  
**Complexity:** High — but could create very natural-looking results

#### **9. Stamp Brush (Image-Based Heightmap)**
Load a grayscale image and use it as a height/influence map.

**Use cases:**
- Importing custom terrain patterns
- Repeatable natural features
- Artist-created brush profiles

**Implementation:** Read image data, map to occupancy values per XZ position.

**Complexity:** Very high — requires image loading support

---

## Implementation Checklist for Any New Brush

To add a new brush shape, you'd need to modify:

| File | What to Change |
|------|----------------|
| `Src/Util/TerrainEnums.lua` | Add to `BrushShape` enum |
| `Src/TerrainOperations/OperationHelper.lua` | Add distance calculation in `calculateBrushPowerForCell` |
| `Src/TerrainOperations/performTerrainBrushOperation.lua` | Add fast-path if native API exists |
| `TerrainEditorModule.lua` | Add to shapes array, update visualization |
| UI | Add button for new shape |

---

## Limitations

1. **Voxel Resolution:** Terrain voxels are 4×4×4 studs. Fine details smaller than this will be lost. Sharp edges become blocky.

2. **Performance:** Complex shapes without fast-path API support must process every voxel in the bounding box. A size-64 sphere processes up to 64³ = 262,144 voxels.

3. **Visualization Mismatch:** The brush preview uses Roblox Part shapes (`Ball`, `Block`, `Cylinder`, `Wedge`). Custom shapes like Cone or Torus would need:
   - A custom mesh (`MeshPart`)
   - Or a wireframe made of multiple parts
   - Or accept that preview doesn't match exactly

4. **No Rotation:** Current brush shapes are axis-aligned. Adding rotation would require:
   - Rotating the distance calculation
   - Updating visualization with CFrame rotation
   - More UI controls

5. **Height Independence:** The cube currently uses `height` parameter, but sphere doesn't (it's always uniform). Cylinder uses height for Y extent. New shapes would need to decide how to handle height.

---

## Recommendations

### Quick Wins
1. **Wedge** — Minimal work, native API support, immediate value for ramps/slopes
2. **Dome/Half-Sphere** — Simple math modification, useful for hills

### Medium-Term
3. **Cone** — Moderate math, good for mountains and decorative pillars
4. **Capsule** — Organic shapes, smooth edges

### Long-Term (If Warranted)
5. **Torus** — More complex but unique functionality
6. **Ellipsoid** — Requires UI work for 3 axis sizes

