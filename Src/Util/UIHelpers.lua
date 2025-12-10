--!strict
-- UI Helper functions for the Terrain Editor
-- Low-level UI element creation using Theme for consistent styling

local Theme = require(script.Parent.Theme)

local UIHelpers = {}

-- ============================================================================
-- Basic Label Creators
-- ============================================================================

function UIHelpers.createLabel(parent: Frame, text: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Theme.Fonts.Default
	label.TextSize = Theme.Sizes.TextMedium
	label.TextColor3 = Theme.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

function UIHelpers.createHeader(parent: Frame, text: string, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Font = Theme.Fonts.Medium
	label.TextSize = Theme.Sizes.TextMedium
	label.TextColor3 = Theme.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

-- NEW: Description text (gray, small, wrapped) - used for panel explanations
function UIHelpers.createDescription(parent: Frame, text: string, height: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height or 28)
	label.Font = Theme.Fonts.Default
	label.TextSize = Theme.Sizes.TextDescription
	label.TextColor3 = Theme.Colors.TextMuted
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

-- NEW: Status label (bold, colored) - used for tool state display
function UIHelpers.createStatusLabel(parent: Frame, text: string, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 24)
	label.Font = Theme.Fonts.Bold
	label.TextSize = Theme.Sizes.TextMedium
	label.TextColor3 = color or Theme.Colors.Warning
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

-- NEW: Note/tip text (very dim, small) - used for hints
function UIHelpers.createNote(parent: Frame, text: string, height: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height or 24)
	label.Font = Theme.Fonts.Default
	label.TextSize = Theme.Sizes.TextSmall
	label.TextColor3 = Theme.Colors.TextNote
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

-- NEW: Instructions text (normal weight, white, wrapped) - used for tool instructions
function UIHelpers.createInstructions(parent: Frame, text: string, height: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Instructions"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height or 50)
	label.Font = Theme.Fonts.Default
	label.TextSize = Theme.Sizes.TextNormal
	label.TextColor3 = Theme.Colors.Text
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = text
	label.Parent = parent
	return label
end

-- ============================================================================
-- Labeled Row Pattern
-- ============================================================================

export type LabeledRowResult = {
	row: Frame,
	label: TextLabel,
}

-- NEW: Create a row with a label on the left and space for content on the right
function UIHelpers.createLabeledRow(parent: Frame, labelText: string, labelWidth: number?): LabeledRowResult
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 24)
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, labelWidth or 80, 1, 0)
	label.Font = Theme.Fonts.Default
	label.TextSize = Theme.Sizes.TextNormal
	label.TextColor3 = Theme.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText
	label.Parent = row

	return {
		row = row,
		label = label,
	}
end

-- ============================================================================
-- Button Creators
-- ============================================================================

function UIHelpers.createButton(parent: Frame, text: string, position: UDim2, size: UDim2, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Theme.Colors.ButtonDefault
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.Font = Theme.Fonts.Medium
	button.TextSize = 13
	button.TextColor3 = Theme.Colors.Text
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Sizes.CornerRadius)
	corner.Parent = button

	button.MouseButton1Click:Connect(callback)
	return button
end

-- NEW: Action button (natural width based on text, secondary color)
function UIHelpers.createActionButton(parent: Frame, text: string, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Theme.Colors.ButtonSecondary
	button.BorderSizePixel = 0
	button.AutomaticSize = Enum.AutomaticSize.X  -- Size to fit text
	button.Size = UDim2.new(0, 0, 0, Theme.Sizes.ButtonHeight)
	button.Font = Theme.Fonts.Medium
	button.TextSize = Theme.Sizes.TextNormal
	button.TextColor3 = Theme.Colors.Text
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent

	-- Padding so text doesn't touch edges
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = button

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Sizes.CornerRadius)
	corner.Parent = button

	button.MouseButton1Click:Connect(callback)
	return button
end

function UIHelpers.createToolButton(parent: Frame, toolId: string, displayName: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = toolId
	button.BackgroundColor3 = Theme.Colors.ButtonDefault
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = UDim2.new(0, Theme.Sizes.ToolButtonWidth, 0, Theme.Sizes.ToolButtonHeight)
	button.Font = Theme.Fonts.Medium
	button.TextSize = Theme.Sizes.TextDescription
	button.TextColor3 = Theme.Colors.Text
	button.Text = displayName
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Sizes.CornerRadius)
	corner.Parent = button

	return button
end

-- ============================================================================
-- Slider (Redesigned: compact, hover preview, reasonable width)
-- ============================================================================

function UIHelpers.createSlider(
	parent: Frame,
	label: string,
	min: number,
	max: number,
	initial: number,
	callback: (number) -> ()
): (TextLabel, Frame, (number) -> ())
	local currentValue = initial
	local UserInputService = game:GetService("UserInputService")

	-- Main container - fixed reasonable width
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(0, Theme.Sizes.SliderTrackWidth + 60, 0, Theme.Sizes.SliderHeight)
	container.Parent = parent

	-- Header row: label on left, value on right
	local headerRow = Instance.new("Frame")
	headerRow.Name = "Header"
	headerRow.BackgroundTransparency = 1
	headerRow.Size = UDim2.new(1, 0, 0, 18)
	headerRow.Parent = container

	local labelText = Instance.new("TextLabel")
	labelText.Name = "Label"
	labelText.BackgroundTransparency = 1
	labelText.Size = UDim2.new(0.5, 0, 1, 0)
	labelText.Font = Theme.Fonts.Medium
	labelText.TextSize = Theme.Sizes.TextNormal
	labelText.TextColor3 = Theme.Colors.Text
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.Text = label
	labelText.Parent = headerRow

	local valueText = Instance.new("TextLabel")
	valueText.Name = "Value"
	valueText.BackgroundTransparency = 1
	valueText.Position = UDim2.new(0.5, 0, 0, 0)
	valueText.Size = UDim2.new(0.5, 0, 1, 0)
	valueText.Font = Theme.Fonts.Bold
	valueText.TextSize = Theme.Sizes.TextNormal
	valueText.TextColor3 = Theme.Colors.Accent
	valueText.TextXAlignment = Enum.TextXAlignment.Right
	valueText.Text = tostring(initial)
	valueText.Parent = headerRow

	-- Slider track
	local sliderBg = Instance.new("Frame")
	sliderBg.Name = "SliderTrack"
	sliderBg.BackgroundColor3 = Theme.Colors.SliderTrack
	sliderBg.BorderSizePixel = 0
	sliderBg.Position = UDim2.new(0, 0, 0, 24)
	sliderBg.Size = UDim2.new(0, Theme.Sizes.SliderTrackWidth, 0, Theme.Sizes.SliderTrackHeight)
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
	thumb.Size = UDim2.new(0, Theme.Sizes.SliderThumbSize, 0, Theme.Sizes.SliderThumbSize)
	thumb.ZIndex = 2
	thumb.Parent = sliderBg

	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(1, 0)
	thumbCorner.Parent = thumb

	local thumbStroke = Instance.new("UIStroke")
	thumbStroke.Color = Theme.Colors.SliderThumbStroke
	thumbStroke.Thickness = Theme.Sizes.SliderThumbStroke
	thumbStroke.Parent = thumb

	-- Hover preview tooltip
	local hoverPreview = Instance.new("TextLabel")
	hoverPreview.Name = "HoverPreview"
	hoverPreview.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	hoverPreview.BorderSizePixel = 0
	hoverPreview.Size = UDim2.new(0, 36, 0, 20)
	hoverPreview.AnchorPoint = Vector2.new(0.5, 1)
	hoverPreview.Position = UDim2.new(0, 0, 0, -4)
	hoverPreview.Font = Theme.Fonts.Bold
	hoverPreview.TextSize = 11
	hoverPreview.TextColor3 = Theme.Colors.Text
	hoverPreview.Visible = false
	hoverPreview.ZIndex = 10
	hoverPreview.Parent = sliderBg

	local previewCorner = Instance.new("UICorner")
	previewCorner.CornerRadius = UDim.new(0, 4)
	previewCorner.Parent = hoverPreview

	-- Min/Max labels below track
	local minLabel = Instance.new("TextLabel")
	minLabel.BackgroundTransparency = 1
	minLabel.Position = UDim2.new(0, 0, 0, 40)
	minLabel.Size = UDim2.new(0, 30, 0, 12)
	minLabel.Font = Theme.Fonts.Default
	minLabel.TextSize = Theme.Sizes.TextSmall
	minLabel.TextColor3 = Theme.Colors.TextDim
	minLabel.TextXAlignment = Enum.TextXAlignment.Left
	minLabel.Text = tostring(min)
	minLabel.Parent = container

	local maxLabel = Instance.new("TextLabel")
	maxLabel.BackgroundTransparency = 1
	maxLabel.Position = UDim2.new(0, Theme.Sizes.SliderTrackWidth - 30, 0, 40)
	maxLabel.Size = UDim2.new(0, 30, 0, 12)
	maxLabel.Font = Theme.Fonts.Default
	maxLabel.TextSize = Theme.Sizes.TextSmall
	maxLabel.TextColor3 = Theme.Colors.TextDim
	maxLabel.TextXAlignment = Enum.TextXAlignment.Right
	maxLabel.Text = tostring(max)
	maxLabel.Parent = container

	-- Function to update slider visually and call callback
	local function setValue(value: number)
		value = math.clamp(math.floor(value + 0.5), min, max)
		currentValue = value
		local relativeX = (value - min) / (max - min)
		sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
		thumb.Position = UDim2.new(relativeX, 0, 0.5, 0)
		valueText.Text = tostring(value)
		callback(value)
	end

	-- Helper to get value at mouse position
	local function getValueAtPosition(posX: number): number
		local relativeX = math.clamp((posX - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
		return math.floor(min + relativeX * (max - min) + 0.5)
	end

	-- Hover: show preview of value you'd click to
	sliderBg.MouseMoved:Connect(function(x: number)
		local previewValue = getValueAtPosition(x)
		hoverPreview.Text = tostring(previewValue)
		local relX = (previewValue - min) / (max - min)
		hoverPreview.Position = UDim2.new(relX, 0, 0, -4)
		hoverPreview.Visible = true
	end)

	sliderBg.MouseLeave:Connect(function()
		hoverPreview.Visible = false
	end)

	-- Click on track to set value
	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local value = getValueAtPosition(input.Position.X)
			setValue(value)
		end
	end)

	-- Return label, container, and setValue function for external updates
	return labelText, container, setValue
end

-- ============================================================================
-- Config Panel
-- ============================================================================

function UIHelpers.createConfigPanel(parent: Frame, name: string): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.BackgroundTransparency = 1
	panel.Size = UDim2.new(1, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	panel.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Theme.Sizes.PaddingSmall)
	layout.Parent = panel

	return panel
end

-- ============================================================================
-- Container Helpers
-- ============================================================================

-- NEW: Create a container with automatic sizing and list layout
function UIHelpers.createAutoContainer(parent: Frame, name: string?): Frame
	local container = Instance.new("Frame")
	container.Name = name or "Container"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Theme.Sizes.PaddingSmall)
	layout.Parent = container

	return container
end

-- NEW: Create a container with grid layout
function UIHelpers.createGridContainer(parent: Frame, cellSize: UDim2?, cellPadding: UDim2?): Frame
	local container = Instance.new("Frame")
	container.Name = "GridContainer"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.Parent = parent

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize or UDim2.new(0, Theme.Sizes.ButtonWidth, 0, Theme.Sizes.ButtonHeight)
	grid.CellPadding = cellPadding or UDim2.new(0, Theme.Sizes.PaddingSmall, 0, Theme.Sizes.PaddingSmall)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = container

	return container
end

return UIHelpers
