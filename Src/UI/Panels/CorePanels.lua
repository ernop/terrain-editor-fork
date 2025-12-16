--!strict
-- CorePanels.lua - Core brush setting panels shared by most tools
-- Panels: Shape, MiniCards (Rate/Pivot/Falloff/Spin/Plane), Strength, Size, BrushLock

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

-- ============================================================================
-- Mini Card Helper - creates a small card with title and 2-column button grid
-- ============================================================================
local MINI_CARD_WIDTH = 95
local MINI_CARD_BUTTON_WIDTH = 42
local MINI_CARD_BUTTON_HEIGHT = 20

local function createMiniCard(
	parent: Frame,
	title: string,
	options: { { id: string, name: string } },
	initialValue: string,
	onChange: (string) -> (),
	layoutOrder: number
): { card: Frame, buttons: { [string]: TextButton }, updateVisuals: () -> () }
	local card = Instance.new("Frame")
	card.Name = title .. "Card"
	card.BackgroundColor3 = Color3.fromRGB(35, 38, 42)
	card.BorderSizePixel = 0
	card.Size = UDim2.new(0, MINI_CARD_WIDTH, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = layoutOrder
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 6)
	cardCorner.Parent = card

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, 6)
	cardPadding.PaddingBottom = UDim.new(0, 6)
	cardPadding.PaddingLeft = UDim.new(0, 6)
	cardPadding.PaddingRight = UDim.new(0, 6)
	cardPadding.Parent = card

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Padding = UDim.new(0, 4)
	cardLayout.Parent = card

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 14)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 11
	titleLabel.TextColor3 = Color3.fromRGB(160, 165, 175)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.LayoutOrder = 1
	titleLabel.Parent = card

	-- Button grid container
	local buttonGrid = Instance.new("Frame")
	buttonGrid.Name = "ButtonGrid"
	buttonGrid.BackgroundTransparency = 1
	buttonGrid.Size = UDim2.new(1, 0, 0, 0)
	buttonGrid.AutomaticSize = Enum.AutomaticSize.Y
	buttonGrid.LayoutOrder = 2
	buttonGrid.Parent = card

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, MINI_CARD_BUTTON_WIDTH, 0, MINI_CARD_BUTTON_HEIGHT)
	gridLayout.CellPadding = UDim2.new(0, 2, 0, 2)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = buttonGrid

	local buttons: { [string]: TextButton } = {}
	local currentValue = initialValue

	local function updateVisuals()
		for id, btn in pairs(buttons) do
			btn.BackgroundColor3 = (id == currentValue) and Theme.Colors.ButtonSelected or Theme.Colors.ButtonDefault
		end
	end

	for i, opt in ipairs(options) do
		local btn = Instance.new("TextButton")
		btn.Name = opt.id
		btn.BackgroundColor3 = Theme.Colors.ButtonDefault
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 9
		btn.TextColor3 = Theme.Colors.Text
		btn.TextScaled = true
		btn.Text = opt.name
		btn.LayoutOrder = i
		btn.AutoButtonColor = true
		btn.Parent = buttonGrid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 3)
		corner.Parent = btn

		buttons[opt.id] = btn
		btn.MouseButton1Click:Connect(function()
			currentValue = opt.id
			onChange(opt.id)
			updateVisuals()
		end)
	end
	updateVisuals()

	return {
		card = card,
		buttons = buttons,
		updateVisuals = updateVisuals,
	}
end

-- ============================================================================
-- Inline Slider with value next to label (e.g., "Size 135")
-- ============================================================================
local function createInlineSlider(
	parent: Frame,
	label: string,
	min: number,
	max: number,
	initial: number,
	callback: (number) -> ()
): (Frame, (number) -> ())
	local currentValue = initial
	local UserInputService = game:GetService("UserInputService")

	local container = Instance.new("Frame")
	container.Name = label .. "Slider"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 38)
	container.Parent = parent

	-- Label with value inline: "Size 135"
	local labelRow = Instance.new("Frame")
	labelRow.Name = "LabelRow"
	labelRow.BackgroundTransparency = 1
	labelRow.Size = UDim2.new(1, 0, 0, 16)
	labelRow.Parent = container

	local labelText = Instance.new("TextLabel")
	labelText.Name = "Label"
	labelText.BackgroundTransparency = 1
	labelText.Size = UDim2.new(0, 0, 1, 0)
	labelText.AutomaticSize = Enum.AutomaticSize.X
	labelText.Font = Theme.Fonts.Medium
	labelText.TextSize = 12
	labelText.TextColor3 = Theme.Colors.Text
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.TextScaled = true
	labelText.Text = label .. " "
	labelText.Parent = labelRow

	local valueText = Instance.new("TextLabel")
	valueText.Name = "Value"
	valueText.BackgroundTransparency = 1
	valueText.Position = UDim2.new(0, 0, 0, 0)
	valueText.Size = UDim2.new(0, 50, 1, 0)
	valueText.Font = Theme.Fonts.Bold
	valueText.TextSize = 12
	valueText.TextColor3 = Theme.Colors.Accent
	valueText.TextXAlignment = Enum.TextXAlignment.Left
	valueText.TextScaled = true
	valueText.Text = tostring(initial)
	valueText.Parent = labelRow

	-- Layout to position value after label
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Parent = labelRow

	-- Slider track
	local sliderBg = Instance.new("Frame")
	sliderBg.Name = "SliderTrack"
	sliderBg.BackgroundColor3 = Theme.Colors.SliderTrack
	sliderBg.BorderSizePixel = 0
	sliderBg.Position = UDim2.new(0, 0, 0, 20)
	sliderBg.Size = UDim2.new(1, 0, 0, 14)
	sliderBg.Parent = container

	local sliderCorner = Instance.new("UICorner")
	sliderCorner.CornerRadius = UDim.new(0, 7)
	sliderCorner.Parent = sliderBg

	-- Slider fill
	local sliderFill = Instance.new("Frame")
	sliderFill.Name = "Fill"
	sliderFill.BackgroundColor3 = Theme.Colors.SliderFill
	sliderFill.BorderSizePixel = 0
	sliderFill.Size = UDim2.new((initial - min) / (max - min), 0, 1, 0)
	sliderFill.Parent = sliderBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 7)
	fillCorner.Parent = sliderFill

	-- Thumb
	local thumb = Instance.new("Frame")
	thumb.Name = "Thumb"
	thumb.BackgroundColor3 = Theme.Colors.SliderThumb
	thumb.BorderSizePixel = 0
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	thumb.Position = UDim2.new((initial - min) / (max - min), 0, 0.5, 0)
	thumb.Size = UDim2.new(0, 16, 0, 16)
	thumb.ZIndex = 2
	thumb.Parent = sliderBg

	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(1, 0)
	thumbCorner.Parent = thumb

	local thumbStroke = Instance.new("UIStroke")
	thumbStroke.Color = Theme.Colors.SliderThumbStroke
	thumbStroke.Thickness = 2
	thumbStroke.Parent = thumb

	-- Update function
	local function setValue(value: number)
		value = math.clamp(math.floor(value + 0.5), min, max)
		currentValue = value
		local relativeX = (value - min) / (max - min)
		sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
		thumb.Position = UDim2.new(relativeX, 0, 0.5, 0)
		valueText.Text = tostring(value)
		callback(value)
	end

	local function getValueAtPosition(posX: number): number
		local relativeX = math.clamp((posX - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
		return math.floor(min + relativeX * (max - min) + 0.5)
	end

	-- Dragging state
	local isDragging = false

	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = true
			setValue(getValueAtPosition(input.Position.X))
		end
	end)

	sliderBg.InputChanged:Connect(function(input)
		if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			setValue(getValueAtPosition(input.Position.X))
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = false
		end
	end)

	return container, setValue
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
	shapeHeader.TextScaled = true
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
		btn.Font = Theme.Fonts.Medium
		btn.TextSize = 9
		btn.TextColor3 = Theme.Colors.Text
		btn.TextScaled = true
		btn.Text = "" -- Will position text manually below icon
		btn.LayoutOrder = i
		btn.AutoButtonColor = true
		btn.Parent = shapeButtonsContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		-- Icon container
		local iconContainer = Instance.new("Frame")
		iconContainer.Name = "ShapeIcon"
		iconContainer.BackgroundTransparency = 1
		iconContainer.Size = UDim2.new(0, 32, 0, 32)
		iconContainer.Position = UDim2.new(0.5, -16, 0, 3)
		iconContainer.Parent = btn

		-- Create shape icon
		local shapeIcon = UIComponents.createShapeIcon(shape.id, 32)
		shapeIcon.Parent = iconContainer

		-- Label below icon
		local labelBelow = Instance.new("TextLabel")
		labelBelow.Name = "Label"
		labelBelow.BackgroundTransparency = 1
		labelBelow.Size = UDim2.new(1, 0, 0, 14)
		labelBelow.Position = UDim2.new(0, 0, 1, -14)
		labelBelow.Font = Theme.Fonts.Medium
		labelBelow.TextSize = 9
		labelBelow.TextColor3 = Theme.Colors.Text
		labelBelow.TextScaled = true
		labelBelow.Text = shape.name
		labelBelow.Parent = btn

		shapeButtons[shape.id] = btn
		btn.MouseButton1Click:Connect(function()
			S.brushShape = shape.id
			updateShapeVisuals()
			if rebuildSizeSliders then
				rebuildSizeSliders()
			end
			deps.createBrushVisualization()
		end)
	end
	updateShapeVisuals()

	panels["brushShape"] = shapePanel

	-- ========================================================================
	-- Mini Cards Container - floating cards for Rate, Pivot, Falloff, Spin, Plane
	-- ========================================================================
	local miniCardsPanel = UIHelpers.createConfigPanel(deps.configContainer, "miniCards")

	local miniCardsContainer = Instance.new("Frame")
	miniCardsContainer.Name = "MiniCardsFlow"
	miniCardsContainer.BackgroundTransparency = 1
	miniCardsContainer.Size = UDim2.new(1, 0, 0, 0)
	miniCardsContainer.AutomaticSize = Enum.AutomaticSize.Y
	miniCardsContainer.Parent = miniCardsPanel

	-- UIGridLayout with fixed cell height (tallest card is Spin with 5 rows of buttons)
	-- Height = 6 padding top + 14 title + 4 gap + (5 rows * 20px + 4 gaps * 2px) + 6 padding bottom = ~140
	local miniCardsGrid = Instance.new("UIGridLayout")
	miniCardsGrid.CellSize = UDim2.new(0, MINI_CARD_WIDTH, 0, 140)
	miniCardsGrid.CellPadding = UDim2.new(0, 6, 0, 6)
	miniCardsGrid.FillDirection = Enum.FillDirection.Horizontal
	miniCardsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	miniCardsGrid.SortOrder = Enum.SortOrder.LayoutOrder
	miniCardsGrid.Parent = miniCardsContainer

	-- Rate Card
	local rateCard = createMiniCard(miniCardsContainer, "Rate", {
		{ id = "no_repeat", name = "Once" },
		{ id = "on_move_only", name = "Move" },
		{ id = "very_slow", name = "V.Slow" },
		{ id = "slow", name = "Slow" },
		{ id = "normal", name = "Normal" },
		{ id = "fast", name = "Fast" },
	}, S.brushRate, function(newRate)
		S.brushRate = newRate
	end, 1)

	-- Pivot Card
	local pivotCard = createMiniCard(miniCardsContainer, "Pivot", {
		{ id = PivotType.Bottom, name = "Bottom" },
		{ id = PivotType.Center, name = "Center" },
		{ id = PivotType.Top, name = "Top" },
		{ id = PivotType.Surface, name = "Surface" },
	}, S.pivotType, function(newPivot)
		S.pivotType = newPivot
	end, 2)

	-- Falloff Card
	local falloffCard = createMiniCard(miniCardsContainer, "Falloff", {
		{ id = FalloffType.Cosine, name = "Cosine" },
		{ id = FalloffType.Linear, name = "Linear" },
		{ id = FalloffType.Plateau, name = "Plateau" },
		{ id = FalloffType.Gaussian, name = "Gauss" },
		{ id = FalloffType.Quadratic, name = "Quad" },
		{ id = FalloffType.Sharp, name = "Sharp" },
	}, S.falloffType, function(newFalloff)
		S.falloffType = newFalloff
		if deps.createBrushVisualization and S.brushPart then
			deps.createBrushVisualization()
		end
	end, 3)

	-- Spin Card
	local spinCard = createMiniCard(miniCardsContainer, "Spin", {
		{ id = SpinMode.Off, name = "Off" },
		{ id = SpinMode.WorldY, name = "World Y" },
		{ id = SpinMode.WorldYFast, name = "W.Y Fst" },
		{ id = SpinMode.World3D, name = "W. 3D" },
		{ id = SpinMode.World3DFast, name = "W.3D Fst" },
		{ id = SpinMode.ShapeY, name = "Shape Y" },
		{ id = SpinMode.Shape3D, name = "Shp 3D" },
		{ id = SpinMode.Roll, name = "Roll" },
		{ id = SpinMode.Wobble, name = "Wobble" },
		{ id = SpinMode.Spiral, name = "Spiral" },
	}, S.spinMode, function(newSpin)
		S.spinMode = newSpin
	end, 4)

	-- Plane Card
	local planeCard = createMiniCard(miniCardsContainer, "Plane", {
		{ id = PlaneLockType.Off, name = "Off" },
		{ id = PlaneLockType.Auto, name = "Auto" },
		{ id = PlaneLockType.Manual, name = "Manual" },
	}, S.planeLockMode, function(newMode)
		S.planeLockMode = newMode
		S.autoPlaneActive = false
		if newMode == PlaneLockType.Off then
			deps.hidePlaneVisualization()
		end
	end, 5)

	panels["miniCards"] = miniCardsPanel
	-- Map individual panel names for visibility control
	panels["brushRate"] = miniCardsPanel
	panels["pivot"] = miniCardsPanel
	panels["falloff"] = miniCardsPanel
	panels["spin"] = miniCardsPanel
	panels["planeLock"] = miniCardsPanel

	-- ========================================================================
	-- Strength Panel - inline slider with value next to label
	-- ========================================================================
	local strengthPanel = UIHelpers.createConfigPanel(deps.configContainer, "strength")

	local _, setStrengthValue = createInlineSlider(
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
	-- Size Panel - with axis-aware sliders
	-- ========================================================================
	local sizePanel = UIHelpers.createConfigPanel(deps.configContainer, "brushSize")

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
			local _, setter = createInlineSlider(sizePanel, "Size", Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE, S.brushSizeX, function(val)
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

			local sliderFrame, setter = createInlineSlider(sizePanel, axis.label, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE, currentVal, function(val)
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

	panels["brushSize"] = sizePanel

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
	lockButton.TextScaled = true
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
			lockButton.Text = "Hit L to lock brush and adjust its rotation and size"
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
		labelWidth = 80,
	})
	hollowToggle.container.LayoutOrder = 1

	local thicknessSlider, _ = createInlineSlider(hollowPanel, "Thickness", 10, 50, math.floor(S.wallThickness * 100), function(val)
		S.wallThickness = val / 100
	end)
	thicknessContainer = thicknessSlider
	thicknessContainer.LayoutOrder = 2
	thicknessContainer.Visible = S.hollowEnabled

	panels["hollow"] = hollowPanel

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
		labelWidth = 80,
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
		labelWidth = 80,
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
	tooltipLabel.TextScaled = true
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
