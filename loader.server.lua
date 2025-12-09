--!strict
-- TerrainEditorFork Loader
-- This tiny plugin loads the actual code from ServerStorage (synced by Rojo)
-- Install this ONCE, then use Rojo live sync for development

local ServerStorage = game:GetService("ServerStorage")

local PLUGIN_NAME = "TerrainEditorFork"
local RETRY_INTERVAL = 1

-- Wait for the synced code to appear
local function waitForModule()
	while not ServerStorage:FindFirstChild(PLUGIN_NAME) do
		task.wait(RETRY_INTERVAL)
	end
	return ServerStorage:FindFirstChild(PLUGIN_NAME)
end

-- Toolbar button to reload
local toolbar = plugin:CreateToolbar("Terrain Editor (Fork) - DEV")
local reloadButton = toolbar:CreateButton("Reload", "Reload the terrain editor", "rbxassetid://1507949215")

local currentGui: DockWidgetPluginGui? = nil
local currentCleanup: (() -> ())? = nil

local loadCount = 0

local function deepClone(original: Instance): Instance
	local clone = original:Clone()
	return clone
end

local function loadPlugin()
	-- Clean up previous instance
	if currentCleanup then
		pcall(currentCleanup)
		currentCleanup = nil
	end
	if currentGui then
		currentGui:Destroy()
		currentGui = nil
	end

	local pluginModule = waitForModule()
	loadCount = loadCount + 1

	-- Clone the module to bypass require cache
	-- Each clone is a new ModuleScript that hasn't been required yet
	local moduleClone = deepClone(pluginModule)
	moduleClone.Name = PLUGIN_NAME .. "_Clone" .. loadCount
	moduleClone.Parent = ServerStorage

	-- Create the dock widget
	local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 400, 500, 300, 300)
	currentGui = plugin:CreateDockWidgetPluginGui("TerrainEditorForkDev", widgetInfo)
	currentGui.Title = "Terrain Editor (Fork) - LIVE DEV"

	-- Try to load and run the cloned module
	local success, err = pcall(function()
		local MainModule = require(moduleClone)
		if type(MainModule) == "function" then
			currentCleanup = MainModule(plugin, currentGui)
		elseif type(MainModule) == "table" and MainModule.init then
			currentCleanup = MainModule.init(plugin, currentGui)
		end
	end)

	-- Clean up the clone after loading (it's cached in memory now)
	task.defer(function()
		moduleClone:Destroy()
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
		errorLabel.Parent = currentGui
		warn("[TerrainEditorFork] Load error:", err)
	else
		print("[TerrainEditorFork] Loaded successfully! (reload #" .. loadCount .. ")")
	end
end

reloadButton.Click:Connect(function()
	print("[TerrainEditorFork] Reloading...")
	loadPlugin()
end)

-- Initial load
task.defer(loadPlugin)

print("[TerrainEditorFork Loader] Ready - Click 'Reload' button to hot-reload changes")
