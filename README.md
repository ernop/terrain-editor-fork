# Roblox Terrain Editor Fork

A custom fork of Roblox Studio's built-in Terrain Editor plugin, with readable source code that you can modify and extend.

## What is this?

Roblox Studio's built-in terrain tools are compiled and uneditable. This project extracts the original readable Lua source code (from May 2022, commit `581236f`) so you can:

- Customize brush behavior
- Add new terrain tools
- Modify the UI
- Learn how Roblox's terrain system works

## Quick Start

```powershell
cd D:\proj\roblox-terrain-editor
rojo serve
```

Then in Studio: Connect via the Rojo plugin, and click **Reload** after making code changes.

## Project Structure

```
roblox-terrain-editor/
├── TerrainEditorModule.lua     # Main plugin code (EDIT THIS)
├── loader.server.lua           # Loader plugin source
├── default.project.json        # Rojo live sync config
├── loader.project.json         # Loader build config
├── Packages/                   # Dependencies (Roact, Rodux, etc.)
└── Src/
    ├── Actions/                # Redux-style state actions
    ├── Components/             # Roact UI components
    ├── Reducers/               # State management
    ├── TerrainInterfaces/      # Terrain API wrappers
    ├── TerrainOperations/      # Core brush algorithms (THE GOOD STUFF)
    └── Util/                   # Constants, enums, helpers
```

## Key Files to Modify

| File | What it does |
|------|--------------|
| `TerrainEditorModule.lua` | Main plugin code |
| `Src/TerrainOperations/performTerrainBrushOperation.lua` | Main brush logic |
| `Src/TerrainOperations/SculptOperations.lua` | Add/subtract/grow/erode |
| `Src/TerrainOperations/smartLargeSculptBrush.lua` | Large brush optimization |
| `Src/Util/Constants.lua` | Voxel size, defaults |
| `Src/Util/TerrainEnums.lua` | Tool IDs, brush shapes |

## First-Time Setup

1. Build the loader plugin:
   ```powershell
   rojo build loader.project.json -o "D:\proj\studio\plugins\TerrainEditorLoader.rbxm"
   ```

2. Start Rojo and connect in Studio

See `.cursor/rules/` for detailed development guidelines.

## Source

Original source extracted from [Roblox-Client-Tracker](https://github.com/MaximumADHD/Roblox-Client-Tracker) commit `581236f` (May 24, 2022).

## License

This is Roblox's code extracted for educational/modification purposes. Use responsibly.
