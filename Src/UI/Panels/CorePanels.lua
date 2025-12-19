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
	onBrushShapeChanged: (() -> ())?, -- Optional callback when brush shape changes
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
-- These cards must stay readable: fixed-height, flexible-width, and no tiny scaled text.
local MINI_CARD_HEIGHT = 150
local MINI_CARD_TITLE_HEIGHT = 16
local MINI_CARD_BUTTON_HEIGHT = 28
local MINI_CARD_CARD_PADDING = 4
local MINI_CARD_GAP = 3
local MINI_CARD_CELL_PADDING = 3

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
	-- Size is controlled by the parent UIGridLayout; keep this fixed-height and non-auto to avoid wasted space.
	card.Size = UDim2.new(0, 0, 0, MINI_CARD_HEIGHT)
	card.AutomaticSize = Enum.AutomaticSize.None
	card.LayoutOrder = layoutOrder
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 6)
	cardCorner.Parent = card

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, MINI_CARD_CARD_PADDING)
	cardPadding.PaddingBottom = UDim.new(0, MINI_CARD_CARD_PADDING)
	cardPadding.PaddingLeft = UDim.new(0, MINI_CARD_CARD_PADDING)
	cardPadding.PaddingRight = UDim.new(0, MINI_CARD_CARD_PADDING)
	cardPadding.Parent = card

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Padding = UDim.new(0, MINI_CARD_GAP)
	cardLayout.Parent = card

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, MINI_CARD_TITLE_HEIGHT)
	titleLabel.Font = Theme.Fonts.Bold
	titleLabel.TextSize = Theme.Sizes.TextNormal
	titleLabel.TextColor3 = Theme.Colors.Text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextScaled = false
	titleLabel.Text = title
	titleLabel.LayoutOrder = 1
	titleLabel.Parent = card

	-- Button grid container
	local buttonGrid = Instance.new("Frame")
	buttonGrid.Name = "ButtonGrid"
	buttonGrid.BackgroundTransparency = 1
	buttonGrid.Size = UDim2.new(1, 0, 1, -(MINI_CARD_TITLE_HEIGHT + MINI_CARD_GAP))
	buttonGrid.AutomaticSize = Enum.AutomaticSize.None
	buttonGrid.LayoutOrder = 2
	buttonGrid.Parent = card

	-- Choose columns based on option count to keep the card compact without shrinking text.
	-- 2 columns for small sets; 3 columns for larger sets like Spin.
	local columns = (#options > 6) and 3 or 2

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(1 / columns, -(MINI_CARD_CELL_PADDING * 2), 0, MINI_CARD_BUTTON_HEIGHT)
	gridLayout.CellPadding = UDim2.new(0, MINI_CARD_CELL_PADDING, 0, MINI_CARD_CELL_PADDING)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = buttonGrid

	local buttons: { [string]: TextButton } = {}
	local currentValue = initialValue

	local function updateVisuals()
		for id, btn in pairs(buttons) do
			local isSelected = (id == currentValue)
			btn:SetAttribute("IsSelected", isSelected)
			btn.BackgroundColor3 = isSelected and Theme.Colors.ButtonSelected or Theme.Colors.ButtonDefault
		end
	end

	for i, opt in ipairs(options) do
		local btn = Instance.new("TextButton")
		btn.Name = opt.id
		btn.BackgroundColor3 = Theme.Colors.ButtonDefault
		btn.BorderSizePixel = 0
		btn.Font = Theme.Fonts.Medium
		btn.TextSize = Theme.Sizes.TextButton
		btn.TextColor3 = Theme.Colors.Text
		btn.TextScaled = false
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn.TextWrapped = true
		btn.TextXAlignment = Enum.TextXAlignment.Center
		btn.TextYAlignment = Enum.TextYAlignment.Center
		btn.Text = opt.name
		btn.LayoutOrder = i
		btn:SetAttribute("UnselectedColor", Theme.Colors.ButtonDefault)
		btn:SetAttribute("SelectedColor", Theme.Colors.ButtonSelected)
		btn:SetAttribute("IsSelected", false)
		UIHelpers.installStrongHover(btn)
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
	labelText.TextSize = Theme.Sizes.TextNormal
	labelText.TextColor3 = Theme.Colors.Text
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.TextScaled = false
	labelText.Text = label .. " "
	labelText.Parent = labelRow

	local valueText = Instance.new("TextLabel")
	valueText.Name = "Value"
	valueText.BackgroundTransparency = 1
	valueText.Position = UDim2.new(0, 0, 0, 0)
	valueText.Size = UDim2.new(0, 50, 1, 0)
	valueText.Font = Theme.Fonts.Bold
	valueText.TextSize = Theme.Sizes.TextNormal
	valueText.TextColor3 = Theme.Colors.Accent
	valueText.TextXAlignment = Enum.TextXAlignment.Left
	valueText.TextScaled = false
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
	-- Give breathing room from panel edges
	sliderBg.Position = UDim2.new(0, 8, 0, 20)
	sliderBg.Size = UDim2.new(1, -16, 0, 14)
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
	shapeHeader.TextSize = Theme.Sizes.TextNormal
	shapeHeader.TextColor3 = Color3.new(1, 1, 1)
	shapeHeader.TextXAlignment = Enum.TextXAlignment.Left
	shapeHeader.TextScaled = false
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
	-- Make room for readable labels (no tiny scaled text)
	shapeGrid.CellSize = UDim2.new(0, 64, 0, 70)
	shapeGrid.CellPadding = UDim2.new(0, 4, 0, 4)
	shapeGrid.FillDirection = Enum.FillDirection.Horizontal
	shapeGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	shapeGrid.SortOrder = Enum.SortOrder.LayoutOrder
	shapeGrid.Parent = shapeButtonsContainer

	local shapeButtons: { [string]: TextButton } = {}
	local function updateShapeVisuals()
		for id, btn in pairs(shapeButtons) do
			local isSelected = (id == S.brushShape)
			btn:SetAttribute("IsSelected", isSelected)
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
		btn.Size = UDim2.new(0, 64, 0, 70)
		btn.BackgroundColor3 = Theme.Colors.ButtonDefault
		btn.BorderSizePixel = 0
		btn.Font = Theme.Fonts.Medium
		btn.TextSize = Theme.Sizes.TextButton
		btn.TextColor3 = Theme.Colors.Text
		btn.TextScaled = false
		btn.Text = "" -- Will position text manually below icon
		btn.LayoutOrder = i
		btn:SetAttribute("UnselectedColor", Theme.Colors.ButtonDefault)
		btn:SetAttribute("SelectedColor", Theme.Colors.ButtonSelected)
		btn:SetAttribute("IsSelected", false)
		UIHelpers.installStrongHover(btn)
		btn.Parent = shapeButtonsContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		-- Icon container
		local iconContainer = Instance.new("Frame")
		iconContainer.Name = "ShapeIcon"
		iconContainer.BackgroundTransparency = 1
		iconContainer.Size = UDim2.new(0, 34, 0, 34)
		iconContainer.Position = UDim2.new(0.5, -17, 0, 6)
		iconContainer.Parent = btn

		-- Create shape icon
		local shapeIcon = UIComponents.createShapeIcon(shape.id, 34)
		shapeIcon.Parent = iconContainer

		-- Label below icon
		local labelBelow = Instance.new("TextLabel")
		labelBelow.Name = "Label"
		labelBelow.BackgroundTransparency = 1
		labelBelow.Size = UDim2.new(1, 0, 0, 18)
		labelBelow.Position = UDim2.new(0, 0, 1, -20)
		labelBelow.Font = Theme.Fonts.Medium
		labelBelow.TextSize = Theme.Sizes.TextNormal
		labelBelow.TextColor3 = Theme.Colors.Text
		labelBelow.TextScaled = false
		labelBelow.TextTruncate = Enum.TextTruncate.AtEnd
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
			if deps.onBrushShapeChanged then
				deps.onBrushShapeChanged()
			end
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
	-- Cards are fixed-height and flexible-width so text never has to shrink.
	local miniCardsGrid = Instance.new("UIGridLayout")
	miniCardsGrid.FillDirectionMaxCells = 2
	miniCardsGrid.CellSize = UDim2.new(0.5, -3, 0, MINI_CARD_HEIGHT)
	miniCardsGrid.CellPadding = UDim2.new(0, 6, 0, 6)
	miniCardsGrid.FillDirection = Enum.FillDirection.Horizontal
	miniCardsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	miniCardsGrid.SortOrder = Enum.SortOrder.LayoutOrder
	miniCardsGrid.Parent = miniCardsContainer

	-- Rate Card
	local rateCard = createMiniCard(miniCardsContainer, "Rate", {
		{ id = "no_repeat", name = "Once" },
		{ id = "on_move_only", name = "Move" },
		{ id = "very_slow", name = "Very\nSlow" },
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
		{ id = FalloffType.Gaussian, name = "Gaussian" },
		{ id = FalloffType.Quadratic, name = "Quadratic" },
		{ id = FalloffType.Sharp, name = "Sharp" },
	}, S.falloffType, function(newFalloff)
		S.falloffType = newFalloff
		if deps.createBrushVisualization and S.brushPart then
			deps.createBrushVisualization()
		end
	end, 3)

	-- Spin Type Card (8 options, compact 2-column layout)
	local spinTypeCard = createMiniCard(miniCardsContainer, "Spin", {
		{ id = SpinMode.Off, name = "Off" },
		{ id = SpinMode.WorldY, name = "World Y" },
		{ id = SpinMode.World3D, name = "World 3D" },
		{ id = SpinMode.ShapeY, name = "Shape Y" },
		{ id = SpinMode.Shape3D, name = "Shape 3D" },
		{ id = SpinMode.Roll, name = "Roll" },
		{ id = SpinMode.Wobble, name = "Wobble" },
		{ id = SpinMode.Spiral, name = "Spiral" },
	}, S.spinMode, function(newSpin)
		S.spinMode = newSpin
	end, 4)

	-- Spin Speed Card (5 levels)
	local spinSpeedCard = createMiniCard(miniCardsContainer, "Speed", {
		{ id = 1, name = "1" },
		{ id = 2, name = "2" },
		{ id = 3, name = "3" },
		{ id = 4, name = "4" },
		{ id = 5, name = "5" },
	}, S.spinSpeed, function(newSpeed)
		S.spinSpeed = newSpeed
	end, 5)

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
	end, 6)

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

		-- Check if shape uses a dedicated panel instead of size sliders
		if shapeDims and shapeDims.noSizeSliders then
			-- Grid shape uses gridShapeSettings panel, no size sliders here
			-- Add a hint label instead
			local hintLabel = Instance.new("TextLabel")
			hintLabel.Name = "SizeHint"
			hintLabel.BackgroundTransparency = 1
			hintLabel.Size = UDim2.new(1, 0, 0, 24)
			hintLabel.Font = Theme.Fonts.Default
			hintLabel.TextSize = Theme.Sizes.TextNormal
			hintLabel.TextColor3 = Theme.Colors.TextDim
			hintLabel.Text = "Use Grid Shape Settings below"
			hintLabel.TextXAlignment = Enum.TextXAlignment.Left
			hintLabel.TextScaled = false
			hintLabel.Parent = sizePanel
			return
		end

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

	local lockHint = Instance.new("TextLabel")
	lockHint.Name = "LockHint"
	lockHint.BackgroundTransparency = 1
	lockHint.Size = UDim2.new(1, 0, 0, 20)
	lockHint.Font = Theme.Fonts.Medium
	lockHint.TextSize = Theme.Sizes.TextNormal
	lockHint.TextColor3 = Theme.Colors.Text
	lockHint.TextXAlignment = Enum.TextXAlignment.Left
	lockHint.TextScaled = false
	lockHint.TextWrapped = true
	lockHint.Text = "Press L to lock brush (shows handles for rotate/resize)"
	lockHint.Parent = lockPanel

	local lockButton = Instance.new("TextButton")
	lockButton.Name = "LockButton"
	lockButton.Size = UDim2.new(1, 0, 0, 32)
	lockButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	lockButton.BorderSizePixel = 0
	lockButton.Font = Theme.Fonts.Bold
	lockButton.TextSize = Theme.Sizes.TextNormal
	lockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	lockButton.TextScaled = false
	lockButton.Text = "🔓 LOCK BRUSH [L]"
	lockButton.Parent = lockPanel
	lockButton:SetAttribute("UnselectedColor", Color3.fromRGB(60, 60, 60))
	lockButton:SetAttribute("SelectedColor", Color3.fromRGB(200, 120, 40))
	lockButton:SetAttribute("IsSelected", false)
	UIHelpers.installStrongHover(lockButton)

	local lockCorner = Instance.new("UICorner")
	lockCorner.CornerRadius = UDim.new(0, 6)
	lockCorner.Parent = lockButton

	local function updateLockButton()
		if S.brushLocked then
			lockButton.Text = "🔒 UNLOCK BRUSH [L]"
			lockButton.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
			lockButton:SetAttribute("IsSelected", true)
		else
			lockButton.Text = "🔓 LOCK BRUSH [L]"
			lockButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			lockButton:SetAttribute("IsSelected", false)
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

	local hollowToggle = UIComponents.createCheckbox({
		parent = hollowPanel,
		label = "Make shape hollow",
		initialState = S.hollowEnabled,
		onChange = function(isHollow)
			S.hollowEnabled = isHollow
			if thicknessContainer then
				thicknessContainer.Visible = isHollow
			end
		end,
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
	tooltipLabel.TextSize = Theme.Sizes.TextNormal
	tooltipLabel.TextColor3 = Theme.Colors.Text
	tooltipLabel.TextWrapped = true
	tooltipLabel.TextXAlignment = Enum.TextXAlignment.Left
	tooltipLabel.TextScaled = false
	tooltipLabel.Text = "Full strength at brush center, falls off with depth. Helps fill holes from front to back."
	tooltipLabel.LayoutOrder = 2
	tooltipLabel.Parent = emphasizeCenterPanel

	panels["emphasizeBrushCenter"] = emphasizeCenterPanel

	-- ========================================================================
	-- Grid Shape Settings Panel - controls for Grid brush shape
	-- ========================================================================
	local BrushShape = TerrainEnums.BrushShape
	local gridShapePanel = UIHelpers.createConfigPanel(deps.configContainer, "gridShapeSettings")

	local gridShapeHeader = UIHelpers.createHeader(gridShapePanel, "Grid Shape Settings", UDim2.new(0, 0, 0, 0))
	gridShapeHeader.LayoutOrder = 1

	-- Cube Size slider
	local _, cubeSizeContainer, _ = UIHelpers.createSlider(gridShapePanel, "Cube Size", 1, 20, S.gridBrushCubeSize, function(v)
		S.gridBrushCubeSize = v
		deps.createBrushVisualization()
	end)
	cubeSizeContainer.LayoutOrder = 2

	-- Count X slider
	local _, countXContainer, _ = UIHelpers.createSlider(gridShapePanel, "Count X", 1, 10, S.gridBrushCountX, function(v)
		S.gridBrushCountX = v
		deps.createBrushVisualization()
	end)
	countXContainer.LayoutOrder = 3

	-- Count Y slider
	local _, countYContainer, _ = UIHelpers.createSlider(gridShapePanel, "Count Y", 1, 10, S.gridBrushCountY, function(v)
		S.gridBrushCountY = v
		deps.createBrushVisualization()
	end)
	countYContainer.LayoutOrder = 4

	-- Count Z slider
	local _, countZContainer, _ = UIHelpers.createSlider(gridShapePanel, "Count Z", 1, 10, S.gridBrushCountZ, function(v)
		S.gridBrushCountZ = v
		deps.createBrushVisualization()
	end)
	countZContainer.LayoutOrder = 5

	panels["gridShapeSettings"] = gridShapePanel

	return {
		panels = panels,
		setStrengthValue = setStrengthValue,
		rebuildSizeSliders = rebuildSizeSliders,
		updateLockButton = updateLockButton,
	}
end

return CorePanels
