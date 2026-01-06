# Bridge Tool System

The Bridge tool connects two terrain points with a procedurally generated path. Unlike brush-based tools, Bridge operates in point-to-point mode with real-time preview.

---

## Quick Reference

| Control | Range | Purpose |
|---------|-------|---------|
| Width | 1-20 | Brush size at each path point |
| Intensity | 10-300% | How extreme the path variations are |
| Segments | 0-1000 | Path density (0 = auto) |
| Plane Lock | 0-100% | Constrain lateral drift |
| Axis Roll | 0-360° | Rotate bridge around its axis |

| Checkbox | Default | Purpose |
|----------|---------|---------|
| Use selected brush shape | OFF | Use current brush instead of spheres |
| Anchor start/end points | ON | Prevent endpoint drift with intensity |
| Terrain aware | OFF | Push path above existing terrain |

---

## User Workflow

1. Select **Bridge** tool from Utility category
2. **Click** terrain to set start point (green marker appears)
3. **Click** terrain again to set end point (orange marker appears)
4. Preview path appears automatically with blue spheres
5. Adjust settings - preview updates in real-time
6. **Click again** to build the bridge
7. Use **Clear Points** button to reset and start over

---

## Controls

### Width (1-20)

Size of terrain added at each path point. In voxels (multiply by 4 for studs).

### Intensity (10-300%)

Multiplier for how extreme the path variations are:
- **10%**: Subtle, gentle curves
- **100%**: Normal/default behavior
- **300%**: Dramatic, exaggerated shapes

### Segments (0-1000)

Number of points along the path:
- **0**: Auto-calculate based on distance (recommended for most cases)
- **Higher values**: Denser, smoother paths (useful for very long bridges or detailed work)

### Use Selected Brush Shape

When ON, uses your current brush shape (Cube, Cylinder, etc.) instead of spheres at each path point. Allows for interesting effects like square-tube bridges.

### Anchor Start/End Points

**Default: ON** (recommended)

Prevents the start and end positions from drifting when you change intensity. Without this, some variants (Exponential, Staircase, TrollBridge) would shift the endpoints.

Technical: Calculates offsets at t=0 and t=1, then subtracts a linear interpolation from the entire path.

### Terrain Aware

When ON, the path generator:
1. Raycasts down to find terrain height at each point
2. Pushes the path up to maintain 4 studs (1 voxel) clearance
3. Prevents bridges from clipping through existing terrain

### Plane Lock (0-100%)

Constrains lateral drift to the vertical plane between start and end:
- **0%**: Full 3D freedom - Corkscrew spirals freely, Fibonacci does full spirals
- **50%**: Half lateral movement
- **100%**: No lateral drift - path stays in vertical plane (only up/down)

### Axis Roll (0-360°)

Rotates the entire bridge around the axis formed by start→end line. "Rolls" the bridge like a log:

| Angle | Effect |
|-------|--------|
| 0° | Default - vertical offset goes up, horizontal goes sideways |
| 90° | Rotated - what was up is now sideways |
| 180° | Upside down - arcs become U-shapes |
| 270° | Opposite of 90° |

**Examples:**
- Arc at 90° → Horizontal arch (tunnel entrance from above)
- Catenary at 180° → Sag becomes a hump
- Corkscrew at 45° → Diagonal helix
- TrollBridge at 90° → Sideways loop-the-loop

---

## Bridge Variants (17 total)

### Classic Variants

| Variant | Description | Best For |
|---------|-------------|----------|
| **Arc** | Classic `sin(πt)` arch | Traditional bridges, arches |
| **Sinusoidal** | Gentle wave `sin(6πt)` | Rolling hills, gentle paths |
| **Blippy** | Short repeated bumps | Stepping stones, bumpy paths |
| **SquareWave** | Stepped alternating heights | Industrial, mechanical structures |
| **Rollercoaster** | Large amplitude waves with peaks | Dramatic terrain, thrill rides |
| **TwistySwingly** | Combined vertical + horizontal waves | Winding mountain paths |
| **MegaMeander** | Multiple random curves layered | Wild flying paths, organic chaos |

### Mathematical Variants

| Variant | Formula | Description |
|---------|---------|-------------|
| **Fibonacci** | φ^(5t) golden ratio | Ever-accelerating ascent with spiral motion |
| **Fractal** | 4-octave sine waves | Self-similar bumps at multiple scales |
| **Exponential** | e^(3t) | Starts flat, rockets skyward at end |
| **Logarithmic** | log(1+10t) | Quick rise at start, flattens toward end |
| **Corkscrew** | 3D helix | Full spiral wrapping around the path |
| **Catenary** | cosh(x) | True hanging chain curve (suspension bridge shape) |

### Fun & Trollish Variants

| Variant | Description | Best For |
|---------|-------------|----------|
| **Drunkard** | Pseudo-random chaotic wobble with stumbles | Rickety, unstable bridges |
| **Heartbeat** | ECG/EKG cardiac rhythm (P-QRS-T waves) | Medical themes, dramatic spikes |
| **Staircase** | Distinct steps with flat landings | Grand staircases, temple steps |
| **TrollBridge** | Normal arc with a **loop-the-loop** in the middle | Impossible architecture, jokes |

---

## Variant Details

### Fibonacci

Uses the golden ratio (φ ≈ 1.618) for ever-increasing height:
```
height = (φ^(5t) - 1) / (φ^5 - 1) × distance × 0.4
```
Also adds gentle spiral motion in the horizontal plane. Creates paths that feel "naturally impossible."

### Fractal

Self-similar waves at 4 different scales (octaves):
```
octave1 = sin(2πt) × 0.5
octave2 = sin(4πt) × 0.25
octave3 = sin(8πt) × 0.125
octave4 = sin(16πt) × 0.0625
```
Each octave is half the wavelength and half the amplitude. Creates organic, coastline-like complexity.

### Corkscrew

Full 3D helix wrapping around the path axis:
```
angle = t × 2π × turns
x = cos(angle) × radius
y = sin(angle) × radius
```
Radius swells in the middle and shrinks at ends for visual appeal. Number of turns scales with intensity.

### Catenary

The true mathematical shape of a hanging chain (hyperbolic cosine):
```
y = cosh(2x) normalized to touch y=0 at both ends
```
Creates authentic suspension bridge sag. At 180° axis roll, becomes a hump instead of a sag.

### Heartbeat

Accurate ECG waveform with distinct components:
- **P wave**: Small initial bump (atrial depolarization)
- **QRS complex**: Sharp spike with Q dip, tall R peak, S dip
- **T wave**: Rounded recovery bump

Each heartbeat takes 20% of the path, so a bridge shows ~5 heartbeats.

### TrollBridge

Looks like a normal arc... until the middle, where it does a full **360° loop-the-loop**:
```
if t in [0.35, 0.65]:
    angle = (t - 0.35) / 0.3 × 2π
    y = (1 - cos(angle)) × loopRadius  -- 0 at entry, 2r at top, 0 at exit
    x = sin(angle) × loopRadius × 0.5   -- Horizontal displacement
```
Perfectly ridiculous and impossible. Best experienced with Axis Roll = 0° (vertical loop) or 90° (horizontal loop).

---

## MegaMeander System

MegaMeander uses a separate curve system with multiple random curves combined:

```lua
type Curve = {
    type: "sin" | "cos" | "combined",
    amplitude: number,      -- 0.5 to 2.0
    frequency: number,      -- 2.0 to 8.0
    phase: number,          -- 0 to 2π
    offset: Vector3,
    verticalBias: number,
    horizontalBias: number,
}
```

### MegaMeander Controls

When MegaMeander is selected with both points set:
- **Re-randomize Layout**: Generate new random curves
- **Add Curve**: Add another curve layer
- **Meander Complexity** (1-50): Number of curves to generate

---

## Technical Implementation

### Offset Functions (BrushData.lua)

| Function | Purpose |
|----------|---------|
| `getBridgeOffset(t, distance, variant, intensity)` | Raw offset calculation |
| `getBridgeOffsetAnchored(...)` | Anchored version (start/end = 0) |
| `getBridgeOffsetTerrainAware(...)` | Terrain collision avoidance |
| `getBridgeOffsetPlaneAware(...)` | Plane constraint applied |

### Axis Rotation Math

```lua
-- Build coordinate frame aligned with path
local baseCFrame = CFrame.lookAt(Vector3.zero, pathDir)

-- Rotate around path axis
local rotatedCFrame = baseCFrame * CFrame.Angles(0, 0, axisRotation)

-- Extract rotated perpendicular directions
local perpDirX = rotatedCFrame.RightVector  -- For X offset
local perpDirY = rotatedCFrame.UpVector     -- For Y offset
local perpDirZ = ...                         -- For Z offset

-- Apply offset in rotated space
finalOffset = perpDirX * offset.X + perpDirY * offset.Y + perpDirZ * offset.Z
```

### Path Generation Flow

1. Calculate path direction and distance
2. Build rotated coordinate frame (if axis roll ≠ 0)
3. For each segment (t = 0 to 1):
   - Get base position via lerp
   - Calculate offset using selected variant
   - Apply anchoring correction
   - Apply plane constraint
   - Rotate offset by axis roll
   - Apply terrain awareness adjustment
   - Place preview marker or fill terrain

---

## State Keys

| Key | Type | Description |
|-----|------|-------------|
| `bridgeStartPoint` | Vector3? | First click position |
| `bridgeEndPoint` | Vector3? | Second click position |
| `bridgePreviewParts` | { BasePart } | Preview visualization parts |
| `bridgeWidth` | number | 1-20 voxels |
| `bridgeVariant` | string | One of 17 variants |
| `bridgeIntensity` | number | 0.1-3.0 multiplier |
| `bridgeSegments` | number | 0-1000 (0 = auto) |
| `bridgeUseBrushShape` | boolean | Use brush shape vs spheres |
| `bridgeAnchorEndpoints` | boolean | Anchor start/end positions |
| `bridgeTerrainAware` | boolean | Avoid terrain collisions |
| `bridgePlaneConstraint` | number | 0-1 lateral constraint |
| `bridgeAxisRotation` | number | 0-360 degrees |
| `bridgeCurves` | { Curve } | MegaMeander curves |
| `bridgeMeanderComplexity` | number | 1-50 curves |

---

## Files

| File | Purpose |
|------|---------|
| `Src/Tools/Utility/BridgeTool.lua` | Tool definition, traits, docs |
| `Src/UI/Panels/BridgePanel.lua` | UI panel, preview, build logic |
| `Src/Util/BrushData.lua` | Offset calculation functions |
| `Src/Util/BridgePathGenerator.lua` | MegaMeander curve system |
