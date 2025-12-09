# Luau Module Traits and Properties

When a module is imported via `require()`, it returns whatever the module script returns. This document explains the different patterns and their properties.

## Module Return Types

### 1. Table Module (Most Common)
**Pattern:** Module returns a table with functions/properties

```lua
-- Example: Src/Util/Constants.lua
local Constants = {}
Constants.INITIAL_BRUSH_SIZE = 6
Constants.VOXEL_RESOLUTION = 4
return Constants
```

**Properties when imported:**
- Type: `{ [string]: any }` (table)
- Access: `local Constants = require(module); Constants.INITIAL_BRUSH_SIZE`
- Traits:
  - Can have nested tables
  - Can have functions as values
  - Can be extended after creation
  - Shared state across all require() calls (singleton)

**Example usage:**
```lua
local Constants = require(Src.Util.Constants)
print(Constants.INITIAL_BRUSH_SIZE) -- 6
```

### 2. Function Module
**Pattern:** Module returns a function directly

```lua
-- Example: Src/Actions/Action.lua
return function(name, fn)
    return setmetatable({
        name = name,
    }, {
        __call = function(self, ...)
            return fn(...)
        end,
    })
end
```

**Properties when imported:**
- Type: `(args...) -> returnType`
- Access: `local Action = require(module); local myAction = Action("Name", fn)`
- Traits:
  - Can be called immediately
  - Can return values or other functions
  - Often used for factories/constructors

**Example usage:**
```lua
local Action = require(Src.Actions.Action)
local ChangeTool = Action("ChangeTool", function(toolId)
    return { toolId = toolId }
end)
```

### 3. Object Module (Table with Methods)
**Pattern:** Module returns a table with methods and state

```lua
-- Example: TerrainEditorModule.lua
local TerrainEditorModule = {}

function TerrainEditorModule.init(pluginInstance, parentGui)
    -- initialization code
    return cleanupFunction
end

return TerrainEditorModule
```

**Properties when imported:**
- Type: `{ [string]: (args...) -> any }`
- Access: `local Module = require(module); Module.init(...)`
- Traits:
  - Methods are functions stored in table
  - Can have both methods and data
  - Supports object-oriented patterns

**Example usage:**
```lua
local TerrainEditorModule = require(script.TerrainEditorModule)
local cleanup = TerrainEditorModule.init(plugin, gui)
```

### 4. Mixed Return Module
**Pattern:** Module returns a table that can also be called (metatable)

```lua
-- Example: Src/Actions/Action.lua (returns callable table)
return function(name, fn)
    return setmetatable({
        name = name,  -- property
    }, {
        __call = function(self, ...)  -- callable
            return fn(...)
        end,
    })
end
```

**Properties when imported:**
- Type: `{ name: string } & ((args...) -> any)`
- Access: Can use both `Action.name` and `Action(...)`
- Traits:
  - Has properties (table access)
  - Can be called (function call)
  - Uses metatable `__call` metamethod

**Example usage:**
```lua
local Action = require(Src.Actions.Action)
local MyAction = Action("MyAction", function(value)
    return { value = value }
end)
print(MyAction.name)  -- "MyAction" (property)
local action = MyAction(42)  -- callable
```

## Module Caching Behavior

### Singleton Pattern
**Important:** `require()` caches the result. The module script runs **once**, and subsequent `require()` calls return the same cached value.

```lua
-- First require() - module executes
local Constants1 = require(Src.Util.Constants)

-- Second require() - returns cached value (module doesn't re-execute)
local Constants2 = require(Src.Util.Constants)

-- Constants1 and Constants2 are the SAME table
print(Constants1 == Constants2)  -- true
```

**Implications:**
- Module state is shared across all require() calls
- Changes to module data affect all consumers
- Useful for configuration/singleton patterns
- Can cause issues if module has mutable state

## Module Properties in Strict Mode

With `--!strict`, you can type the return value:

```lua
--!strict

export type Constants = {
    INITIAL_BRUSH_SIZE: number,
    VOXEL_RESOLUTION: number,
    MIN_BRUSH_SIZE: number,
    MAX_BRUSH_SIZE: number,
}

local Constants: Constants = {
    INITIAL_BRUSH_SIZE = 6,
    VOXEL_RESOLUTION = 4,
    MIN_BRUSH_SIZE = 1,
    MAX_BRUSH_SIZE = 64,
}

return Constants
```

**When imported:**
```lua
local Constants: Constants = require(Src.Util.Constants)
-- Type checker knows all properties
```

## Common Module Patterns in This Codebase

### 1. Constants Module
```lua
-- Returns: { [string]: any }
local Constants = require(Src.Util.Constants)
```

### 2. Enum Module
```lua
-- Returns: { ToolId: { [string]: string }, BrushShape: { [string]: string } }
local TerrainEnums = require(Src.Util.TerrainEnums)
local ToolId = TerrainEnums.ToolId
```

### 3. Data Module
```lua
-- Returns: { ShapeSupportsRotation: { [BrushShape]: boolean }, ... }
local BrushData = require(Src.Util.BrushData)
```

### 4. Function Module
```lua
-- Returns: (name: string, fn: function) -> callable table
local Action = require(Src.Actions.Action)
```

### 5. Operation Module
```lua
-- Returns: (terrain: Terrain, opSet: OperationSet) -> ()
local performTerrainBrushOperation = require(Src.TerrainOperations.performTerrainBrushOperation)
```

## Module Instance Properties

When you `require()` a ModuleScript, you get:
- **No Instance properties** - The return value is NOT an Instance
- **Pure Lua value** - Table, function, number, string, etc.
- **Cached** - Same value returned on subsequent requires
- **Type-safe** - With `--!strict`, types are checked

## Type Annotations for Modules

You can type the return value:

```lua
--!strict

export type ModuleType = {
    init: (plugin: Plugin, gui: GuiObject) -> (() -> ())?,
    version: string?,
}

local Module: ModuleType = {
    init = function(plugin, gui)
        return function() end
    end,
}

return Module
```

## Best Practices

1. **Use `--!strict`** - Enables type checking
2. **Export types** - Use `export type` for complex return types
3. **Document return value** - Comment what the module returns
4. **Consistent patterns** - Use same pattern across similar modules
5. **Avoid mutable state** - Prefer immutable data or explicit state management

## Example: Complete Module with Types

```lua
--!strict

export type ToolRegistry = {
    getAllTools: () -> { ToolDefinition },
    getTool: (toolId: string) -> ToolDefinition?,
    getToolConfigPanels: (toolId: string) -> { string },
}

export type ToolDefinition = {
    id: string,
    name: string,
    row: number,
    col: number,
    configPanels: { string },
    description: string?,
}

local ToolRegistry: ToolRegistry = {
    getAllTools = function()
        return {}
    end,
    getTool = function(toolId)
        return nil
    end,
    getToolConfigPanels = function(toolId)
        return {}
    end,
}

return ToolRegistry
```

**When imported:**
```lua
local ToolRegistry: ToolRegistry = require(Src.Util.ToolRegistry)
-- Full type checking and autocomplete available
```


