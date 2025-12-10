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

	-- Style header
	local variantLabel = UIHelpers.createHeader(bridgeInfoPanel, "Style", UDim2.new(0, 0, 0, 0))
	variantLabel.LayoutOrder = 5

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
	variantGroup.container.LayoutOrder = 6

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
	clearBridgeBtn.LayoutOrder = 10

	-- Meander controls (only visible for MegaMeander with both points set)
	local meanderControlsContainer = UIHelpers.createAutoContainer(bridgeInfoPanel, "MeanderControls")
	meanderControlsContainer.LayoutOrder = 11
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

	updateBridgePreview = function(hoverPoint: Vector3?)
		-- Update hover point if provided
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
			endMarker.Size = Vector3.new(S.bridgeWidth, S.bridgeWidth, S.bridgeWidth) * Constants.VOXEL_RESOLUTION
			endMarker.CFrame = CFrame.new(endPoint)
			endMarker.Anchored = true
			endMarker.CanCollide = false
			endMarker.Material = Enum.Material.Neon
			endMarker.Color = Theme.Colors.BridgeEnd
			endMarker.Transparency = Theme.Transparency.PreviewMarker
			endMarker.Parent = workspace
			table.insert(S.bridgePreviewParts, endMarker)

			local distance = (endPoint - S.bridgeStartPoint).Magnitude
			local steps = math.max(2, math.floor(distance / (Constants.VOXEL_RESOLUTION * 2)))

			-- Generate path preview
			if S.bridgeVariant == "MegaMeander" then
				-- Initialize curves if empty
				if #S.bridgeCurves == 0 then
					S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
				end

				local path = BridgePathGenerator.generateMeanderingPath(
					S.bridgeStartPoint,
					endPoint,
					S.bridgeCurves,
					S.terrain,
					steps,
					true
				)

				for i, pathPoint in ipairs(path) do
					if i > 1 and i < #path then
						local pathMarker = Instance.new("Part")
						pathMarker.Size = Vector3.new(S.bridgeWidth * 0.5, S.bridgeWidth * 0.5, S.bridgeWidth * 0.5) * Constants.VOXEL_RESOLUTION
						pathMarker.CFrame = CFrame.new(pathPoint.position)
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
			else
				-- Use original path generation for other variants
				local pathDir = (endPoint - S.bridgeStartPoint).Unit
				local perpDir = Vector3.new(-pathDir.Z, 0, pathDir.X)

				for i = 1, steps - 1 do
					local t = i / steps
					local pos = S.bridgeStartPoint:Lerp(endPoint, t)
					local offset = BrushData.getBridgeOffset(t, distance, S.bridgeVariant)
					local finalOffset = Vector3.new(0, offset.Y, 0) + perpDir * offset.X

					local pathMarker = Instance.new("Part")
					pathMarker.Size = Vector3.new(S.bridgeWidth * 0.5, S.bridgeWidth * 0.5, S.bridgeWidth * 0.5) * Constants.VOXEL_RESOLUTION
					pathMarker.CFrame = CFrame.new(pos + finalOffset)
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
	end

	local function buildBridge()
		if not S.bridgeStartPoint or not S.bridgeEndPoint then
			return
		end

		ChangeHistoryService:SetWaypoint("TerrainBridge_Start")

		local distance = (S.bridgeEndPoint - S.bridgeStartPoint).Magnitude
		local steps = math.max(3, math.floor(distance / Constants.VOXEL_RESOLUTION))
		local radius = S.bridgeWidth * Constants.VOXEL_RESOLUTION / 2

		if S.bridgeVariant == "MegaMeander" then
			if #S.bridgeCurves == 0 then
				S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
			end

			local path = BridgePathGenerator.generateMeanderingPath(
				S.bridgeStartPoint,
				S.bridgeEndPoint,
				S.bridgeCurves,
				S.terrain,
				steps,
				true
			)

			for _, pathPoint in ipairs(path) do
				S.terrain:FillBall(pathPoint.position, radius, S.brushMaterial)
			end
		else
			local pathDir = (S.bridgeEndPoint - S.bridgeStartPoint).Unit
			local perpDir = Vector3.new(-pathDir.Z, 0, pathDir.X)

			for i = 0, steps do
				local t = i / steps
				local pos = S.bridgeStartPoint:Lerp(S.bridgeEndPoint, t)
				local offset = BrushData.getBridgeOffset(t, distance, S.bridgeVariant)
				local finalOffset = Vector3.new(0, offset.Y, 0) + perpDir * offset.X
				local bridgePos = pos + finalOffset
				S.terrain:FillBall(bridgePos, radius, S.brushMaterial)
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

