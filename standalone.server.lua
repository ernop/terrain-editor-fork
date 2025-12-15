--!strict
-- TerrainEditorFork Standalone Plugin
-- This is the distributable version - all code is bundled inside

local PLUGIN_NAME = "Terrain Editor (Fork)"

-- The module is bundled as a child of this script
local pluginModule = script:WaitForChild("TerrainEditorModule")

-- Create the dock widget
local widgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Float,
    true,   -- enabled
    false,  -- override previous state
    520,    -- default width
    500,    -- default height
    500,    -- min width
    300     -- min height
)
local pluginGui = plugin:CreateDockWidgetPluginGui("TerrainEditorFork", widgetInfo)
pluginGui.Title = PLUGIN_NAME

-- Load and run the module
local success, err = pcall(function()
    local MainModule = require(pluginModule)
    if type(MainModule) == "function" then
        MainModule(plugin, pluginGui)
    elseif type(MainModule) == "table" and MainModule.init then
        MainModule.init(plugin, pluginGui)
    end
end)

if not success then
    -- Show error in the widget
    local errorLabel = Instance.new("TextLabel")
    errorLabel.Size = UDim2.fromScale(1, 1)
    errorLabel.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    errorLabel.TextWrapped = true
    errorLabel.TextSize = 14
    errorLabel.Font = Enum.Font.Code
    errorLabel.Text = "ERROR:\n\n" .. tostring(err)
    errorLabel.Parent = pluginGui
    warn("[TerrainEditorFork] Load error:", err)
else
    print("[TerrainEditorFork] Plugin loaded successfully!")
end

