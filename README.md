# Terrain Editor Fork

A modifiable version of Roblox Studio's terrain tools. The original is compiled and locked away—this one you can open up, tinker with, and make your own.

---

## Sculpting Tools

| Tool | What it does |
|------|--------------|
| **Add** | Build terrain up |
| **Subtract** | Carve terrain away |
| **Grow** | Gently raise surfaces |
| **Erode** | Gently wear surfaces down |
| **Smooth** | Soften rough edges |
| **Flatten** | Level terrain to a plane (Erode only, Grow only, or Both) |
| **Noise** | Add procedural roughness with adjustable scale, intensity, and seed |
| **Paint** | Change material without changing shape |

---

## Bridge Tool

Click once to set a start point, click again for an end point. A terrain bridge connects them.

**Bridge Styles:**
- **Arc** — smooth curve upward
- **Sinusoidal** — gentle wave
- **Blippy** — short bumps
- **SquareWave** — stepped pattern
- **Rollercoaster** — dramatic hills
- **TwistySwingly** — curves side to side

Adjustable width. Preview shows the path before you commit.

---

## Brush Shapes

### Standard Shapes

| Shape | Sizing | Rotation |
|-------|--------|----------|
| **Sphere** | Uniform | — |
| **Cube** | X, Y, Z independent | ✓ |
| **Cylinder** | Radius + Height | ✓ |
| **Wedge** | X, Y, Z independent | ✓ |
| **Corner Wedge** | X, Y, Z independent | ✓ |
| **Dome** | Radius + Height | — |

### Creative Shapes

| Shape | What it looks like |
|-------|-------------------|
| **Torus** | Donut ring |
| **Ring** | Flat washer |
| **ZigZag** | Z-shaped profile |
| **Sheet** | Curved surface, like bent paper |
| **Grid** | 3D checkerboard pattern |
| **Stick** | Long thin rod |
| **Spikepad** | Flat base with pointed spikes on top |

Each has its own character. Wedges make clean ramps. Cylinders punch tunnels. Torus carves craters.

---

## Brush Modifiers

### Hollow Mode

Turn any shape into a shell. Adjustable wall thickness (10%–50% of radius).

Good for caves, domes, tunnels, hollow mountains.

### Spin Mode

The brush rotates continuously while you paint. Creates organic, twisted forms.

### Pivot Position

Where the brush anchors to your cursor:
- **Bottom** — brush sits on top of terrain
- **Center** — brush centered on cursor
- **Top** — brush hangs below cursor

---

## Plane Lock

Constrain your brush to a horizontal plane.

| Mode | Behavior |
|------|----------|
| **Off** | Normal—brush follows terrain surface |
| **Auto** | Locks to the height where you first click, releases when you let go |
| **Manual** | Set a specific height, or click "Set from Cursor" |

The locked plane shows as a green disc. Useful for cutting flat surfaces or building at consistent heights.

---

## Controls

### Keyboard

| Key | Action |
|-----|--------|
| **R** | Lock/unlock brush in place |
| **Shift + Scroll** | Adjust brush size |
| **Ctrl + Scroll** | Adjust brush strength |

### When Brush is Locked

- Brush turns **orange** and stays put
- **Drag orange rings** to rotate
- **Drag cyan arrows** to resize per-axis
- Press **R** again to unlock (returns to blue, follows mouse)

---

## Options

- **Ignore Water** — brush operations pass through water
- **Auto Material** — automatically picks material based on surroundings

---

## Materials

22 terrain materials with visual tile previews:

Grass, Sand, Rock, Ground, Snow, Ice, Glacier, Water, Mud, Slate, Concrete, Brick, Cobblestone, Asphalt, Pavement, Basalt, Cracked Lava, Salt, Sandstone, Limestone, Leafy Grass, Wood Planks

---

## Getting Started

### First Time

Build the loader plugin once:

```powershell
rojo build loader.project.json -o "YOUR_PLUGINS_FOLDER/TerrainEditorLoader.rbxm"
```

### Every Time

```powershell
rojo serve
```

Then in Studio: Connect via Rojo, and click **Reload** after making changes.

---

## Where Things Live

```
Src/
├── TerrainOperations/     ← The algorithms
│   ├── performTerrainBrushOperation.lua
│   ├── SculptOperations.lua
│   └── OperationHelper.lua
├── Util/
│   ├── TerrainEnums.lua   ← Tool IDs, brush shapes
│   ├── BrushData.lua      ← Shape configs, tool configs
│   └── Constants.lua      ← Voxel size, defaults
└── Components/            ← UI
```

The heart of terrain editing is in `TerrainOperations/`. That's where occupancy values become hills and valleys.

---

## Planned

- **Terrace** — stepped layers
- **Cliff** — force vertical faces
- **Path** — carve directional channels
- **Clone** — copy terrain from one spot to another

See `docs/` for implementation notes.

---

## Source

Extracted from [Roblox-Client-Tracker](https://github.com/MaximumADHD/Roblox-Client-Tracker), commit `581236f` (May 2022). This is Roblox's code, made readable for learning and modifying.
