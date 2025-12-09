--!strict
-- UI Helper functions for the Terrain Editor
-- Extracted to reduce local register count in main module

local UIHelpers = {}

function UIHelpers.createLabel(parent: Frame, text: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
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
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

function UIHelpers.createButton(parent: Frame, text: string, position: UDim2, size: UDim2, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	button.MouseButton1Click:Connect(callback)
	return button
end

function UIHelpers.createSlider(
	parent: Frame,
	label: string,
	min: number,
	max: number,
	initial: number,
	callback: (number) -> ()
): (TextLabel, Frame, (number) -> ())
	local currentValue = initial

	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 70)
	container.Parent = parent

	local labelText = UIHelpers.createLabel(container, label .. ": " .. tostring(initial), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 18))

	-- Slider track area
	local sliderArea = Instance.new("Frame")
	sliderArea.Name = "SliderArea"
	sliderArea.BackgroundTransparency = 1
	sliderArea.Position = UDim2.new(0, 0, 0, 20)
	sliderArea.Size = UDim2.new(1, 0, 0, 52)
	sliderArea.Parent = container

	-- Min label
	local minLabel = Instance.new("TextLabel")
	minLabel.BackgroundTransparency = 1
	minLabel.Position = UDim2.new(0, 0, 0, 0)
	minLabel.Size = UDim2.new(0, 30, 0, 12)
	minLabel.Font = Enum.Font.Gotham
	minLabel.TextSize = 10
	minLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	minLabel.TextXAlignment = Enum.TextXAlignment.Left
	minLabel.Text = tostring(min)
	minLabel.Parent = sliderArea

	-- Max label
	local maxLabel = Instance.new("TextLabel")
	maxLabel.BackgroundTransparency = 1
	maxLabel.Position = UDim2.new(1, -30, 0, 0)
	maxLabel.Size = UDim2.new(0, 30, 0, 12)
	maxLabel.Font = Enum.Font.Gotham
	maxLabel.TextSize = 10
	maxLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	maxLabel.TextXAlignment = Enum.TextXAlignment.Right
	maxLabel.Text = tostring(max)
	maxLabel.Parent = sliderArea

	-- Slider background track
	local sliderBg = Instance.new("Frame")
	sliderBg.Name = "SliderTrack"
	sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	sliderBg.BorderSizePixel = 0
	sliderBg.Position = UDim2.new(0, 0, 0, 14)
	sliderBg.Size = UDim2.new(1, 0, 0, 18)
	sliderBg.Parent = sliderArea

	local sliderCorner = Instance.new("UICorner")
	sliderCorner.CornerRadius = UDim.new(0, 9)
	sliderCorner.Parent = sliderBg

	-- Hashmarks container
	local hashContainer = Instance.new("Frame")
	hashContainer.Name = "Hashmarks"
	hashContainer.BackgroundTransparency = 1
	hashContainer.Position = UDim2.new(0, 0, 0, 35)
	hashContainer.Size = UDim2.new(1, 0, 0, 8)
	hashContainer.Parent = sliderArea

	-- Create hashmarks (5 ticks: 0%, 25%, 50%, 75%, 100%)
	for i = 0, 4 do
		local tickPos = i / 4
		local tick = Instance.new("Frame")
		tick.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		tick.BorderSizePixel = 0
		tick.Position = UDim2.new(tickPos, -1, 0, 0)
		tick.Size = UDim2.new(0, 2, 1, 0)
		tick.Parent = hashContainer
	end

	-- Slider fill
	local sliderFill = Instance.new("Frame")
	sliderFill.Name = "Fill"
	sliderFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
	sliderFill.BorderSizePixel = 0
	sliderFill.Size = UDim2.new((initial - min) / (max - min), 0, 1, 0)
	sliderFill.Parent = sliderBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = sliderFill

	-- Draggable thumb
	local thumb = Instance.new("Frame")
	thumb.Name = "Thumb"
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel = 0
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	thumb.Position = UDim2.new((initial - min) / (max - min), 0, 0.5, 0)
	thumb.Size = UDim2.new(0, 20, 0, 20)
	thumb.ZIndex = 2
	thumb.Parent = sliderBg

	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(1, 0)
	thumbCorner.Parent = thumb

	local thumbStroke = Instance.new("UIStroke")
	thumbStroke.Color = Color3.fromRGB(0, 120, 200)
	thumbStroke.Thickness = 2
	thumbStroke.Parent = thumb

	-- Function to update slider visually and call callback
	local function setValue(value: number)
		value = math.clamp(math.floor(value + 0.5), min, max)
		currentValue = value
		local relativeX = (value - min) / (max - min)
		sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
		thumb.Position = UDim2.new(relativeX, 0, 0.5, 0)
		labelText.Text = label .. ": " .. tostring(value)
		callback(value)
	end

	-- Click on track to set value (single click, no drag)
	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local relativeX = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
			local value = min + relativeX * (max - min)
			setValue(value)
		end
	end)

	-- Return label, container, and setValue function for external updates
	return labelText, container, setValue
end

function UIHelpers.createToolButton(parent: Frame, toolId: string, displayName: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = toolId
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = UDim2.new(0, 70, 0, 32)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 11
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = displayName
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	return button
end

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
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	return panel
end

return UIHelpers

