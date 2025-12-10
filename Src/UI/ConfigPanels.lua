--!strict
-- ConfigPanels.lua - Orchestrates all panel modules and manages visibility
-- This is the single entry point for creating all configuration panels

local Theme = require(script.Parent.Parent.Util.Theme)
local BrushData = require(script.Parent.Parent.Util.BrushData)

-- Panel modules
local CorePanels = require(script.Parent.Panels.CorePanels)
local MaterialPanel = require(script.Parent.Panels.MaterialPanel)
local ToolPanels = require(script.Parent.Panels.ToolPanels)
local AdvancedPanels = require(script.Parent.Panels.AdvancedPanels)
local BridgePanel = require(script.Parent.Panels.BridgePanel)

local ConfigPanels = {}

export type ConfigPanelsDeps = {
	configContainer: Frame,
	S: any, -- State table
	ToolId: any, -- TerrainEnums.ToolId
	createBrushVisualization: () -> (),
	hidePlaneVisualization: () -> (),
	getTerrainHitRaw: () -> Vector3?,
	ChangeHistoryService: any,
}

export type ConfigPanelsResult = {
	panels: { [string]: Frame },
	setStrengthValue: (value: number) -> (),
	updateVisibility: () -> (),
	updateBridgeStatus: () -> (),
	updateBridgePreview: (hoverPoint: Vector3?) -> (),
	buildBridge: () -> (),
	updateGradientStatus: () -> (),
}

function ConfigPanels.create(deps: ConfigPanelsDeps): ConfigPanelsResult
	local allPanels: { [string]: Frame } = {}
	local S = deps.S
	local ToolId = deps.ToolId

	-- Create Core Panels (Shape, Strength, Rate, Pivot, Hollow, Spin, PlaneLock, Flatten)
	local coreResult = CorePanels.create({
		configContainer = deps.configContainer,
		S = S,
		createBrushVisualization = deps.createBrushVisualization,
		hidePlaneVisualization = deps.hidePlaneVisualization,
		getTerrainHitRaw = deps.getTerrainHitRaw,
	})
	for k, v in pairs(coreResult.panels) do
		allPanels[k] = v
	end

	-- Create Material Panel
	local materialResult = MaterialPanel.create({
		configContainer = deps.configContainer,
		S = S,
	})
	for k, v in pairs(materialResult.panels) do
		allPanels[k] = v
	end

	-- Create Tool Panels (Path, Clone, Blob, Slope, Megarandomize, Cavity, Melt)
	local toolResult = ToolPanels.create({
		configContainer = deps.configContainer,
		S = S,
	})
	for k, v in pairs(toolResult.panels) do
		allPanels[k] = v
	end

	-- Create Advanced Panels (Gradient, Flood, Stalactite, Tendril, Symmetry, Grid, Growth)
	local advancedResult = AdvancedPanels.create({
		configContainer = deps.configContainer,
		S = S,
	})
	for k, v in pairs(advancedResult.panels) do
		allPanels[k] = v
	end

	-- Create Bridge Panel
	local bridgeResult = BridgePanel.create({
		configContainer = deps.configContainer,
		S = S,
		ChangeHistoryService = deps.ChangeHistoryService,
	})
	for k, v in pairs(bridgeResult.panels) do
		allPanels[k] = v
	end

	-- Set layout order for panels
	local panelOrder = {
		"bridgeInfo",
		"brushShape",
		"strength",
		"brushRate",
		"pivot",
		"hollow",
		"spin",
		"planeLock",
		"flattenMode",
		"material",
		"pathDepth",
		"pathProfile",
		"pathDirectionInfo",
		"cloneInfo",
		"blobIntensity",
		"blobSmoothness",
		"slopeMaterials",
		"megarandomizeSettings",
		"cavitySensitivity",
		"meltViscosity",
		"gradientSettings",
		"floodSettings",
		"stalactiteSettings",
		"tendrilSettings",
		"symmetrySettings",
		"gridSettings",
		"growthSettings",
	}

	for i, panelName in ipairs(panelOrder) do
		if allPanels[panelName] then
			allPanels[panelName].LayoutOrder = i
		end
	end

	-- Create "no tool selected" message
	local noToolMessage = Instance.new("TextLabel")
	noToolMessage.Name = "NoToolMessage"
	noToolMessage.BackgroundTransparency = 1
	noToolMessage.Size = UDim2.new(1, 0, 0, 60)
	noToolMessage.Font = Theme.Fonts.Default
	noToolMessage.TextSize = Theme.Sizes.TextMedium
	noToolMessage.TextColor3 = Theme.Colors.Text
	noToolMessage.Text = "Select a tool above to see its settings"
	noToolMessage.TextWrapped = true
	noToolMessage.LayoutOrder = 0
	noToolMessage.Parent = deps.configContainer

	-- Visibility update function
	local function updateVisibility()
		local toolConfig = BrushData.ToolConfigs[S.currentTool]

		-- Hide all panels first
		for _, panel in pairs(allPanels) do
			panel.Visible = false
		end

		if S.currentTool == ToolId.None or not toolConfig then
			noToolMessage.Visible = true
		else
			noToolMessage.Visible = false
			for _, panelName in ipairs(toolConfig) do
				if allPanels[panelName] then
					allPanels[panelName].Visible = true
				end
			end
		end

		-- Update canvas size after visibility change
		task.defer(function()
			local configLayout = deps.configContainer:FindFirstChildOfClass("UIListLayout")
			if configLayout then
				local totalHeight = Theme.Sizes.ConfigStartY + configLayout.AbsoluteContentSize.Y + 20
				local mainFrame = deps.configContainer.Parent
				if mainFrame and mainFrame:IsA("ScrollingFrame") then
					mainFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(totalHeight, 400))
				end
			end
		end)
	end

	return {
		panels = allPanels,
		setStrengthValue = coreResult.setStrengthValue,
		updateVisibility = updateVisibility,
		updateBridgeStatus = bridgeResult.updateBridgeStatus,
		updateBridgePreview = bridgeResult.updateBridgePreview,
		buildBridge = bridgeResult.buildBridge,
		updateGradientStatus = advancedResult.updateGradientStatus,
	}
end

return ConfigPanels

