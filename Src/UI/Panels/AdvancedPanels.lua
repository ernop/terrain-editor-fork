--!strict
-- AdvancedPanels.lua - Advanced tool settings panels
-- Panels: Gradient, Flood, Stalactite, Tendril, Symmetry, Grid, Growth

local Theme = require(script.Parent.Parent.Parent.Util.Theme)
local UIHelpers = require(script.Parent.Parent.Parent.Util.UIHelpers)
local UIComponents = require(script.Parent.Parent.Parent.Util.UIComponents)
local AnalysisPanels = require(script.Parent.AnalysisPanels)

local AdvancedPanels = {}

export type AdvancedPanelsDeps = {
	configContainer: Frame,
	S: any, -- State table
}

export type AdvancedPanelsResult = {
	panels: { [string]: Frame },
	updateGradientStatus: () -> (),
}

function AdvancedPanels.create(deps: AdvancedPanelsDeps): AdvancedPanelsResult
	local panels: { [string]: Frame } = {}
	local S = deps.S

	-- ========================================================================
	-- Gradient Paint Panel
	-- ========================================================================
	local gradientSettingsPanel = UIHelpers.createConfigPanel(deps.configContainer, "gradientSettings")

	local gradientHeader = UIHelpers.createHeader(gradientSettingsPanel, "Gradient Paint", UDim2.new(0, 0, 0, 0))
	gradientHeader.LayoutOrder = 1

	local gradientDesc = UIHelpers.createDescription(gradientSettingsPanel, "Shift+Click = START, Ctrl+Click = END", 32)
	gradientDesc.LayoutOrder = 2

	local gradientStatusLabel = UIHelpers.createStatusLabel(gradientSettingsPanel, "Shift+Click: Set START", Theme.Colors.Warning)
	gradientStatusLabel.Name = "GradientStatus"
	gradientStatusLabel.LayoutOrder = 3

	local gradient1Row = UIHelpers.createLabeledRow(gradientSettingsPanel, "Start:", 45)
	gradient1Row.row.LayoutOrder = 4

	local gradient1Btn = UIComponents.createMaterialCycleButton({
		parent = gradient1Row.row,
		initialMaterial = S.gradientMaterial1,
		onChange = function(newMat)
			S.gradientMaterial1 = newMat
		end,
		position = UDim2.new(0, 50, 0, 0),
		size = UDim2.new(0, 80, 0, 22),
	})

	local gradient2Btn = UIComponents.createMaterialCycleButton({
		parent = gradient1Row.row,
		initialMaterial = S.gradientMaterial2,
		onChange = function(newMat)
			S.gradientMaterial2 = newMat
		end,
		position = UDim2.new(0, 135, 0, 0),
		size = UDim2.new(0, 80, 0, 22),
	})

	local function updateGradientStatus()
		if not S.gradientStartPoint then
			gradientStatusLabel.Text = "Shift+Click: Set START"
			gradientStatusLabel.TextColor3 = Theme.Colors.Warning
		elseif not S.gradientEndPoint then
			gradientStatusLabel.Text = "Ctrl+Click: Set END"
			gradientStatusLabel.TextColor3 = Theme.Colors.Success
		else
			gradientStatusLabel.Text = "Ready! Paint to apply"
			gradientStatusLabel.TextColor3 = Theme.Colors.Ready
		end
	end
	updateGradientStatus()
	S.updateGradientStatus = updateGradientStatus

	panels["gradientSettings"] = gradientSettingsPanel

	-- ========================================================================
	-- Flood Paint Panel
	-- ========================================================================
	local floodSettingsPanel = UIHelpers.createConfigPanel(deps.configContainer, "floodSettings")

	local floodHeader = UIHelpers.createHeader(floodSettingsPanel, "Flood Paint", UDim2.new(0, 0, 0, 0))
	floodHeader.LayoutOrder = 1

	local floodDesc = UIHelpers.createDescription(floodSettingsPanel, "Replaces material in brush area.")
	floodDesc.LayoutOrder = 2

	local floodTargetRow = UIHelpers.createLabeledRow(floodSettingsPanel, "Paint with:", 70)
	floodTargetRow.row.LayoutOrder = 3

	local floodTargetBtn = UIComponents.createMaterialCycleButton({
		parent = floodTargetRow.row,
		initialMaterial = S.floodTargetMaterial,
		onChange = function(newMat)
			S.floodTargetMaterial = newMat
		end,
		position = UDim2.new(0, 75, 0, 0),
	})

	panels["floodSettings"] = floodSettingsPanel

	-- ========================================================================
	-- Stalactite Panel
	-- ========================================================================
	local stalactiteSettingsPanel = UIHelpers.createConfigPanel(deps.configContainer, "stalactiteSettings")

	local stalacHeader = UIHelpers.createHeader(stalactiteSettingsPanel, "Stalactite", UDim2.new(0, 0, 0, 0))
	stalacHeader.LayoutOrder = 1

	local stalacDesc = UIHelpers.createDescription(stalactiteSettingsPanel, "Creates hanging spike formations.")
	stalacDesc.LayoutOrder = 2

	local stalacDirRow = UIHelpers.createLabeledRow(stalactiteSettingsPanel, "Type:", 60)
	stalacDirRow.row.LayoutOrder = 3

	local stalacDirBtn = UIHelpers.createButton(
		stalacDirRow.row,
		S.stalactiteDirection == -1 and "↓ Down" or "↑ Up",
		UDim2.new(0, 65, 0, 0),
		UDim2.new(0, 80, 0, 22),
		function()
			S.stalactiteDirection = S.stalactiteDirection == -1 and 1 or -1
			stalacDirBtn.Text = S.stalactiteDirection == -1 and "↓ Down" or "↑ Up"
		end
	)

	local _, stalacDensityContainer, _ = UIHelpers.createSlider(
		stalactiteSettingsPanel,
		"Density",
		10,
		80,
		math.floor(S.stalactiteDensity * 100),
		function(v)
			S.stalactiteDensity = v / 100
		end
	)
	stalacDensityContainer.LayoutOrder = 4

	local _, stalacLengthContainer, _ = UIHelpers.createSlider(stalactiteSettingsPanel, "Length", 3, 30, S.stalactiteLength, function(v)
		S.stalactiteLength = v
	end)
	stalacLengthContainer.LayoutOrder = 5

	local stalacRandomBtn = UIComponents.createRandomizeSeedButton(stalactiteSettingsPanel, function(seed)
		S.stalactiteSeed = seed
	end)
	stalacRandomBtn.LayoutOrder = 6

	panels["stalactiteSettings"] = stalactiteSettingsPanel

	-- ========================================================================
	-- Tendril Panel
	-- ========================================================================
	local tendrilSettingsPanel = UIHelpers.createConfigPanel(deps.configContainer, "tendrilSettings")

	local tendrilHeader = UIHelpers.createHeader(tendrilSettingsPanel, "Tendril", UDim2.new(0, 0, 0, 0))
	tendrilHeader.LayoutOrder = 1

	local tendrilDesc = UIHelpers.createDescription(tendrilSettingsPanel, "Organic branching structures (roots, vines).")
	tendrilDesc.LayoutOrder = 2

	local _, tendrilBranchContainer, _ = UIHelpers.createSlider(tendrilSettingsPanel, "Branches", 2, 12, S.tendrilBranches, function(v)
		S.tendrilBranches = v
	end)
	tendrilBranchContainer.LayoutOrder = 3

	local _, tendrilLengthContainer, _ = UIHelpers.createSlider(tendrilSettingsPanel, "Length", 5, 40, S.tendrilLength, function(v)
		S.tendrilLength = v
	end)
	tendrilLengthContainer.LayoutOrder = 4

	local _, tendrilCurlContainer, _ = UIHelpers.createSlider(
		tendrilSettingsPanel,
		"Curl",
		0,
		100,
		math.floor(S.tendrilCurl * 100),
		function(v)
			S.tendrilCurl = v / 100
		end
	)
	tendrilCurlContainer.LayoutOrder = 5

	local tendrilRandomBtn = UIComponents.createRandomizeSeedButton(tendrilSettingsPanel, function(seed)
		S.tendrilSeed = seed
	end)
	tendrilRandomBtn.LayoutOrder = 6

	panels["tendrilSettings"] = tendrilSettingsPanel

	-- ========================================================================
	-- Symmetry Panel
	-- ========================================================================
	local symmetrySettingsPanel = UIHelpers.createConfigPanel(deps.configContainer, "symmetrySettings")

	local symmetryHeader = UIHelpers.createHeader(symmetrySettingsPanel, "Symmetry Tool", UDim2.new(0, 0, 0, 0))
	symmetryHeader.LayoutOrder = 1

	local symmetryDesc = UIHelpers.createDescription(
		symmetrySettingsPanel,
		"Creates symmetric copies of terrain within the brush. First sector is the source, others are mirrored/rotated.",
		40
	)
	symmetryDesc.LayoutOrder = 2

	local symmetryTypeLabel = UIHelpers.createStatusLabel(symmetrySettingsPanel, "Type: " .. S.symmetryType, Theme.Colors.Text)
	symmetryTypeLabel.Font = Theme.Fonts.Bold
	symmetryTypeLabel.LayoutOrder = 3

	local symmetryTypes = {
		{ id = "MirrorX", name = "Mirror X", segments = 2 },
		{ id = "MirrorZ", name = "Mirror Z", segments = 2 },
		{ id = "MirrorXZ", name = "Mirror XZ", segments = 4 },
		{ id = "Radial4", name = "Radial 4", segments = 4 },
		{ id = "Radial6", name = "Radial 6", segments = 6 },
		{ id = "Radial8", name = "Radial 8", segments = 8 },
	}

	local symmetryGroup = UIComponents.createButtonGroup({
		parent = symmetrySettingsPanel,
		options = symmetryTypes,
		initialValue = S.symmetryType,
		onChange = function(newType)
			S.symmetryType = newType
			for _, typeInfo in ipairs(symmetryTypes) do
				if typeInfo.id == newType then
					S.symmetrySegments = typeInfo.segments
					break
				end
			end
			symmetryTypeLabel.Text = "Type: " .. newType
		end,
		layout = "grid",
		buttonSize = UDim2.new(0, 80, 0, 26),
	})
	symmetryGroup.container.LayoutOrder = 4

	local symmetryNote = UIHelpers.createNote(symmetrySettingsPanel, "Tip: Use large brush with Cube shape for best results")
	symmetryNote.LayoutOrder = 5

	panels["symmetrySettings"] = symmetrySettingsPanel

	-- ========================================================================
	-- Variation Grid Panel
	-- ========================================================================
	local gridSettingsPanel = UIHelpers.createConfigPanel(deps.configContainer, "gridSettings")

	local gridHeader = UIHelpers.createHeader(gridSettingsPanel, "Variation Grid", UDim2.new(0, 0, 0, 0))
	gridHeader.LayoutOrder = 1

	local gridDesc = UIHelpers.createDescription(gridSettingsPanel, "Creates a grid pattern with height variation per cell.")
	gridDesc.LayoutOrder = 2

	local _, gridCellSizeContainer, _ = UIHelpers.createSlider(gridSettingsPanel, "Cell Size", 4, 24, S.gridCellSize, function(v)
		S.gridCellSize = v
	end)
	gridCellSizeContainer.LayoutOrder = 3

	local _, gridVariationContainer, _ = UIHelpers.createSlider(
		gridSettingsPanel,
		"Variation",
		0,
		100,
		math.floor(S.gridVariation * 100),
		function(v)
			S.gridVariation = v / 100
		end
	)
	gridVariationContainer.LayoutOrder = 4

	local gridRandomBtn = UIComponents.createRandomizeSeedButton(gridSettingsPanel, function(seed)
		S.gridSeed = seed
	end)
	gridRandomBtn.LayoutOrder = 5

	panels["gridSettings"] = gridSettingsPanel

	-- ========================================================================
	-- Growth Simulation Panel
	-- ========================================================================
	local growthSettingsPanel = UIHelpers.createConfigPanel(deps.configContainer, "growthSettings")

	local growthHeader = UIHelpers.createHeader(growthSettingsPanel, "Growth Simulation", UDim2.new(0, 0, 0, 0))
	growthHeader.LayoutOrder = 1

	local growthDesc =
		UIHelpers.createDescription(growthSettingsPanel, "Expands existing terrain organically. Paint near terrain edges to grow.", 32)
	growthDesc.LayoutOrder = 2

	local _, growthRateContainer, _ = UIHelpers.createSlider(
		growthSettingsPanel,
		"Rate",
		10,
		80,
		math.floor(S.growthRate * 100),
		function(v)
			S.growthRate = v / 100
		end
	)
	growthRateContainer.LayoutOrder = 3

	local _, growthBiasContainer, _ = UIHelpers.createSlider(
		growthSettingsPanel,
		"Bias (↓-0-↑)",
		0,
		200,
		math.floor((S.growthBias + 1) * 100),
		function(v)
			S.growthBias = (v / 100) - 1
		end
	)
	growthBiasContainer.LayoutOrder = 4

	local growthPatternLabel = UIHelpers.createStatusLabel(growthSettingsPanel, "Pattern: " .. S.growthPattern, Theme.Colors.Text)
	growthPatternLabel.Font = Theme.Fonts.Bold
	growthPatternLabel.LayoutOrder = 5

	local growthPatterns = { "organic", "crystalline", "cellular" }
	local growthPatternIdx = 1
	for i, p in ipairs(growthPatterns) do
		if p == S.growthPattern then
			growthPatternIdx = i
			break
		end
	end

	local growthPatternBtn = UIHelpers.createActionButton(growthSettingsPanel, "Cycle Pattern", function()
		growthPatternIdx = (growthPatternIdx % #growthPatterns) + 1
		S.growthPattern = growthPatterns[growthPatternIdx]
		growthPatternLabel.Text = "Pattern: " .. S.growthPattern
	end)
	growthPatternBtn.LayoutOrder = 6

	local growthRandomBtn = UIComponents.createRandomizeSeedButton(growthSettingsPanel, function(seed)
		S.growthSeed = seed
	end)
	growthRandomBtn.LayoutOrder = 7

	panels["growthSettings"] = growthSettingsPanel

	-- Delegate analysis panels to AnalysisPanels module
	local analysisResult = AnalysisPanels.create(deps)
	for panelName, panelFrame in pairs(analysisResult.panels) do
		panels[panelName] = panelFrame
	end

	return {
		panels = panels,
		updateGradientStatus = updateGradientStatus,
	}
end

return AdvancedPanels
