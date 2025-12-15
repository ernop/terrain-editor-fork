--!strict
-- CorePanels.lua - Core brush setting panels shared by most tools
-- Panels: Shape, Strength, BrushRate, Pivot, Hollow, Spin, PlaneLock, FlattenMode

local Theme = require(script.Parent.Parent.Parent.Util.Theme)
local UIHelpers = require(script.Parent.Parent.Parent.Util.UIHelpers)
local UIComponents = require(script.Parent.Parent.Parent.Util.UIComponents)
local BrushData = require(script.Parent.Parent.Parent.Util.BrushData)
local TerrainEnums = require(script.Parent.Parent.Parent.Util.TerrainEnums)

local PivotType = TerrainEnums.PivotType
local FlattenMode = TerrainEnums.FlattenMode
local PlaneLockType = TerrainEnums.PlaneLockType
local SpinMode = TerrainEnums.SpinMode
local FalloffType = TerrainEnums.FalloffType

local Constants = require(script.Parent.Parent.Parent.Util.Constants)

local CorePanels = {}

-- Consistent label width for alignment across all panels
local LABEL_WIDTH = 80

export type CorePanelsDeps = {
	configContainer: Frame,
	S: any, -- State table
	createBrushVisualization: () -> (),
	hidePlaneVisualization: () -> (),
	getTerrainHitRaw: () -> Vector3?,
	toggleBrushLock: (() -> ())?, -- Optional callback to toggle brush lock
}

export type CorePanelsResult = {
	panels: { [string]: Frame },
	setStrengthValue: (value: number) -> (),
	rebuildSizeSliders: () -> (),
	updateLockButton: () -> (), -- Update lock button visual state
}

-- Helper to create a bold white inline label
local function createInlineLabel(parent: Frame, text: string, layoutOrder: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "InlineLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, LABEL_WIDTH, 0, 22)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.LayoutOrder = layoutOrder
	label.Parent = parent
	return label
end

function CorePanels.create(deps: CorePanelsDeps): CorePanelsResult
	local panels: { [string]: Frame } = {}
	local S = deps.S

	-- ========================================================================
	-- Shape Panel - grid of shapes with visual icons
	-- ========================================================================
	local shapePanel = UIHelpers.createConfigPanel(deps.configContainer, "brushShape")

	-- Header label
	local shapeHeader = Instance.new("TextLabel")
	shapeHeader.Name = "ShapeHeader"
	shapeHeader.BackgroundTransparency = 1
	shapeHeader.Size = UDim2.new(1, 0, 0, 20)
	shapeHeader.Font = Enum.Font.GothamBold
	shapeHeader.TextSize = 13
	shapeHeader.TextColor3 = Color3.new(1, 1, 1)
	shapeHeader.TextXAlignment = Enum.TextXAlignment.Left
	shapeHeader.Text = "Shape"
	shapeHeader.LayoutOrder = 1
	shapeHeader.Parent = shapePanel

	local shapeButtonsContainer = Instance.new("Frame")
	shapeButtonsContainer.Name = "ShapeButtons"
	shapeButtonsContainer.BackgroundTransparency = 1
	shapeButtonsContainer.Size = UDim2.new(1, 0, 0, 0)
	shapeButtonsContainer.AutomaticSize = Enum.AutomaticSize.Y
	shapeButtonsContainer.LayoutOrder = 2
	shapeButtonsContainer.Parent = shapePanel

	local shapeGrid = Instance.new("UIGridLayout")
	shapeGrid.CellSize = UDim2.new(0, 50, 0, 52) -- Taller cells for icon + label
	shapeGrid.CellPadding = UDim2.new(0, 4, 0, 4)
	shapeGrid.FillDirection = Enum.FillDirection.Horizontal
	shapeGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	shapeGrid.SortOrder = Enum.SortOrder.LayoutOrder
	shapeGrid.Parent = shapeButtonsContainer

	local shapeButtons: { [string]: TextButton } = {}
	local function updateShapeVisuals()
		for id, btn in pairs(shapeButtons) do
			local isSelected = (id == S.brushShape)
			btn.BackgroundColor3 = isSelected and Theme.Colors.ButtonSelected or Theme.Colors.ButtonDefault
			-- Update icon color based on selection
			local icon = btn:FindFirstChild("ShapeIcon")
			if icon then
				for _, child in ipairs(icon:GetDescendants()) do
					if child:IsA("Frame") and child.BackgroundColor3 ~= Color3.fromRGB(50, 50, 50) then
						-- Don't change "hole" colors, only shape colors
						if child.BackgroundColor3 == Color3.fromRGB(100, 115, 130) then
							-- Dim color stays relative
							child.BackgroundColor3 = isSelected and Color3.fromRGB(140, 160, 180) or Color3.fromRGB(100, 115, 130)
						else
							child.BackgroundColor3 = isSelected and Color3.fromRGB(220, 235, 255) or Color3.fromRGB(180, 200, 220)
						end
					end
				end
			end
		end
	end

	-- Forward declaration (defined in Size Panel section below)
	local rebuildSizeSliders: () -> ()

	for i, shape in ipairs(BrushData.Shapes) do
		local btn = Instance.new("TextButton")
		btn.Name = shape.id
		btn.Size = UDim2.new(0, 50, 0, 52)
		btn.BackgroundColor3 = Theme.Colors.ButtonDefault
		btn.BorderSizePixel = 0
		btn.Text = "" -- No text on button itself
		btn.LayoutOrder = i
		btn.AutoButtonColor = true
		btn.Parent = shapeButtonsContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = btn

		-- Add shape icon
		local icon = UIComponents.createShapeIcon(shape.id, 26)
		icon.Position = UDim2.new(0.5, 0, 0, 15)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Parent = btn

		-- Add label below icon
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0, 0, 1, -14)
		label.Size = UDim2.new(1, 0, 0, 14)
		label.Font = Theme.Fonts.Medium
		label.TextSize = 9
		label.TextColor3 = Theme.Colors.Text
		label.Text = shape.name
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Parent = btn

		shapeButtons[shape.id] = btn
		btn.MouseButton1Click:Connect(function()
			S.brushShape = shape.id
			updateShapeVisuals()
			rebuildSizeSliders()
			if S.brushPart then
				deps.createBrushVisualization()
			end
		end)
	end
	updateShapeVisuals()

	panels["brushShape"] = shapePanel

	-- ========================================================================
	-- Size Panel - inline label with dynamic sliders
	-- ========================================================================
	local sizePanel = UIHelpers.createConfigPanel(deps.configContainer, "size")

	local sizeSliderSetters: { [string]: (number) -> () } = {}

	rebuildSizeSliders = function()
		-- Clear existing content
		for _, child in ipairs(sizePanel:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		sizeSliderSetters = {}

		local shapeDims = BrushData.ShapeDimensions[S.brushShape]
		if not shapeDims then
			-- Fallback: single uniform slider
			local _, _, setter = UIHelpers.createSlider(sizePanel, "Size", Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE, S.brushSizeX, function(val)
				S.brushSizeX = val
				S.brushSizeY = val
				S.brushSizeZ = val
			end)
			sizeSliderSetters["uniform"] = setter
			return
		end

		-- Create a slider for each axis
		for i, axis in ipairs(shapeDims.axes) do
			local currentVal = S.brushSizeX
			if axis.maps[1] == "y" then
				currentVal = S.brushSizeY
			elseif axis.maps[1] == "z" then
				currentVal = S.brushSizeZ
			end

			local _, sliderFrame, setter = UIHelpers.createSlider(sizePanel, axis.label, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE, currentVal, function(val)
				for _, axisName in ipairs(axis.maps) do
					if axisName == "x" then
						S.brushSizeX = val
					elseif axisName == "y" then
						S.brushSizeY = val
					elseif axisName == "z" then
						S.brushSizeZ = val
					end
				end
			end)
			sliderFrame.LayoutOrder = i
			sizeSliderSetters[axis.label] = setter
		end
	end
	rebuildSizeSliders()

	panels["size"] = sizePanel

	-- ========================================================================
	-- Brush Lock Panel
	-- ========================================================================
	local lockPanel = UIHelpers.createConfigPanel(deps.configContainer, "brushLock")

	local lockButton = Instance.new("TextButton")
	lockButton.Name = "LockButton"
	lockButton.Size = UDim2.new(1, 0, 0, 32)
	lockButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	lockButton.BorderSizePixel = 0
	lockButton.Font = Theme.Fonts.Bold
	lockButton.TextSize = 12
	lockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	lockButton.Text = "🔓 LOCK BRUSH [L]"
	lockButton.Parent = lockPanel

	local lockCorner = Instance.new("UICorner")
	lockCorner.CornerRadius = UDim.new(0, 6)
	lockCorner.Parent = lockButton

	local function updateLockButton()
		if S.brushLocked then
			lockButton.Text = "🔒 LOCKED — DRAG HANDLES [L]"
			lockButton.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
		else
			lockButton.Text = "🔓 LOCK BRUSH [L]"
			lockButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		end
	end

	lockButton.MouseButton1Click:Connect(function()
		if deps.toggleBrushLock then
			deps.toggleBrushLock()
			updateLockButton()
		end
	end)
	updateLockButton()

	panels["brushLock"] = lockPanel

	-- ========================================================================
	-- Strength Panel - inline label with slider
	-- ========================================================================
	local strengthPanel = UIHelpers.createConfigPanel(deps.configContainer, "strength")

	local _, strengthSliderContainer, setStrengthValue = UIHelpers.createSlider(
		strengthPanel,
		"Strength",
		1,
		100,
		math.floor(S.brushStrength * 100),
		function(value)
			S.brushStrength = value / 100
		end
	)

	panels["strength"] = strengthPanel

	-- ========================================================================
	-- Brush Rate Panel - inline label with button grid
	-- ========================================================================
	local brushRatePanel = UIHelpers.createConfigPanel(deps.configContainer, "brushRate")

	local rateRow = Instance.new("Frame")
	rateRow.Name = "RateRow"
	rateRow.BackgroundTransparency = 1
	rateRow.Size = UDim2.new(1, 0, 0, 0)
	rateRow.AutomaticSize = Enum.AutomaticSize.Y
	rateRow.Parent = brushRatePanel

	createInlineLabel(rateRow, "Rate", 1)

	local rateButtonsContainer = Instance.new("Frame")
	rateButtonsContainer.Name = "RateButtons"
	rateButtonsContainer.BackgroundTransparency = 1
	rateButtonsContainer.Position = UDim2.new(0, LABEL_WIDTH, 0, 0)
	rateButtonsContainer.Size = UDim2.new(1, -LABEL_WIDTH, 0, 0)
	rateButtonsContainer.AutomaticSize = Enum.AutomaticSize.Y
	rateButtonsContainer.Parent = rateRow

	local rateGrid = Instance.new("UIGridLayout")
	rateGrid.CellSize = UDim2.new(0, 58, 0, 22)
	rateGrid.CellPadding = UDim2.new(0, 3, 0, 3)
	rateGrid.FillDirection = Enum.FillDirection.Horizontal
	rateGrid.SortOrder = Enum.SortOrder.LayoutOrder
	rateGrid.Parent = rateButtonsContainer

	local rateOptions = {
		{ id = "no_repeat", name = "No repeat" },
		{ id = "on_move_only", name = "On move" },
		{ id = "very_slow", name = "Very slow" },
		{ id = "slow", name = "Slow" },
		{ id = "normal", name = "Normal" },
		{ id = "fast", name = "Fast" },
	}

	local rateButtons: { [string]: TextButton } = {}
	local function updateRateVisuals()
		for id, btn in pairs(rateButtons) do
			btn.BackgroundColor3 = (id == S.brushRate) and Theme.Colors.ButtonSelected or Theme.Colors.ButtonDefault
		end
	end

	for i, opt in ipairs(rateOptions) do
		local btn = Instance.new("TextButton")
		btn.Name = opt.id
		btn.Size = UDim2.new(0, 58, 0, 22)
		btn.BackgroundColor3 = Theme.Colors.ButtonDefault
		btn.BorderSizePixel = 0
		btn.Font = Theme.Fonts.Medium
		btn.TextSize = 10
		btn.TextColor3 = Theme.Colors.Text
		btn.Text = opt.name
		btn.LayoutOrder = i
		btn.AutoButtonColor = true
		btn.Parent = rateButtonsContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		rateButtons[opt.id] = btn
		btn.MouseButton1Click:Connect(function()
			S.brushRate = opt.id
			updateRateVisuals()
		end)
	end
	updateRateVisuals()

	panels["brushRate"] = brushRatePanel

	-- ========================================================================
	-- Pivot Panel - inline
	-- ========================================================================
	local pivotPanel = UIHelpers.createConfigPanel(deps.configContainer, "pivot")

	local pivotGroup = UIComponents.createLabeledButtonGroup({
		parent = pivotPanel,
		label = "Pivot",
		options = {
			{ id = PivotType.Bottom, name = "Bot" },
			{ id = PivotType.Center, name = "Cen" },
			{ id = PivotType.Top, name = "Top" },
			{ id = PivotType.Surface, name = "Surface" },
		},
		initialValue = S.pivotType,
		onChange = function(newPivot)
			S.pivotType = newPivot
		end,
		labelWidth = LABEL_WIDTH,
		buttonWidth = 48,
	})

	panels["pivot"] = pivotPanel

	-- ========================================================================
	-- Hollow Mode Panel - inline with conditional slider
	-- ========================================================================
	local hollowPanel = UIHelpers.createConfigPanel(deps.configContainer, "hollow")

	local thicknessContainer: Frame

	local hollowToggle = UIComponents.createLabeledToggle({
		parent = hollowPanel,
		label = "Hollow",
		initialState = S.hollowEnabled,
		textOn = "HOLLOW",
		textOff = "Solid",
		onChange = function(isHollow)
			S.hollowEnabled = isHollow
			if thicknessContainer then
				thicknessContainer.Visible = isHollow
			end
		end,
		labelWidth = LABEL_WIDTH,
	})
	hollowToggle.container.LayoutOrder = 1

	local _, thicknessContainerRef, _ = UIHelpers.createSlider(hollowPanel, "Thickness", 10, 50, math.floor(S.wallThickness * 100), function(val)
		S.wallThickness = val / 100
	end)
	thicknessContainer = thicknessContainerRef
	thicknessContainer.LayoutOrder = 2
	thicknessContainer.Visible = S.hollowEnabled

	panels["hollow"] = hollowPanel

	-- ========================================================================
	-- Falloff Curve Panel - inline label with grid + slider
	-- ========================================================================
	local falloffPanel = UIHelpers.createConfigPanel(deps.configContainer, "falloff")

	local falloffRow = Instance.new("Frame")
	falloffRow.Name = "FalloffRow"
	falloffRow.BackgroundTransparency = 1
	falloffRow.Size = UDim2.new(1, 0, 0, 0)
	falloffRow.AutomaticSize = Enum.AutomaticSize.Y
	falloffRow.LayoutOrder = 1
	falloffRow.Parent = falloffPanel

	createInlineLabel(falloffRow, "Falloff", 1)

	local falloffButtonsContainer = Instance.new("Frame")
	falloffButtonsContainer.Name = "FalloffButtons"
	falloffButtonsContainer.BackgroundTransparency = 1
	falloffButtonsContainer.Position = UDim2.new(0, LABEL_WIDTH, 0, 0)
	falloffButtonsContainer.Size = UDim2.new(1, -LABEL_WIDTH, 0, 0)
	falloffButtonsContainer.AutomaticSize = Enum.AutomaticSize.Y
	falloffButtonsContainer.Parent = falloffRow

	local falloffGrid = Instance.new("UIGridLayout")
	falloffGrid.CellSize = UDim2.new(0, 58, 0, 22)
	falloffGrid.CellPadding = UDim2.new(0, 3, 0, 3)
	falloffGrid.FillDirection = Enum.FillDirection.Horizontal
	falloffGrid.SortOrder = Enum.SortOrder.LayoutOrder
	falloffGrid.Parent = falloffButtonsContainer

	local falloffOptions = {
		{ id = FalloffType.Cosine, name = "Cosine" },
		{ id = FalloffType.Linear, name = "Linear" },
		{ id = FalloffType.Plateau, name = "Plateau" },
		{ id = FalloffType.Gaussian, name = "Gaussian" },
		{ id = FalloffType.Quadratic, name = "Quadratic" },
		{ id = FalloffType.Sharp, name = "Sharp" },
	}

	local falloffButtons: { [string]: TextButton } = {}
	local function updateFalloffVisuals()
		for id, btn in pairs(falloffButtons) do
			btn.BackgroundColor3 = (id == S.falloffType) and Theme.Colors.ButtonSelected or Theme.Colors.ButtonDefault
		end
	end

	for i, opt in ipairs(falloffOptions) do
		local btn = Instance.new("TextButton")
		btn.Name = opt.id
		btn.Size = UDim2.new(0, 58, 0, 22)
		btn.BackgroundColor3 = Theme.Colors.ButtonDefault
		btn.BorderSizePixel = 0
		btn.Font = Theme.Fonts.Medium
		btn.TextSize = 10
		btn.TextColor3 = Theme.Colors.Text
		btn.Text = opt.name
		btn.LayoutOrder = i
		btn.AutoButtonColor = true
		btn.Parent = falloffButtonsContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		falloffButtons[opt.id] = btn
		btn.MouseButton1Click:Connect(function()
			S.falloffType = opt.id
			updateFalloffVisuals()
		end)
	end
	updateFalloffVisuals()

	local _, extentContainer, _ = UIHelpers.createSlider(falloffPanel, "Softness", 0, 100, math.floor(S.falloffExtent * 100), function(val)
		S.falloffExtent = val / 100
		if deps.createBrushVisualization and S.brushPart then
			deps.createBrushVisualization()
		end
	end)
	extentContainer.LayoutOrder = 2

	panels["falloff"] = falloffPanel

	-- ========================================================================
	-- Spin Mode Panel - inline
	-- ========================================================================
	local spinPanel = UIHelpers.createConfigPanel(deps.configContainer, "spin")

	local spinGroup = UIComponents.createLabeledButtonGroup({
		parent = spinPanel,
		label = "Spin",
		options = {
			{ id = SpinMode.Off, name = "Off" },
			-- World-relative modes
			{ id = SpinMode.WorldY, name = "World Y" },
			{ id = SpinMode.WorldYFast, name = "W.Y Fast" },
			{ id = SpinMode.World3D, name = "World 3D" },
			{ id = SpinMode.World3DFast, name = "W.3D Fast" },
			-- Shape-relative modes
			{ id = SpinMode.ShapeY, name = "Shape Y" },
			{ id = SpinMode.Shape3D, name = "Shape 3D" },
			-- Special effects
			{ id = SpinMode.Roll, name = "Roll" },
			{ id = SpinMode.Wobble, name = "Wobble" },
			{ id = SpinMode.Spiral, name = "Spiral" },
		},
		initialValue = S.spinMode,
		onChange = function(newMode)
			S.spinMode = newMode
		end,
		labelWidth = LABEL_WIDTH,
		buttonWidth = 60,
	})

	panels["spin"] = spinPanel

	-- ========================================================================
	-- Plane Lock Panel - inline with conditional controls
	-- ========================================================================
	local planeLockPanel = UIHelpers.createConfigPanel(deps.configContainer, "planeLock")

	local manualControlsContainer = UIHelpers.createAutoContainer(planeLockPanel, "ManualControls")
	manualControlsContainer.LayoutOrder = 2
	manualControlsContainer.Visible = (S.planeLockMode == PlaneLockType.Manual)

	local planeLockGroup = UIComponents.createLabeledButtonGroup({
		parent = planeLockPanel,
		label = "Plane",
		options = {
			{ id = PlaneLockType.Off, name = "Off" },
			{ id = PlaneLockType.Auto, name = "Auto" },
			{ id = PlaneLockType.Manual, name = "Manual" },
		},
		initialValue = S.planeLockMode,
		onChange = function(newMode)
			S.planeLockMode = newMode
			S.autoPlaneActive = false
			manualControlsContainer.Visible = (newMode == PlaneLockType.Manual)
			if newMode == PlaneLockType.Off then
				deps.hidePlaneVisualization()
			end
		end,
		labelWidth = LABEL_WIDTH,
		buttonWidth = 58,
	})
	planeLockGroup.container.LayoutOrder = 1

	local _, planeHeightContainer, setPlaneHeightValue = UIHelpers.createSlider(manualControlsContainer, "Height", -100, 500, S.planePositionY, function(value)
		S.planePositionY = value
	end)
	planeHeightContainer.LayoutOrder = 1

	local setHeightBtn = UIHelpers.createActionButton(manualControlsContainer, "Set from Cursor", function()
		local hitPosition = deps.getTerrainHitRaw()
		if hitPosition then
			S.planePositionY = math.floor(hitPosition.Y + 0.5)
			setPlaneHeightValue(S.planePositionY)
		end
	end)
	setHeightBtn.LayoutOrder = 2

	panels["planeLock"] = planeLockPanel

	-- ========================================================================
	-- Flatten Mode Panel - inline
	-- ========================================================================
	local flattenModePanel = UIHelpers.createConfigPanel(deps.configContainer, "flattenMode")

	local flattenGroup = UIComponents.createLabeledButtonGroup({
		parent = flattenModePanel,
		label = "Flatten",
		options = {
			{ id = FlattenMode.Erode, name = "Erode" },
			{ id = FlattenMode.Both, name = "Both" },
			{ id = FlattenMode.Grow, name = "Grow" },
		},
		initialValue = S.flattenMode,
		onChange = function(newMode)
			S.flattenMode = newMode
		end,
		labelWidth = LABEL_WIDTH,
		buttonWidth = 55,
	})

	panels["flattenMode"] = flattenModePanel

	-- ========================================================================
	-- Emphasize Brush Center Panel - toggle for depth-based falloff
	-- ========================================================================
	local emphasizeCenterPanel = UIHelpers.createConfigPanel(deps.configContainer, "emphasizeBrushCenter")

	local emphasizeCenterToggle = UIComponents.createLabeledToggle({
		parent = emphasizeCenterPanel,
		label = "Center",
		initialState = S.emphasizeBrushCenter,
		textOn = "Emphasize",
		textOff = "Uniform",
		onChange = function(isEnabled)
			S.emphasizeBrushCenter = isEnabled
		end,
		labelWidth = LABEL_WIDTH,
	})

	-- Add tooltip description
	local tooltipLabel = Instance.new("TextLabel")
	tooltipLabel.Name = "Tooltip"
	tooltipLabel.BackgroundTransparency = 1
	tooltipLabel.Size = UDim2.new(1, 0, 0, 28)
	tooltipLabel.Font = Theme.Fonts.Default
	tooltipLabel.TextSize = 10
	tooltipLabel.TextColor3 = Theme.Colors.TextDim
	tooltipLabel.TextWrapped = true
	tooltipLabel.TextXAlignment = Enum.TextXAlignment.Left
	tooltipLabel.Text = "Full strength at brush center, falls off with depth. Helps fill holes from front to back."
	tooltipLabel.LayoutOrder = 2
	tooltipLabel.Parent = emphasizeCenterPanel

	panels["emphasizeBrushCenter"] = emphasizeCenterPanel

	return {
		panels = panels,
		setStrengthValue = setStrengthValue,
		rebuildSizeSliders = rebuildSizeSliders,
		updateLockButton = updateLockButton,
	}
end

return CorePanels
