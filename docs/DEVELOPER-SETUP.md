# Developer Setup

## Prerequisites

- [Aftman](https://github.com/LPGhatguy/aftman) for toolchain management
- [Roblox Studio](https://create.roblox.com/docs/studio/setting-up-roblox-studio)
- VS Code or Cursor IDE with [Luau LSP](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp) extension

## First Time Setup

Run the setup script:

```powershell
.\setup.ps1
```

Build the loader plugin (once):

```powershell
rojo build loader.project.json -o "$env:LOCALAPPDATA\Roblox\Plugins\TerrainEditorLoader.rbxm"
```

Restart Studio after building the loader.

---

## Two Deployment Workflows

### Live Development (daily workflow)

1. Run `rojo serve` in project folder
2. Open Studio, connect Rojo (localhost:34872)
3. Editor opens automatically via loader plugin
4. Edit code in Cursor/VS Code
5. Click **Reload** button in Studio toolbar after changes
6. Repeat 4-5

The loader syncs code to ServerStorage and hot-reloads when you click Reload.

### Production Build (end of work session)

1. Bump VERSION in `TerrainEditorModule.lua`
2. Build standalone:

```powershell
rojo build standalone.project.json -o "TerrainEditorFork.rbxm"
Copy-Item "TerrainEditorFork.rbxm" "$env:LOCALAPPDATA\Roblox\Plugins\" -Force
```

---

## Project Structure

```
TerrainEditorModule.lua     # Main entry point - EDIT THIS
Src/
├── Actions/                # Redux-style state actions
├── Components/             # Roact UI components
├── Reducers/               # State management
├── TerrainInterfaces/      # Terrain API wrappers
├── TerrainOperations/      # Core brush algorithms (THE GOOD STUFF)
├── Tools/                  # Tool implementations
└── Util/                   # Constants, enums, helpers
```

### Rojo Sync Structure

When connected via Rojo:

```
ServerStorage/
└── TerrainEditorFork (ModuleScript)  ← TerrainEditorModule.lua
    ├── Src/                          ← script.Src
    │   ├── Util/
    │   │   ├── TerrainEnums.lua
    │   │   └── Constants.lua
    │   └── TerrainOperations/
    │       └── performTerrainBrushOperation.lua
    └── Packages/
```

**Important:** In code, use `script.Src` not `script.Parent.Src`

---

## Troubleshooting

### "Src is not a valid member of ServerStorage"

Wrong: `script.Parent.Src`
Right: `script.Src`

### Changes not showing after Reload

1. Check Rojo is connected (green indicator)
2. Check Output for errors
3. Verify version number changed in title

### Port already in use

```powershell
Get-Process -Name "rojo" | Stop-Process -Force
rojo serve
```

### Rebuild loader plugin

```powershell
rojo build loader.project.json -o "$env:LOCALAPPDATA\Roblox\Plugins\TerrainEditorLoader.rbxm"
```

Restart Studio after rebuilding loader.

---

## Version Bumping

Current version is the `VERSION` constant at top of `TerrainEditorModule.lua`. Bump it after changes to confirm reload worked.

---

## Linting

```powershell
.\lint.ps1
```

Or directly:

```powershell
sg scan
```

See `docs/linting.md` for rule details.

---

## Hot-Reload Mechanism

The loader plugin (`loader.server.lua`) handles hot-reloading:

1. **Module cloning**: Each reload clones the module to bypass Lua's `require` cache
2. **Cleanup function**: `TerrainEditorModule.init()` returns a cleanup function that:
   - Disconnects all RBXScriptConnections
   - Destroys all created Parts (brush visualization, handles)
   - Destroys all UI elements
3. **GUI persistence**: The same DockWidgetPluginGui is reused so Studio remembers dock position

**Adding new connections or parts:**
```lua
-- Store connections for cleanup
local myConnection = someEvent:Connect(function() ... end)
table.insert(connections, myConnection)

-- Store parts for cleanup
local myPart = Instance.new("Part")
table.insert(createdParts, myPart)
```

---

## Common Development Patterns

### Adding a New Tool

1. Create `Src/Tools/{Category}/{Name}Tool.lua`
2. Export: `id`, `name`, `traits`, `docs`, `configPanels`, `execute`
3. Tool is auto-discovered by ToolRegistry on reload
4. See existing tools as templates

### Adding a New Config Panel

1. Create panel in appropriate `Src/UI/Panels/{Category}Panels.lua`
2. Add panel name to `panelOrder` in `ConfigPanels.lua`
3. Add panel name to tool's `configPanels` array

### Adding a New Brush Shape

1. Add enum to `TerrainEnums.BrushShape`
2. Add shape to `BrushData.Shapes` and `BrushData.ShapeDimensions`
3. Add SDF calculation in `OperationHelper.calculateBrushPowerForCellAxisAligned`
4. Add visualization in `createBrushVisualization()` in TerrainEditorModule

---

## Testing Changes

1. Build terrain in Studio using the tool
2. Verify undo/redo works (ChangeHistoryService waypoints)
3. Test with different brush sizes (small and large)
4. Test with hollow mode, rotation, and different falloff curves
5. Check Output window for errors

