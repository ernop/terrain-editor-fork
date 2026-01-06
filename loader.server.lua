--!strict
-- TerrainEditorFork Loader
-- This tiny plugin loads the actual code from ServerStorage (synced by Rojo)
-- Install this ONCE, then use Rojo live sync for development

local ServerStorage = game:GetService("ServerStorage")

local PLUGIN_NAME = "TerrainEditorFork"
local RETRY_INTERVAL = 1
local WIDGET_ID = "TerrainEditorForkDev"
local WIDGET_ENABLED_SETTING_KEY = "TerrainEditorForkDev.DockWidget.Enabled"

-- Wait for the synced code to appear
local function waitForModule()
	while not ServerStorage:FindFirstChild(PLUGIN_NAME) do
		task.wait(RETRY_INTERVAL)
	end
	return ServerStorage:FindFirstChild(PLUGIN_NAME)
end

-- Toolbar button to reload
local toolbar = plugin:CreateToolbar("Terrain Editor (Fork) - DEV")
local toggleButton = toolbar:CreateButton("Open", "Open/close the terrain editor", "rbxassetid://7229442422")
local reloadButton = toolbar:CreateButton("Reload", "Reload the terrain editor", "rbxassetid://1507949215")

local currentGui: DockWidgetPluginGui? = nil
local currentCleanup: (() -> ())? = nil

local loadCount = 0

local function deepClone(original: Instance): Instance
	local clone = original:Clone()
	return clone
end

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

local function ensureGui()
	if currentGui then
		return
	end

	-- Default: do NOT pop open on Studio launch.
	-- Also: do not override Studio's saved docking state.
	local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 260, 500, 260, 300)
	currentGui = plugin:CreateDockWidgetPluginGui(WIDGET_ID, widgetInfo)
	currentGui.Title = "TerrainParkour's TerrainCreator - DEV"

	local savedEnabled = getSavedWidgetEnabled()
	if savedEnabled ~= nil then
		currentGui.Enabled = savedEnabled
	end

	currentGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if currentGui then
			toggleButton:SetActive(currentGui.Enabled)
			saveWidgetEnabled(currentGui.Enabled)
		end
	end)

	toggleButton:SetActive(currentGui.Enabled)
end

local function loadPlugin()
	ensureGui()

	-- Clean up previous instance
	if currentCleanup then
		pcall(currentCleanup)
		currentCleanup = nil
	end
	if currentGui then
		-- Important: keep the same DockWidgetPluginGui instance so Studio can remember
		-- docked position/size, and so visibility isn't forcibly reset on each reload.
		for _, child in currentGui:GetChildren() do
			child:Destroy()
		end
	end

	local pluginModule = waitForModule()
	loadCount = loadCount + 1

	-- Clone the module to bypass require cache
	-- Each clone is a new ModuleScript that hasn't been required yet
	local moduleClone = deepClone(pluginModule)
	moduleClone.Name = PLUGIN_NAME .. "_Clone" .. loadCount
	moduleClone.Parent = ServerStorage

	-- Try to load and run the cloned module
	local success, err = xpcall(function()
		local MainModule = require(moduleClone)
		if type(MainModule) == "function" then
			currentCleanup = MainModule(plugin, currentGui)
		elseif type(MainModule) == "table" and MainModule.init then
			currentCleanup = MainModule.init(plugin, currentGui)
		end
	end, debug.traceback)

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

toggleButton.Click:Connect(function()
	ensureGui()
	if currentGui then
		currentGui.Enabled = not currentGui.Enabled
		toggleButton:SetActive(currentGui.Enabled)
	end
end)

reloadButton.Click:Connect(function()
	print("[TerrainEditorFork] Reloading...")
	loadPlugin()
end)

-- Initial load
task.defer(loadPlugin)

print("[TerrainEditorFork Loader] Ready - Click 'Reload' button to hot-reload changes")
