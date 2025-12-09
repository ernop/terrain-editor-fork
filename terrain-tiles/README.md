# Terrain Tile Assets

This folder contains terrain texture tiles for use in the terrain tracking widgets.

## Tile Naming Convention

Files must be named exactly as follows (lowercase, no spaces):

| File Name | Display Name | Roblox Enum |
|-----------|--------------|-------------|
| `asphalt.png` | Asphalt | `Enum.Material.Asphalt` |
| `basalt.png` | Basalt | `Enum.Material.Basalt` |
| `brick.png` | Brick | `Enum.Material.Brick` |
| `cobblestone.png` | Cobblestone | `Enum.Material.Cobblestone` |
| `concrete.png` | Concrete | `Enum.Material.Concrete` |
| `crackedlava.png` | Cracked Lava | `Enum.Material.CrackedLava` |
| `glacier.png` | Glacier | `Enum.Material.Glacier` |
| `grass.png` | Grass | `Enum.Material.Grass` |
| `ground.png` | Ground | `Enum.Material.Ground` |
| `ice.png` | Ice | `Enum.Material.Ice` |
| `leafygrass.png` | Leafy Grass | `Enum.Material.LeafyGrass` |
| `limestone.png` | Limestone | `Enum.Material.Limestone` |
| `mud.png` | Mud | `Enum.Material.Mud` |
| `pavement.png` | Pavement | `Enum.Material.Pavement` |
| `rock.png` | Rock | `Enum.Material.Rock` |
| `salt.png` | Salt | `Enum.Material.Salt` |
| `sand.png` | Sand | `Enum.Material.Sand` |
| `sandstone.png` | Sandstone | `Enum.Material.Sandstone` |
| `slate.png` | Slate | `Enum.Material.Slate` |
| `snow.png` | Snow | `Enum.Material.Snow` |
| `water.png` | Water | `Enum.Material.Water` |
| `woodplanks.png` | Wood Planks | `Enum.Material.WoodPlanks` |
| `air.png` | Air | `Enum.Material.Air` |

## Verification

Open `terrain-verification.html` in a browser to verify all images are present and correctly named.

## Uploading to Roblox

### Option 1: Asphalt CLI (Recommended)

[Asphalt](https://github.com/jackTabsCode/asphalt) is a modern command-line tool for uploading assets to Roblox.

#### Installation

Using Aftman (already configured in this project):
```bash
aftman add jackTabsCode/asphalt
```

Or using Cargo:
```bash
cargo install asphalt
```

#### Setup

1. Get an API key from [Creator Dashboard](https://create.roblox.com/dashboard/credentials)
   - Required permissions: `asset:read`, `asset:write`
   - Restrict to your IP address for security

2. Copy and configure:
   ```bash
   cp asphalt.example.toml asphalt.toml
   # Edit asphalt.toml with your user/group ID
   ```

3. Upload assets:
   ```bash
   # Set API key (or use --api-key argument)
   set ASPHALT_API_KEY=your-api-key-here
   
   # Sync assets to Roblox
   asphalt sync
   
   # Or dry-run to preview what will be uploaded
   asphalt sync --dry-run
   ```

4. After upload, Asphalt generates:
   - `asphalt.lock.toml` - Contains the uploaded asset IDs (commit this)
   - Generated Luau code with asset references

### Option 2: Manual Upload

Upload each image manually through the [Creator Dashboard](https://create.roblox.com/dashboard/creations) and record the asset IDs, then update `terrainData.lua` with the IDs.

## After Upload

Update `rojo/ReplicatedStorage/gui/activeRunWidgets/terrainData.lua`:

Replace `NO_TEXTURE` values with actual asset IDs:
```lua
grass = {
    name = "grass",
    displayName = "Grass",
    color = Color3.fromRGB(75, 151, 75),
    symbol = "🌿",
    textureId = "rbxassetid://123456789",  -- Replace with actual ID
},
```

## Reference

- [Roblox Terrain Documentation](https://create.roblox.com/docs/parts/terrain)
- [Asphalt GitHub](https://github.com/jackTabsCode/asphalt)
- [Roblox Open Cloud Assets API](https://create.roblox.com/docs/cloud/open-cloud/usage-assets)



