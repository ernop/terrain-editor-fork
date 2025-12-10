--!strict
-- AdvancedPanels.lua - Advanced tool settings panels
-- Panels: Gradient, Flood, Stalactite, Tendril, Symmetry, Grid, Growth

local Theme = require(script.Parent.Parent.Parent.Util.Theme)
local UIHelpers = require(script.Parent.Parent.Parent.Util.UIHelpers)
local UIComponents = require(script.Parent.Parent.Parent.Util.UIComponents)

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

	-- ========================================================================
	-- Voxel Inspect Panel (Analysis Tool)
	-- ========================================================================
	local voxelInspectPanel = UIHelpers.createConfigPanel(deps.configContainer, "voxelInspectPanel")

	local voxelHeader = UIHelpers.createHeader(voxelInspectPanel, "🔍 Voxel Inspector", UDim2.new(0, 0, 0, 0))
	voxelHeader.LayoutOrder = 1

	local voxelDesc = UIHelpers.createDescription(voxelInspectPanel, "Hover terrain to inspect. Click to lock & edit.", 28)
	voxelDesc.LayoutOrder = 2

	-- Status label (locked/hovering)
	local voxelStatusLabel = UIHelpers.createStatusLabel(voxelInspectPanel, "Move over terrain...", Theme.Colors.TextDim)
	voxelStatusLabel.Name = "VoxelStatus"
	voxelStatusLabel.LayoutOrder = 3

	-- Position display
	local voxelPosLabel = Instance.new("TextLabel")
	voxelPosLabel.Name = "VoxelPosition"
	voxelPosLabel.BackgroundTransparency = 1
	voxelPosLabel.Size = UDim2.new(1, -20, 0, 20)
	voxelPosLabel.Font = Enum.Font.RobotoMono
	voxelPosLabel.TextSize = 12
	voxelPosLabel.TextColor3 = Theme.Colors.Text
	voxelPosLabel.TextXAlignment = Enum.TextXAlignment.Left
	voxelPosLabel.Text = "Pos: ---"
	voxelPosLabel.LayoutOrder = 4
	voxelPosLabel.Parent = voxelInspectPanel

	-- Grid position display
	local voxelGridLabel = Instance.new("TextLabel")
	voxelGridLabel.Name = "VoxelGrid"
	voxelGridLabel.BackgroundTransparency = 1
	voxelGridLabel.Size = UDim2.new(1, -20, 0, 20)
	voxelGridLabel.Font = Enum.Font.RobotoMono
	voxelGridLabel.TextSize = 12
	voxelGridLabel.TextColor3 = Theme.Colors.Text
	voxelGridLabel.TextXAlignment = Enum.TextXAlignment.Left
	voxelGridLabel.Text = "Grid: ---"
	voxelGridLabel.LayoutOrder = 5
	voxelGridLabel.Parent = voxelInspectPanel

	-- Material display
	local voxelMatLabel = Instance.new("TextLabel")
	voxelMatLabel.Name = "VoxelMaterial"
	voxelMatLabel.BackgroundTransparency = 1
	voxelMatLabel.Size = UDim2.new(1, -20, 0, 20)
	voxelMatLabel.Font = Enum.Font.RobotoMono
	voxelMatLabel.TextSize = 12
	voxelMatLabel.TextColor3 = Theme.Colors.Text
	voxelMatLabel.TextXAlignment = Enum.TextXAlignment.Left
	voxelMatLabel.Text = "Material: ---"
	voxelMatLabel.LayoutOrder = 6
	voxelMatLabel.Parent = voxelInspectPanel

	-- Occupancy display
	local voxelOccLabel = Instance.new("TextLabel")
	voxelOccLabel.Name = "VoxelOccupancy"
	voxelOccLabel.BackgroundTransparency = 1
	voxelOccLabel.Size = UDim2.new(1, -20, 0, 20)
	voxelOccLabel.Font = Enum.Font.RobotoMono
	voxelOccLabel.TextSize = 12
	voxelOccLabel.TextColor3 = Theme.Colors.Text
	voxelOccLabel.TextXAlignment = Enum.TextXAlignment.Left
	voxelOccLabel.Text = "Occupancy: ---"
	voxelOccLabel.LayoutOrder = 7
	voxelOccLabel.Parent = voxelInspectPanel

	-- Occupancy bar visualization
	local occBarContainer = Instance.new("Frame")
	occBarContainer.Name = "OccupancyBarContainer"
	occBarContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	occBarContainer.BorderSizePixel = 0
	occBarContainer.Size = UDim2.new(1, -20, 0, 16)
	occBarContainer.LayoutOrder = 8
	occBarContainer.Parent = voxelInspectPanel

	local occBar = Instance.new("Frame")
	occBar.Name = "OccupancyBar"
	occBar.BackgroundColor3 = Color3.fromRGB(80, 180, 255)
	occBar.BorderSizePixel = 0
	occBar.Size = UDim2.new(0, 0, 1, 0)
	occBar.Parent = occBarContainer

	local occBarCorner = Instance.new("UICorner")
	occBarCorner.CornerRadius = UDim.new(0, 3)
	occBarCorner.Parent = occBar

	-- Edit section (visible when locked)
	local editSection = Instance.new("Frame")
	editSection.Name = "EditSection"
	editSection.BackgroundTransparency = 1
	editSection.Size = UDim2.new(1, 0, 0, 130)
	editSection.Visible = false
	editSection.LayoutOrder = 9
	editSection.Parent = voxelInspectPanel

	local editSectionLayout = Instance.new("UIListLayout")
	editSectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	editSectionLayout.Padding = UDim.new(0, 5)
	editSectionLayout.Parent = editSection

	local editHeader = Instance.new("TextLabel")
	editHeader.BackgroundTransparency = 1
	editHeader.Size = UDim2.new(1, 0, 0, 20)
	editHeader.Font = Enum.Font.GothamBold
	editHeader.TextSize = 12
	editHeader.TextColor3 = Color3.fromRGB(100, 200, 255)
	editHeader.TextXAlignment = Enum.TextXAlignment.Left
	editHeader.Text = "─── EDIT MODE ───"
	editHeader.LayoutOrder = 1
	editHeader.Parent = editSection

	-- Occupancy edit slider
	local _, editOccSliderContainer, editOccSlider = UIHelpers.createSlider(editSection, "Set Occ", 0, 100, 50, function(v)
		if S.voxelInspectLocked and S.voxelInspectGridPos then
			local VOXEL_SIZE = 4
			local gridPos = S.voxelInspectGridPos
			local voxelMin = Vector3.new(gridPos.X * VOXEL_SIZE, gridPos.Y * VOXEL_SIZE, gridPos.Z * VOXEL_SIZE)
			local voxelMax = voxelMin + Vector3.new(VOXEL_SIZE, VOXEL_SIZE, VOXEL_SIZE)
			local region = Region3.new(voxelMin, voxelMax)

			-- Read current material
			local materials, _ = S.terrain:ReadVoxels(region, VOXEL_SIZE)
			local currentMat = materials[1][1][1]
			if currentMat == Enum.Material.Air then
				currentMat = Enum.Material.Grass -- Default to grass if air
			end

			-- Write new occupancy
			local newOcc = v / 100
			local newMats = { { { currentMat } } }
			local newOccs = { { { newOcc } } }
			S.terrain:WriteVoxels(region, VOXEL_SIZE, newMats, newOccs)

			-- Update state
			S.voxelInspectOccupancy = newOcc
			S.voxelInspectMaterial = currentMat

			-- Update display
			if S.updateVoxelInspectDisplay then
				S.updateVoxelInspectDisplay()
			end
		end
	end)
	editOccSliderContainer.LayoutOrder = 2

	-- Material edit button
	local editMatRow = UIHelpers.createLabeledRow(editSection, "Set Mat:", 55)
	editMatRow.row.LayoutOrder = 3

	local editMaterialBtn = UIComponents.createMaterialCycleButton({
		parent = editMatRow.row,
		initialMaterial = Enum.Material.Grass,
		onChange = function(newMat)
			if S.voxelInspectLocked and S.voxelInspectGridPos then
				local VOXEL_SIZE = 4
				local gridPos = S.voxelInspectGridPos
				local voxelMin = Vector3.new(gridPos.X * VOXEL_SIZE, gridPos.Y * VOXEL_SIZE, gridPos.Z * VOXEL_SIZE)
				local voxelMax = voxelMin + Vector3.new(VOXEL_SIZE, VOXEL_SIZE, VOXEL_SIZE)
				local region = Region3.new(voxelMin, voxelMax)

				-- Use current occupancy or default to 1 if none
				local occ = S.voxelInspectOccupancy > 0 and S.voxelInspectOccupancy or 1

				-- Write new material with occupancy
				local newMats = { { { newMat } } }
				local newOccs = { { { occ } } }
				S.terrain:WriteVoxels(region, VOXEL_SIZE, newMats, newOccs)

				-- Update state
				S.voxelInspectMaterial = newMat

				-- Update display
				if S.updateVoxelInspectDisplay then
					S.updateVoxelInspectDisplay()
				end
			end
		end,
		position = UDim2.fromOffset(60, 0),
		size = UDim2.fromOffset(100, 22),
	})

	-- Store edit slider reference for syncing
	S.voxelInspectEditOccSlider = editOccSlider

	-- Store references for updates
	S.voxelInspectUI = {
		statusLabel = voxelStatusLabel,
		posLabel = voxelPosLabel,
		gridLabel = voxelGridLabel,
		matLabel = voxelMatLabel,
		occLabel = voxelOccLabel,
		occBar = occBar,
		editSection = editSection,
	}

	-- Update function for voxel inspector
	local function updateVoxelInspectDisplay()
		local ui = S.voxelInspectUI
		if not ui then
			return
		end

		if S.voxelInspectLocked then
			ui.statusLabel.Text = "🔒 LOCKED - Click terrain to unlock"
			ui.statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
			ui.editSection.Visible = true
			-- Sync the edit slider to current occupancy
			if S.voxelInspectEditOccSlider then
				local occPercent = math.floor((S.voxelInspectOccupancy or 0) * 100)
				-- Update slider visually (if it has a setValue method or we can update the fill)
			end
		else
			ui.statusLabel.Text = "Move over terrain..."
			ui.statusLabel.TextColor3 = Theme.Colors.TextDim
			ui.editSection.Visible = false
		end

		if S.voxelInspectPosition then
			local p = S.voxelInspectPosition
			ui.posLabel.Text = string.format("Pos: %.1f, %.1f, %.1f", p.X, p.Y, p.Z)
		else
			ui.posLabel.Text = "Pos: ---"
		end

		if S.voxelInspectGridPos then
			local g = S.voxelInspectGridPos
			ui.gridLabel.Text = string.format("Grid: %d, %d, %d", g.X, g.Y, g.Z)
		else
			ui.gridLabel.Text = "Grid: ---"
		end

		local mat = S.voxelInspectMaterial
		if mat and mat ~= Enum.Material.Air then
			ui.matLabel.Text = "Material: " .. mat.Name
			ui.matLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
		else
			ui.matLabel.Text = "Material: Air"
			ui.matLabel.TextColor3 = Theme.Colors.TextDim
		end

		local occ = S.voxelInspectOccupancy or 0
		ui.occLabel.Text = string.format("Occupancy: %.2f (%.0f%%)", occ, occ * 100)
		ui.occBar.Size = UDim2.new(occ, 0, 1, 0)

		-- Color the bar based on occupancy
		if occ > 0.8 then
			ui.occBar.BackgroundColor3 = Color3.fromRGB(80, 255, 120) -- Green for solid
		elseif occ > 0.3 then
			ui.occBar.BackgroundColor3 = Color3.fromRGB(255, 220, 80) -- Yellow for partial
		else
			ui.occBar.BackgroundColor3 = Color3.fromRGB(255, 100, 100) -- Red for sparse
		end
	end

	S.updateVoxelInspectDisplay = updateVoxelInspectDisplay

	-- Unlock button
	local unlockBtn = UIHelpers.createActionButton(voxelInspectPanel, "Unlock / Clear", function()
		S.voxelInspectLocked = false
		S.voxelInspectPosition = nil
		S.voxelInspectGridPos = nil
		S.voxelInspectOccupancy = 0
		S.voxelInspectMaterial = Enum.Material.Air
		updateVoxelInspectDisplay()
	end)
	unlockBtn.LayoutOrder = 10

	panels["voxelInspectPanel"] = voxelInspectPanel

	-- ========================================================================
	-- Component Analyzer Panel (Analysis Tool)
	-- ========================================================================
	local componentAnalyzerPanel = UIHelpers.createConfigPanel(deps.configContainer, "componentAnalyzerPanel")

	local compHeader = UIHelpers.createHeader(componentAnalyzerPanel, "🏝️ Island Analyzer", UDim2.new(0, 0, 0, 0))
	compHeader.LayoutOrder = 1

	local compDesc =
		UIHelpers.createDescription(componentAnalyzerPanel, "Finds disconnected terrain regions. Can take a while on large maps.", 32)
	compDesc.LayoutOrder = 2

	-- Status row
	local compStatusLabel = UIHelpers.createStatusLabel(componentAnalyzerPanel, "Ready to scan", Theme.Colors.Text)
	compStatusLabel.Name = "ComponentStatus"
	compStatusLabel.LayoutOrder = 3

	-- Progress section
	local progressSection = Instance.new("Frame")
	progressSection.Name = "ProgressSection"
	progressSection.BackgroundTransparency = 1
	progressSection.Size = UDim2.new(1, 0, 0, 50)
	progressSection.LayoutOrder = 4
	progressSection.Visible = false -- Hidden until scan starts
	progressSection.Parent = componentAnalyzerPanel

	local progressSectionLayout = Instance.new("UIListLayout")
	progressSectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	progressSectionLayout.Padding = UDim.new(0, 4)
	progressSectionLayout.Parent = progressSection

	-- Progress info text
	local progressInfo = Instance.new("TextLabel")
	progressInfo.Name = "ProgressInfo"
	progressInfo.BackgroundTransparency = 1
	progressInfo.Size = UDim2.new(1, 0, 0, 18)
	progressInfo.Font = Theme.Fonts.Medium
	progressInfo.TextSize = Theme.Sizes.TextNormal
	progressInfo.TextColor3 = Theme.Colors.Text
	progressInfo.TextXAlignment = Enum.TextXAlignment.Left
	progressInfo.Text = "Scanning: 0% | Islands found: 0"
	progressInfo.LayoutOrder = 1
	progressInfo.Parent = progressSection

	-- Progress bar container
	local progressBarBg = Instance.new("Frame")
	progressBarBg.Name = "ProgressBarBg"
	progressBarBg.BackgroundColor3 = Theme.Colors.SliderTrack
	progressBarBg.BorderSizePixel = 0
	progressBarBg.Size = UDim2.new(0, 200, 0, 12)
	progressBarBg.LayoutOrder = 2
	progressBarBg.Parent = progressSection

	local progressBarCorner = Instance.new("UICorner")
	progressBarCorner.CornerRadius = UDim.new(0, 6)
	progressBarCorner.Parent = progressBarBg

	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.BackgroundColor3 = Theme.Colors.Accent
	progressBar.BorderSizePixel = 0
	progressBar.Size = UDim2.new(0, 0, 1, 0)
	progressBar.Parent = progressBarBg

	local progressBarFillCorner = Instance.new("UICorner")
	progressBarFillCorner.CornerRadius = UDim.new(0, 6)
	progressBarFillCorner.Parent = progressBar

	-- Results container (will be populated after scan)
	local compResultsContainer = Instance.new("ScrollingFrame")
	compResultsContainer.Name = "ResultsContainer"
	compResultsContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	compResultsContainer.BorderSizePixel = 0
	compResultsContainer.Size = UDim2.new(1, 0, 0, 120)
	compResultsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	compResultsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	compResultsContainer.ScrollBarThickness = 6
	compResultsContainer.LayoutOrder = 5
	compResultsContainer.Visible = false -- Hidden until results
	compResultsContainer.Parent = componentAnalyzerPanel

	local resultsCorner = Instance.new("UICorner")
	resultsCorner.CornerRadius = UDim.new(0, 4)
	resultsCorner.Parent = compResultsContainer

	local resultsPadding = Instance.new("UIPadding")
	resultsPadding.PaddingLeft = UDim.new(0, 6)
	resultsPadding.PaddingRight = UDim.new(0, 6)
	resultsPadding.PaddingTop = UDim.new(0, 6)
	resultsPadding.PaddingBottom = UDim.new(0, 6)
	resultsPadding.Parent = compResultsContainer

	local compResultsLayout = Instance.new("UIListLayout")
	compResultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	compResultsLayout.Padding = UDim.new(0, 4)
	compResultsLayout.Parent = compResultsContainer

	-- Buttons row
	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "ButtonRow"
	buttonRow.BackgroundTransparency = 1
	buttonRow.Size = UDim2.new(1, 0, 0, 30)
	buttonRow.LayoutOrder = 6
	buttonRow.Parent = componentAnalyzerPanel

	local buttonRowLayout = Instance.new("UIListLayout")
	buttonRowLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonRowLayout.Padding = UDim.new(0, 8)
	buttonRowLayout.Parent = buttonRow

	-- Scan button
	local scanBtn = UIHelpers.createActionButton(buttonRow, "🔍 Scan", function()
		compStatusLabel.Text = "Starting scan..."
		compStatusLabel.TextColor3 = Theme.Colors.Warning
		progressSection.Visible = true
		progressBar.Size = UDim2.new(0, 0, 1, 0)
		progressInfo.Text = "Scanning: 0% | Islands found: 0"
		-- Clear previous results
		for _, child in ipairs(compResultsContainer:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextButton") then
				child:Destroy()
			end
		end
		compResultsContainer.Visible = false
		S.componentScanCancelled = false
		if S.startComponentScan then
			S.startComponentScan()
		end
	end)

	-- Cancel button
	local cancelBtn = UIHelpers.createActionButton(buttonRow, "⏹ Cancel", function()
		S.componentScanCancelled = true
		compStatusLabel.Text = "Scan cancelled (showing partial results)"
		compStatusLabel.TextColor3 = Theme.Colors.Warning
	end)

	-- Store references
	S.componentAnalyzerUI = {
		statusLabel = compStatusLabel,
		resultsContainer = compResultsContainer,
		progressSection = progressSection,
		progressBar = progressBar,
		progressInfo = progressInfo,
	}

	-- Function to update progress (called from scan algorithm)
	S.updateComponentProgress = function(percent: number, islandsFound: number)
		if S.componentAnalyzerUI then
			local ui = S.componentAnalyzerUI
			ui.progressBar.Size = UDim2.new(percent / 100, 0, 1, 0)
			ui.progressInfo.Text = string.format("Scanning: %d%% | Islands found: %d", math.floor(percent), islandsFound)
		end
	end

	-- Function to display results
	S.displayComponentResults = function(islands: { { center: Vector3, size: number, material: string } })
		local ui = S.componentAnalyzerUI
		if not ui then
			return
		end

		ui.progressSection.Visible = false
		ui.resultsContainer.Visible = true
		ui.statusLabel.Text = string.format("Found %d island(s)", #islands)
		ui.statusLabel.TextColor3 = Theme.Colors.Success

		-- Clear old results
		for _, child in ipairs(ui.resultsContainer:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextButton") then
				child:Destroy()
			end
		end

		-- Add result items
		for i, island in ipairs(islands) do
			local sizeLabel = island.size > 10000 and "Large" or (island.size > 1000 and "Medium" or "Small")

			local resultItem = Instance.new("TextButton")
			resultItem.Name = "Island" .. i
			resultItem.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
			resultItem.BorderSizePixel = 0
			resultItem.Size = UDim2.new(1, 0, 0, 28)
			resultItem.Font = Theme.Fonts.Medium
			resultItem.TextSize = Theme.Sizes.TextNormal
			resultItem.TextColor3 = Theme.Colors.Text
			resultItem.TextXAlignment = Enum.TextXAlignment.Left
			resultItem.Text = string.format("  #%d: %s (%s)", i, sizeLabel, island.material)
			resultItem.LayoutOrder = i
			resultItem.AutoButtonColor = true
			resultItem.Parent = ui.resultsContainer

			local itemCorner = Instance.new("UICorner")
			itemCorner.CornerRadius = UDim.new(0, 4)
			itemCorner.Parent = resultItem

			-- Zoom to button
			local zoomBtn = Instance.new("TextButton")
			zoomBtn.BackgroundColor3 = Theme.Colors.Accent
			zoomBtn.BorderSizePixel = 0
			zoomBtn.Position = UDim2.new(1, -60, 0, 4)
			zoomBtn.Size = UDim2.new(0, 55, 0, 20)
			zoomBtn.Font = Theme.Fonts.Medium
			zoomBtn.TextSize = 11
			zoomBtn.TextColor3 = Theme.Colors.Text
			zoomBtn.Text = "Zoom"
			zoomBtn.Parent = resultItem

			local zoomCorner = Instance.new("UICorner")
			zoomCorner.CornerRadius = UDim.new(0, 3)
			zoomCorner.Parent = zoomBtn

			zoomBtn.MouseButton1Click:Connect(function()
				-- Move camera to island center
				local camera = workspace.CurrentCamera
				if camera and island.center then
					camera.CFrame = CFrame.new(island.center + Vector3.new(0, 50, 50), island.center)
				end
			end)
		end

		if #islands == 0 then
			local noResults = Instance.new("TextLabel")
			noResults.BackgroundTransparency = 1
			noResults.Size = UDim2.new(1, 0, 0, 30)
			noResults.Font = Theme.Fonts.Default
			noResults.TextSize = Theme.Sizes.TextNormal
			noResults.TextColor3 = Theme.Colors.TextDim
			noResults.Text = "No terrain found"
			noResults.Parent = ui.resultsContainer
		end
	end

	S.componentScanCancelled = false

	panels["componentAnalyzerPanel"] = componentAnalyzerPanel

	-- ========================================================================
	-- Occupancy Overlay Panel (Analysis Tool)
	-- ========================================================================
	local occupancyOverlayPanel = UIHelpers.createConfigPanel(deps.configContainer, "occupancyOverlayPanel")

	local overlayHeader = UIHelpers.createHeader(occupancyOverlayPanel, "📊 Occupancy Overlay", UDim2.new(0, 0, 0, 0))
	overlayHeader.LayoutOrder = 1

	local overlayDesc = UIHelpers.createDescription(occupancyOverlayPanel, "Visualizes voxel occupancy on terrain surface.", 28)
	overlayDesc.LayoutOrder = 2

	local overlayStatusLabel = UIHelpers.createStatusLabel(occupancyOverlayPanel, "Overlay: OFF", Theme.Colors.TextDim)
	overlayStatusLabel.Name = "OverlayStatus"
	overlayStatusLabel.LayoutOrder = 3

	S.occupancyOverlayEnabled = false

	local toggleOverlayBtn = UIHelpers.createActionButton(occupancyOverlayPanel, "Toggle Overlay", function()
		S.occupancyOverlayEnabled = not S.occupancyOverlayEnabled
		if S.occupancyOverlayEnabled then
			overlayStatusLabel.Text = "Overlay: ON"
			overlayStatusLabel.TextColor3 = Theme.Colors.Success
			if S.updateOccupancyOverlay then
				S.updateOccupancyOverlay()
			end
		else
			overlayStatusLabel.Text = "Overlay: OFF"
			overlayStatusLabel.TextColor3 = Theme.Colors.TextDim
			if S.clearOccupancyOverlay then
				S.clearOccupancyOverlay()
			end
		end
	end)
	toggleOverlayBtn.LayoutOrder = 4

	local _, overlayRangeContainer, _ = UIHelpers.createSlider(occupancyOverlayPanel, "Range", 10, 100, 30, function(v)
		S.occupancyOverlayRange = v
		if S.occupancyOverlayEnabled and S.updateOccupancyOverlay then
			S.updateOccupancyOverlay()
		end
	end)
	overlayRangeContainer.LayoutOrder = 5

	S.occupancyOverlayRange = 30
	S.occupancyOverlayUI = {
		statusLabel = overlayStatusLabel,
	}

	panels["occupancyOverlayPanel"] = occupancyOverlayPanel

	return {
		panels = panels,
		updateGradientStatus = updateGradientStatus,
	}
end

return AdvancedPanels
