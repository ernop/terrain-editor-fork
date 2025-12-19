--!strict
-- TerrainEditorFork Standalone Plugin
-- This is the distributable version - all code is bundled inside

local PLUGIN_NAME = "TerrainParkour's TerrainCreator"
local WIDGET_ID = "TerrainEditorFork"
local WIDGET_ENABLED_SETTING_KEY = "TerrainEditorFork.DockWidget.Enabled"

-- The module is bundled as a child of this script
local pluginModule = script:WaitForChild("TerrainEditorModule")

-- Create toolbar button
local toolbar = plugin:CreateToolbar("TerrainParkour")
local toggleButton = toolbar:CreateButton(
    "TerrainCreator",
    "Open TerrainParkour's TerrainCreator",
    "rbxassetid://7229442422" -- terrain icon
)

local function getSavedWidgetEnabled(): boolean?
	local ok, value = pcall(function()
		return plugin:GetSetting(WIDGET_ENABLED_SETTING_KEY)
	end)
	if not ok then
		return nil
	end
	if type(value) ~= "boolean" then
		return nil
	end
	return value
end

local function saveWidgetEnabled(enabled: boolean)
	pcall(function()
		plugin:SetSetting(WIDGET_ENABLED_SETTING_KEY, enabled)
	end)
end

-- Create the dock widget
local widgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Float,
    false,  -- enabled (default: do NOT pop open on Studio launch)
    false,  -- do not override previous state (allow Studio restore)
    520,    -- default width
    500,    -- default height
    500,    -- min width
    300     -- min height
)
local pluginGui = plugin:CreateDockWidgetPluginGui(WIDGET_ID, widgetInfo)
pluginGui.Title = PLUGIN_NAME

local savedEnabled = getSavedWidgetEnabled()
if savedEnabled ~= nil then
	pluginGui.Enabled = savedEnabled
end

-- Toggle button syncs with widget visibility
local function updateButtonState()
    toggleButton:SetActive(pluginGui.Enabled)
end

toggleButton.Click:Connect(function()
    pluginGui.Enabled = not pluginGui.Enabled
    updateButtonState()
end)

pluginGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	saveWidgetEnabled(pluginGui.Enabled)
	updateButtonState()
end)
updateButtonState()

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

