--!strict
-- BridgePanel.lua - Bridge tool panel with complex state management
-- Returns: panel, updateBridgeStatus, updateBridgePreview, buildBridge functions

local Theme = require(script.Parent.Parent.Parent.Util.Theme)
local UIHelpers = require(script.Parent.Parent.Parent.Util.UIHelpers)
local UIComponents = require(script.Parent.Parent.Parent.Util.UIComponents)
local BrushData = require(script.Parent.Parent.Parent.Util.BrushData)
local Constants = require(script.Parent.Parent.Parent.Util.Constants)
local BridgePathGenerator = require(script.Parent.Parent.Parent.Util.BridgePathGenerator)

local BridgePanel = {}

export type BridgePanelDeps = {
	configContainer: Frame,
	S: any, -- State table
	ChangeHistoryService: any,
}

export type BridgePanelResult = {
	panels: { [string]: Frame },
	updateBridgeStatus: () -> (),
	updateBridgePreview: (hoverPoint: Vector3?) -> (),
	buildBridge: () -> (),
}

function BridgePanel.create(deps: BridgePanelDeps): BridgePanelResult
	local panels: { [string]: Frame } = {}
	local S = deps.S
	local ChangeHistoryService = deps.ChangeHistoryService

	-- Forward declare for callbacks
	local updateBridgePreview: ((hoverPoint: Vector3?) -> ())?
	local updateBridgeStatus: (() -> ())?

	-- Bridge Info Panel
	local bridgeInfoPanel = UIHelpers.createConfigPanel(deps.configContainer, "bridgeInfo")

	local bridgeHeader = UIHelpers.createHeader(bridgeInfoPanel, "Bridge Tool", UDim2.new(0, 0, 0, 0))
	bridgeHeader.LayoutOrder = 1

	local bridgeInstructions = UIHelpers.createInstructions(
		bridgeInfoPanel,
		"Click to set START point, then click again to set END point.",
		50
	)
	bridgeInstructions.LayoutOrder = 2

	local bridgeStatusLabel = UIHelpers.createStatusLabel(bridgeInfoPanel, "Status: Click to set START", Theme.Colors.Warning)
	bridgeStatusLabel.LayoutOrder = 3

	-- Width slider
	local _, bridgeWidthContainer, _ = UIHelpers.createSlider(bridgeInfoPanel, "Width", 1, 20, S.bridgeWidth, function(val)
		S.bridgeWidth = val
		S.bridgeLastPreviewParams = nil
		if updateBridgePreview then
			updateBridgePreview(S.bridgeHoverPoint)
		end
	end)
	bridgeWidthContainer.LayoutOrder = 4

	-- Intensity slider (how extreme the variations are)
	local _, intensityContainer, _ = UIHelpers.createSlider(bridgeInfoPanel, "Intensity", 10, 300, math.floor(S.bridgeIntensity * 100), function(val)
		S.bridgeIntensity = val / 100
		S.bridgeLastPreviewParams = nil
		if updateBridgePreview then
			updateBridgePreview(S.bridgeHoverPoint)
		end
	end)
	intensityContainer.LayoutOrder = 5

	-- Segments slider (0 = auto, up to 1000 for dense paths)
	local _, segmentsContainer, _ = UIHelpers.createSlider(bridgeInfoPanel, "Segments", 0, 1000, S.bridgeSegments, function(val)
		S.bridgeSegments = val
		S.bridgeLastPreviewParams = nil
		if updateBridgePreview then
			updateBridgePreview(S.bridgeHoverPoint)
		end
	end)
	segmentsContainer.LayoutOrder = 6

	-- Use brush shape toggle
	local useBrushShapeToggle = UIComponents.createCheckbox({
		parent = bridgeInfoPanel,
		label = "Use selected brush shape",
		initialState = S.bridgeUseBrushShape,
		onChange = function(enabled)
			S.bridgeUseBrushShape = enabled
			S.bridgeLastPreviewParams = nil
			if updateBridgePreview then
				updateBridgePreview(S.bridgeHoverPoint)
			end
		end,
	})
	useBrushShapeToggle.container.LayoutOrder = 7

	-- Anchor endpoints toggle (prevents start/end drift with intensity changes)
	local anchorEndpointsToggle = UIComponents.createCheckbox({
		parent = bridgeInfoPanel,
		label = "Anchor start/end points",
		initialState = S.bridgeAnchorEndpoints == nil and true or S.bridgeAnchorEndpoints,
		onChange = function(enabled)
			S.bridgeAnchorEndpoints = enabled
			S.bridgeLastPreviewParams = nil
			if updateBridgePreview then
				updateBridgePreview(S.bridgeHoverPoint)
			end
		end,
	})
	anchorEndpointsToggle.container.LayoutOrder = 7.1

	-- Terrain awareness toggle
	local terrainAwarenessToggle = UIComponents.createCheckbox({
		parent = bridgeInfoPanel,
		label = "Terrain aware (avoid collisions)",
		initialState = S.bridgeTerrainAware or false,
		onChange = function(enabled)
			S.bridgeTerrainAware = enabled
			S.bridgeLastPreviewParams = nil
			if updateBridgePreview then
				updateBridgePreview(S.bridgeHoverPoint)
			end
		end,
	})
	terrainAwarenessToggle.container.LayoutOrder = 7.2

	-- Plane constraint slider
	local _, planeConstraintContainer, _ = UIHelpers.createSlider(bridgeInfoPanel, "Plane Lock", 0, 100, math.floor((S.bridgePlaneConstraint or 0) * 100), function(val)
		S.bridgePlaneConstraint = val / 100
		S.bridgeLastPreviewParams = nil
		if updateBridgePreview then
			updateBridgePreview(S.bridgeHoverPoint)
		end
	end)
	planeConstraintContainer.LayoutOrder = 7.3

	-- Axis rotation slider (rotate bridge around its own axis)
	local _, axisRotationContainer, _ = UIHelpers.createSlider(bridgeInfoPanel, "Axis Roll", 0, 360, S.bridgeAxisRotation or 0, function(val)
		S.bridgeAxisRotation = val
		S.bridgeLastPreviewParams = nil
		if updateBridgePreview then
			updateBridgePreview(S.bridgeHoverPoint)
		end
	end)
	axisRotationContainer.LayoutOrder = 7.4

	-- Style header
	local variantLabel = UIHelpers.createHeader(bridgeInfoPanel, "Style", UDim2.new(0, 0, 0, 0))
	variantLabel.LayoutOrder = 8

	-- Variant buttons
	local variantGroup = UIComponents.createButtonGroup({
		parent = bridgeInfoPanel,
		options = (function()
			local opts = {}
			for _, v in ipairs(BrushData.BridgeVariants) do
				table.insert(opts, { id = v, name = v })
			end
			return opts
		end)(),
		initialValue = S.bridgeVariant,
		onChange = function(variant)
			S.bridgeVariant = variant
			S.bridgeLastPreviewParams = nil

			-- Initialize curves when switching to MegaMeander
			if variant == "MegaMeander" and S.bridgeStartPoint and (S.bridgeEndPoint or S.bridgeHoverPoint) then
				if #S.bridgeCurves == 0 then
					S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
				end
			else
				S.bridgeCurves = {}
			end

			if updateBridgeStatus then
				updateBridgeStatus()
			end
			if updateBridgePreview then
				updateBridgePreview(S.bridgeHoverPoint)
			end
		end,
		layout = "grid",
		buttonSize = UDim2.new(0, 80, 0, 26),
	})
	variantGroup.container.LayoutOrder = 9

	-- Clear button
	local clearBridgeBtn = UIHelpers.createButton(bridgeInfoPanel, "Clear Points", UDim2.new(0, 0, 0, 0), UDim2.new(0, 100, 0, 28), function()
		S.bridgeStartPoint = nil
		S.bridgeEndPoint = nil
		S.bridgeCurves = {}
		S.bridgeHoverPoint = nil
		S.bridgeLastPreviewParams = nil
		bridgeStatusLabel.Text = "Status: Click to set START"

		for _, part in ipairs(S.bridgePreviewParts) do
			part:Destroy()
		end
		S.bridgePreviewParts = {}

		if updateBridgeStatus then
			updateBridgeStatus()
		end
	end)
	clearBridgeBtn.LayoutOrder = 20

	-- Meander controls (only visible for MegaMeander with both points set)
	local meanderControlsContainer = UIHelpers.createAutoContainer(bridgeInfoPanel, "MeanderControls")
	meanderControlsContainer.LayoutOrder = 21
	meanderControlsContainer.Visible = false

	local redoLayoutBtn = UIHelpers.createActionButton(meanderControlsContainer, "🔄 Re-randomize Layout", function()
		if S.bridgeStartPoint and (S.bridgeEndPoint or S.bridgeHoverPoint) then
			if S.bridgeVariant == "MegaMeander" then
				S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
			else
				S.bridgeCurves = BridgePathGenerator.generateRandomCurves(math.min(3, S.bridgeMeanderComplexity))
			end
			S.bridgeLastPreviewParams = nil
			if updateBridgePreview then
				updateBridgePreview(S.bridgeHoverPoint)
			end
		end
	end)
	redoLayoutBtn.Size = UDim2.new(1, 0, 0, 32)
	redoLayoutBtn.LayoutOrder = 1

	local addCurveBtn = UIHelpers.createActionButton(meanderControlsContainer, "➕ Add Curve", function()
		if #S.bridgeCurves < 50 then
			table.insert(S.bridgeCurves, BridgePathGenerator.generateRandomCurve())
			S.bridgeLastPreviewParams = nil
			if updateBridgePreview then
				updateBridgePreview(S.bridgeHoverPoint)
			end
		end
	end)
	addCurveBtn.Size = UDim2.new(1, 0, 0, 32)
	addCurveBtn.LayoutOrder = 2

	local complexityLabel = UIHelpers.createHeader(meanderControlsContainer, "Meander Complexity", UDim2.new(0, 0, 0, 0))
	complexityLabel.LayoutOrder = 3

	local _, complexityContainer, _ = UIHelpers.createSlider(meanderControlsContainer, "Curves", 1, 50, S.bridgeMeanderComplexity, function(value)
		S.bridgeMeanderComplexity = value
		if S.bridgeVariant == "MegaMeander" and S.bridgeStartPoint and (S.bridgeEndPoint or S.bridgeHoverPoint) then
			S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
			S.bridgeLastPreviewParams = nil
			if updateBridgePreview then
				updateBridgePreview(S.bridgeHoverPoint)
			end
		end
	end)
	complexityContainer.LayoutOrder = 4

	panels["bridgeInfo"] = bridgeInfoPanel

	-- ========================================================================
	-- Bridge Functions
	-- ========================================================================

	updateBridgeStatus = function()
		if S.bridgeStartPoint and S.bridgeEndPoint then
			bridgeStatusLabel.Text = "Status: READY - Click to build!"
			bridgeStatusLabel.TextColor3 = Theme.Colors.Success
			meanderControlsContainer.Visible = (S.bridgeVariant == "MegaMeander")
		elseif S.bridgeStartPoint then
			bridgeStatusLabel.Text = "Status: Click to set END"
			bridgeStatusLabel.TextColor3 = Theme.Colors.Warning
			meanderControlsContainer.Visible = false
		else
			bridgeStatusLabel.Text = "Status: Click to set START"
			bridgeStatusLabel.TextColor3 = Theme.Colors.Warning
			meanderControlsContainer.Visible = false
		end
	end

	-- Build settings table from current state
	local function getBridgeSettings(endPoint: Vector3): BridgePathGenerator.BridgeSettings
		return {
			startPoint = S.bridgeStartPoint,
			endPoint = endPoint,
			variant = S.bridgeVariant,
			intensity = S.bridgeIntensity,
			segments = S.bridgeSegments,
			anchorEndpoints = S.bridgeAnchorEndpoints ~= false,
			planeConstraint = S.bridgePlaneConstraint or 0,
			axisRotation = S.bridgeAxisRotation or 0,
			terrainAware = S.bridgeTerrainAware or false,
			terrain = S.terrain,
			curves = S.bridgeCurves,
			meanderComplexity = S.bridgeMeanderComplexity,
		}
	end

	updateBridgePreview = function(hoverPoint: Vector3?)
		if hoverPoint then
			S.bridgeHoverPoint = hoverPoint
		end

		-- Clear existing preview parts
		for _, part in ipairs(S.bridgePreviewParts) do
			part:Destroy()
		end
		S.bridgePreviewParts = {}

		if not S.bridgeStartPoint then
			return
		end

		-- Create start marker
		local startMarker = Instance.new("Part")
		startMarker.Archivable = false
		startMarker.Size = Vector3.new(S.bridgeWidth, S.bridgeWidth, S.bridgeWidth) * Constants.VOXEL_RESOLUTION
		startMarker.CFrame = CFrame.new(S.bridgeStartPoint)
		startMarker.Anchored = true
		startMarker.CanCollide = false
		startMarker.Material = Enum.Material.Neon
		startMarker.Color = Theme.Colors.BridgeStart
		startMarker.Transparency = Theme.Transparency.PreviewMarker
		startMarker.Parent = workspace
		table.insert(S.bridgePreviewParts, startMarker)

		local endPoint = S.bridgeEndPoint or hoverPoint
		if endPoint then
			-- Create end marker
			local endMarker = Instance.new("Part")
			endMarker.Archivable = false
			endMarker.Size = Vector3.new(S.bridgeWidth, S.bridgeWidth, S.bridgeWidth) * Constants.VOXEL_RESOLUTION
			endMarker.CFrame = CFrame.new(endPoint)
			endMarker.Anchored = true
			endMarker.CanCollide = false
			endMarker.Material = Enum.Material.Neon
			endMarker.Color = Theme.Colors.BridgeEnd
			endMarker.Transparency = Theme.Transparency.PreviewMarker
			endMarker.Parent = workspace
			table.insert(S.bridgePreviewParts, endMarker)

			-- Generate path using unified generator
			local positions = BridgePathGenerator.generatePath(getBridgeSettings(endPoint))

			for _, position in ipairs(positions) do
				local pathMarker = Instance.new("Part")
				pathMarker.Archivable = false
				pathMarker.Size = Vector3.new(S.bridgeWidth * 0.5, S.bridgeWidth * 0.5, S.bridgeWidth * 0.5) * Constants.VOXEL_RESOLUTION
				pathMarker.CFrame = CFrame.new(position)
				pathMarker.Anchored = true
				pathMarker.CanCollide = false
				pathMarker.Material = Enum.Material.Neon
				pathMarker.Color = Theme.Colors.BridgePath
				pathMarker.Transparency = Theme.Transparency.PathMarker
				pathMarker.Shape = Enum.PartType.Ball
				pathMarker.Parent = workspace
				table.insert(S.bridgePreviewParts, pathMarker)
			end
		end
	end

	local function buildBridge()
		if not S.bridgeStartPoint or not S.bridgeEndPoint then
			return
		end

		-- Generate path using same function as preview
		local positions = BridgePathGenerator.generatePath(getBridgeSettings(S.bridgeEndPoint))
		if #positions == 0 then
			return
		end

		ChangeHistoryService:SetWaypoint("TerrainBridge_Start")

		local radius = S.bridgeWidth * Constants.VOXEL_RESOLUTION / 2

		for _, position in ipairs(positions) do
			if S.bridgeUseBrushShape and S.performBridgeBrush then
				S.performBridgeBrush(position)
			else
				S.terrain:FillBall(position, radius, S.brushMaterial)
			end
		end

		ChangeHistoryService:SetWaypoint("TerrainBridge_End")

		-- Reset state
		S.bridgeStartPoint = nil
		S.bridgeEndPoint = nil
		S.bridgeCurves = {}
		S.bridgeHoverPoint = nil
		S.bridgeLastPreviewParams = nil

		updateBridgeStatus()
		updateBridgePreview(nil)
	end

	return {
		panels = panels,
		updateBridgeStatus = updateBridgeStatus,
		updateBridgePreview = updateBridgePreview,
		buildBridge = buildBridge,
	}
end

return BridgePanel

