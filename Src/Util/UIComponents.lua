--!strict
-- UIComponents.lua - Reusable higher-level UI component factories
-- These reduce boilerplate and local variable count in panel modules

local Theme = require(script.Parent.Theme)
local BrushData = require(script.Parent.BrushData)

local UIComponents = {}

-- ============================================================================
-- Type Definitions
-- ============================================================================

export type ButtonGroupConfig = {
	parent: Frame,
	options: { { id: string, name: string } },
	initialValue: string,
	onChange: (newValue: string) -> (),
	layout: ("horizontal" | "grid")?,
	buttonSize: UDim2?,
	cellPadding: UDim2?,
}

export type ButtonGroupResult = {
	container: Frame,
	buttons: { [string]: TextButton },
	update: (newValue: string) -> (),
	getValue: () -> string,
}

export type MaterialCycleButtonConfig = {
	parent: Frame,
	initialMaterial: Enum.Material,
	onChange: (newMaterial: Enum.Material) -> (),
	position: UDim2?,
	size: UDim2?,
	suffix: string?, -- e.g. " 60%" for Megarandomize
}

export type MaterialCycleButtonResult = {
	button: TextButton,
	update: (newMaterial: Enum.Material) -> (),
	getMaterial: () -> Enum.Material,
}

export type MaterialPickerConfig = {
	parent: Frame,
	initialMaterial: Enum.Material,
	onSelect: (material: Enum.Material) -> (),
}

export type MaterialPickerResult = {
	container: Frame,
	update: (newMaterial: Enum.Material) -> (),
}

export type ToggleButtonConfig = {
	parent: Frame,
	initialState: boolean,
	textOn: string,
	textOff: string,
	onChange: (newState: boolean) -> (),
	size: UDim2?,
}

export type ToggleButtonResult = {
	button: TextButton,
	update: (newState: boolean) -> (),
	getState: () -> boolean,
}

-- ============================================================================
-- ButtonGroup Component
-- Creates a group of mutually-exclusive selection buttons
-- ============================================================================

--[[
    Usage:
        local shapeGroup = UIComponents.createButtonGroup({
            parent = shapePanel,
            options = { {id = "Sphere", name = "Sphere"}, {id = "Cube", name = "Cube"} },
            initialValue = "Sphere",
            onChange = function(newShape)
                S.brushShape = newShape
            end,
            layout = "grid",
        })
        
        -- Later, to update externally:
        shapeGroup.update("Cube")
]]
function UIComponents.createButtonGroup(config: ButtonGroupConfig): ButtonGroupResult
	local currentValue = config.initialValue
	local buttons: { [string]: TextButton } = {}

	-- Container
	local container = Instance.new("Frame")
	container.Name = "ButtonGroup"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.Parent = config.parent

	-- Layout
	local buttonSize = config.buttonSize or UDim2.new(0, Theme.Sizes.ButtonWidth, 0, Theme.Sizes.ButtonHeight)

	if config.layout == "grid" then
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = buttonSize
		grid.CellPadding = config.cellPadding or UDim2.new(0, Theme.Sizes.PaddingSmall, 0, Theme.Sizes.PaddingSmall)
		grid.FillDirection = Enum.FillDirection.Horizontal
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = container
	else
		-- Horizontal layout (default)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, Theme.Sizes.PaddingSmall)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = container
	end

	-- Update function
	local function updateButtonVisuals()
		for id, btn in pairs(buttons) do
			if id == currentValue then
				btn.BackgroundColor3 = Theme.Colors.ButtonSelected
			else
				btn.BackgroundColor3 = Theme.Colors.ButtonDefault
			end
			btn.TextColor3 = Theme.Colors.Text
		end
	end

	-- Create buttons
	for i, option in ipairs(config.options) do
		local btn = Instance.new("TextButton")
		btn.Name = option.id
		btn.Size = buttonSize
		btn.BackgroundColor3 = Theme.Colors.ButtonDefault
		btn.BorderSizePixel = 0
		btn.Font = Theme.Fonts.Medium
		btn.TextSize = Theme.Sizes.TextDescription
		btn.TextColor3 = Theme.Colors.Text
		btn.Text = option.name
		btn.LayoutOrder = i
		btn.AutoButtonColor = true
		btn.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, Theme.Sizes.CornerRadius)
		corner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			currentValue = option.id
			updateButtonVisuals()
			config.onChange(option.id)
		end)

		buttons[option.id] = btn
	end

	-- Initial visual state
	updateButtonVisuals()

	return {
		container = container,
		buttons = buttons,
		update = function(newValue: string)
			currentValue = newValue
			updateButtonVisuals()
		end,
		getValue = function()
			return currentValue
		end,
	}
end

-- ============================================================================
-- MaterialCycleButton Component
-- Button that cycles through materials on click
-- ============================================================================

--[[
    Usage:
        local matBtn = UIComponents.createMaterialCycleButton({
            parent = slopeFlatRow,
            initialMaterial = Enum.Material.Grass,
            onChange = function(newMat)
                S.slopeFlatMaterial = newMat
            end,
            position = UDim2.new(0, 85, 0, 0),
            suffix = " 60%",
        })
]]
function UIComponents.createMaterialCycleButton(config: MaterialCycleButtonConfig): MaterialCycleButtonResult
	local currentMaterial = config.initialMaterial
	local suffix = config.suffix or ""

	-- Find initial info
	local currentName = "Unknown"
	local currentKey = "grass"
	for _, matInfo in ipairs(BrushData.Materials) do
		if matInfo.enum == currentMaterial then
			currentName = matInfo.name
			currentKey = matInfo.key
			break
		end
	end

	-- Container button
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Theme.Colors.ButtonDefault
	button.BorderSizePixel = 0
	button.Position = config.position or UDim2.new(0, 0, 0, 0)
	button.Size = config.size or UDim2.new(0, 110, 0, 26)
	button.Font = Theme.Fonts.Medium
	button.TextSize = Theme.Sizes.TextNormal
	button.TextColor3 = Theme.Colors.Text
	button.Text = ""  -- Text will be in the label
	button.AutoButtonColor = true
	button.Parent = config.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Sizes.CornerRadius)
	corner.Parent = button

	-- Material image thumbnail
	local thumbnail = Instance.new("ImageLabel")
	thumbnail.Name = "Thumbnail"
	thumbnail.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	thumbnail.BorderSizePixel = 0
	thumbnail.Position = UDim2.new(0, 3, 0, 3)
	thumbnail.Size = UDim2.new(0, 20, 0, 20)
	thumbnail.Image = BrushData.TerrainTileAssets[currentKey] or ""
	thumbnail.ScaleType = Enum.ScaleType.Crop
	thumbnail.Parent = button

	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(0, 3)
	thumbCorner.Parent = thumbnail

	-- Material name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 26, 0, 0)
	nameLabel.Size = UDim2.new(1, -29, 1, 0)
	nameLabel.Font = Theme.Fonts.Medium
	nameLabel.TextSize = Theme.Sizes.TextNormal
	nameLabel.TextColor3 = Theme.Colors.Text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = currentName .. suffix
	nameLabel.Parent = button

	local function updateDisplay()
		for _, matInfo in ipairs(BrushData.Materials) do
			if matInfo.enum == currentMaterial then
				nameLabel.Text = matInfo.name .. suffix
				thumbnail.Image = BrushData.TerrainTileAssets[matInfo.key] or ""
				break
			end
		end
	end

	button.MouseButton1Click:Connect(function()
		local mats = BrushData.Materials
		for i, m in ipairs(mats) do
			if m.enum == currentMaterial then
				local nextIdx = (i % #mats) + 1
				currentMaterial = mats[nextIdx].enum
				updateDisplay()
				config.onChange(currentMaterial)
				break
			end
		end
	end)

	return {
		button = button,
		update = function(newMaterial: Enum.Material)
			currentMaterial = newMaterial
			updateDisplay()
		end,
		getMaterial = function()
			return currentMaterial
		end,
	}
end

-- ============================================================================
-- MaterialPicker Component
-- The 22-tile material grid with image tiles
-- ============================================================================

--[[
    Usage:
        local picker = UIComponents.createMaterialPicker({
            parent = materialPanel,
            initialMaterial = Enum.Material.Grass,
            onSelect = function(mat)
                S.brushMaterial = mat
            end,
        })
]]
function UIComponents.createMaterialPicker(config: MaterialPickerConfig): MaterialPickerResult
	local currentMaterial = config.initialMaterial
	local materialButtons: { [Enum.Material]: Frame } = {}

	local container = Instance.new("CanvasGroup")
	container.Name = "MaterialGrid"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.Parent = config.parent

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, Theme.Sizes.MaterialTileSize, 0, Theme.Sizes.MaterialGridCellHeight)
	gridLayout.CellPadding = UDim2.new(0, Theme.Sizes.PaddingSmall, 0, Theme.Sizes.PaddingMedium)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = container

	local function updateSelection()
		for mat, tileContainer in pairs(materialButtons) do
			local tileBtn = tileContainer:FindFirstChild("TileButton")
			if tileBtn then
				local border = tileBtn:FindFirstChild("SelectionBorder") :: UIStroke?
				if border then
					border.Transparency = (mat == currentMaterial) and 0 or 1
				end
			end
		end
	end

	for i, matInfo in ipairs(BrushData.Materials) do
		local tileContainer = Instance.new("Frame")
		tileContainer.Name = matInfo.key
		tileContainer.BackgroundTransparency = 1
		tileContainer.Size = UDim2.new(0, Theme.Sizes.MaterialTileSize, 0, Theme.Sizes.MaterialGridCellHeight)
		tileContainer.LayoutOrder = i
		tileContainer.Parent = container

		local tileBtn = Instance.new("ImageButton")
		tileBtn.Name = "TileButton"
		tileBtn.BackgroundColor3 = Theme.Colors.Panel
		tileBtn.BorderSizePixel = 0
		tileBtn.Size = UDim2.new(0, Theme.Sizes.MaterialTileSize, 0, Theme.Sizes.MaterialTileSize)
		tileBtn.Image = BrushData.TerrainTileAssets[matInfo.key] or ""
		tileBtn.ScaleType = Enum.ScaleType.Crop
		tileBtn.Parent = tileContainer

		local tileCorner = Instance.new("UICorner")
		tileCorner.CornerRadius = UDim.new(0, Theme.Sizes.CornerRadiusLarge)
		tileCorner.Parent = tileBtn

		local selectionBorder = Instance.new("UIStroke")
		selectionBorder.Name = "SelectionBorder"
		selectionBorder.Color = Theme.Colors.Border
		selectionBorder.Thickness = 3
		selectionBorder.Transparency = (matInfo.enum == currentMaterial) and 0 or 1
		selectionBorder.Parent = tileBtn

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0, 0, 0, Theme.Sizes.MaterialTileSize + 2)
		label.Size = UDim2.new(1, 0, 0, Theme.Sizes.MaterialTileLabelHeight)
		label.Font = Theme.Fonts.Bold
		label.TextSize = Theme.Sizes.TextNormal
		label.TextColor3 = Theme.Colors.Text
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = matInfo.name
		label.Parent = tileContainer

		materialButtons[matInfo.enum] = tileContainer

		tileBtn.MouseButton1Click:Connect(function()
			currentMaterial = matInfo.enum
			updateSelection()
			config.onSelect(matInfo.enum)
		end)
	end

	return {
		container = container,
		update = function(newMaterial: Enum.Material)
			currentMaterial = newMaterial
			updateSelection()
		end,
	}
end

-- ============================================================================
-- ToggleButton Component
-- Button that toggles between two states
-- ============================================================================

--[[
    Usage:
        local hollowToggle = UIComponents.createToggleButton({
            parent = hollowPanel,
            initialState = false,
            textOn = "HOLLOW",
            textOff = "Solid",
            onChange = function(isHollow)
                S.hollowEnabled = isHollow
            end,
        })
]]
function UIComponents.createToggleButton(config: ToggleButtonConfig): ToggleButtonResult
	local currentState = config.initialState

	local button = Instance.new("TextButton")
	button.BackgroundColor3 = currentState and Theme.Colors.ButtonToggleOn or Theme.Colors.ButtonDefault
	button.BorderSizePixel = 0
	button.Size = config.size or UDim2.new(0, 100, 0, Theme.Sizes.ButtonHeight)
	button.Font = Theme.Fonts.Medium
	button.TextSize = Theme.Sizes.TextNormal
	button.TextColor3 = Theme.Colors.Text
	button.Text = currentState and config.textOn or config.textOff
	button.AutoButtonColor = true
	button.Parent = config.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Sizes.CornerRadius)
	corner.Parent = button

	local function updateVisuals()
		button.BackgroundColor3 = currentState and Theme.Colors.ButtonToggleOn or Theme.Colors.ButtonDefault
		button.Text = currentState and config.textOn or config.textOff
	end

	button.MouseButton1Click:Connect(function()
		currentState = not currentState
		updateVisuals()
		config.onChange(currentState)
	end)

	return {
		button = button,
		update = function(newState: boolean)
			currentState = newState
			updateVisuals()
		end,
		getState = function()
			return currentState
		end,
	}
end

-- ============================================================================
-- LabeledButtonGroup Component
-- Compact inline layout: "Label — [Opt1] [Opt2] [Opt3]"
-- ============================================================================

export type LabeledButtonGroupConfig = {
	parent: Frame,
	label: string,
	options: { { id: string, name: string } },
	initialValue: string,
	onChange: (newValue: string) -> (),
	labelWidth: number?,
	buttonWidth: number?,
}

export type LabeledButtonGroupResult = {
	container: Frame,
	buttons: { [string]: TextButton },
	update: (newValue: string) -> (),
	getValue: () -> string,
}

function UIComponents.createLabeledButtonGroup(config: LabeledButtonGroupConfig): LabeledButtonGroupResult
	local currentValue = config.initialValue
	local buttons: { [string]: TextButton } = {}
	local labelWidth = config.labelWidth or 80
	local buttonWidth = config.buttonWidth or 60

	-- Container row
	local container = Instance.new("Frame")
	container.Name = "LabeledButtonGroup"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 26)
	container.Parent = config.parent

	-- Label on the left - BOLD, WHITE, BIGGER
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Size = UDim2.new(0, labelWidth, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = config.label
	label.Parent = container

	-- Buttons container - aligned to consistent start position
	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Name = "Buttons"
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.Position = UDim2.new(0, labelWidth, 0, 0)
	buttonsContainer.Size = UDim2.new(1, -labelWidth, 1, 0)
	buttonsContainer.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 3)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = buttonsContainer

	-- Update function
	local function updateButtonVisuals()
		for id, btn in pairs(buttons) do
			if id == currentValue then
				btn.BackgroundColor3 = Theme.Colors.ButtonSelected
			else
				btn.BackgroundColor3 = Theme.Colors.ButtonDefault
			end
			btn.TextColor3 = Theme.Colors.Text
		end
	end

	-- Create buttons
	for i, option in ipairs(config.options) do
		local btn = Instance.new("TextButton")
		btn.Name = option.id
		btn.Size = UDim2.new(0, buttonWidth, 0, 22)
		btn.BackgroundColor3 = Theme.Colors.ButtonDefault
		btn.BorderSizePixel = 0
		btn.Font = Theme.Fonts.Medium
		btn.TextSize = 11
		btn.TextColor3 = Theme.Colors.Text
		btn.Text = option.name
		btn.LayoutOrder = i
		btn.AutoButtonColor = true
		btn.Parent = buttonsContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			currentValue = option.id
			updateButtonVisuals()
			config.onChange(option.id)
		end)

		buttons[option.id] = btn
	end

	-- Initial visual state
	updateButtonVisuals()

	return {
		container = container,
		buttons = buttons,
		update = function(newValue: string)
			currentValue = newValue
			updateButtonVisuals()
		end,
		getValue = function()
			return currentValue
		end,
	}
end

-- ============================================================================
-- LabeledToggle Component  
-- Compact inline layout: "Label — [Toggle]"
-- ============================================================================

export type LabeledToggleConfig = {
	parent: Frame,
	label: string,
	initialState: boolean,
	textOn: string,
	textOff: string,
	onChange: (newState: boolean) -> (),
	labelWidth: number?,
}

export type LabeledToggleResult = {
	container: Frame,
	update: (newState: boolean) -> (),
	getState: () -> boolean,
}

function UIComponents.createLabeledToggle(config: LabeledToggleConfig): LabeledToggleResult
	local currentState = config.initialState
	local labelWidth = config.labelWidth or 80

	-- Container row
	local container = Instance.new("Frame")
	container.Name = "LabeledToggle"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 26)
	container.Parent = config.parent

	-- Label on the left - BOLD, WHITE, BIGGER
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Size = UDim2.new(0, labelWidth, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = config.label
	label.Parent = container

	-- Toggle button - aligned to same position as other button groups
	local button = Instance.new("TextButton")
	button.Name = "Toggle"
	button.Position = UDim2.new(0, labelWidth, 0, 2)
	button.Size = UDim2.new(0, 70, 0, 22)
	button.BackgroundColor3 = currentState and Theme.Colors.ButtonToggleOn or Theme.Colors.ButtonDefault
	button.BorderSizePixel = 0
	button.Font = Theme.Fonts.Medium
	button.TextSize = 11
	button.TextColor3 = Theme.Colors.Text
	button.Text = currentState and config.textOn or config.textOff
	button.AutoButtonColor = true
	button.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	local function updateVisuals()
		button.BackgroundColor3 = currentState and Theme.Colors.ButtonToggleOn or Theme.Colors.ButtonDefault
		button.Text = currentState and config.textOn or config.textOff
	end

	button.MouseButton1Click:Connect(function()
		currentState = not currentState
		updateVisuals()
		config.onChange(currentState)
	end)

	return {
		container = container,
		update = function(newState: boolean)
			currentState = newState
			updateVisuals()
		end,
		getState = function()
			return currentState
		end,
	}
end

-- ============================================================================
-- Shape Icon Component
-- Creates visual GUI-based icons for brush shapes
-- ============================================================================

local TerrainEnums = require(script.Parent.TerrainEnums)
local BrushShape = TerrainEnums.BrushShape

-- Shape icon size constants
local SHAPE_ICON_SIZE = 24
local SHAPE_ICON_COLOR = Color3.fromRGB(180, 200, 220)
local SHAPE_ICON_COLOR_DIM = Color3.fromRGB(100, 115, 130)

-- Helper: Create a simple colored frame element
local function createIconElement(parent: Frame, props: {
	position: UDim2?,
	size: UDim2,
	color: Color3?,
	cornerRadius: number?,
	rotation: number?,
}): Frame
	local element = Instance.new("Frame")
	element.BackgroundColor3 = props.color or SHAPE_ICON_COLOR
	element.BorderSizePixel = 0
	element.Position = props.position or UDim2.new(0, 0, 0, 0)
	element.Size = props.size
	element.AnchorPoint = Vector2.new(0.5, 0.5)
	element.Rotation = props.rotation or 0
	element.Parent = parent
	
	if props.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, props.cornerRadius)
		corner.Parent = element
	end
	
	return element
end

--[[
	Creates a visual icon for a brush shape using GUI elements.
	Returns a Frame containing the shape icon.
]]
function UIComponents.createShapeIcon(shapeId: string, size: number?): Frame
	local iconSize = size or SHAPE_ICON_SIZE
	local container = Instance.new("Frame")
	container.Name = "ShapeIcon"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(0, iconSize, 0, iconSize)
	
	local s = iconSize -- shorthand
	local halfS = s / 2
	
	if shapeId == BrushShape.Sphere then
		-- Circle
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.85),
			cornerRadius = s,
		})
		
	elseif shapeId == BrushShape.Cube then
		-- Square
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.75, 0, s * 0.75),
			cornerRadius = 2,
		})
		
	elseif shapeId == BrushShape.Cylinder then
		-- Tall rounded rectangle (pill shape)
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.55, 0, s * 0.85),
			cornerRadius = s * 0.27,
		})
		
	elseif shapeId == BrushShape.Wedge then
		-- Right triangle using rotated square
		-- We'll use a square rotated 45 degrees with half hidden
		local triangleContainer = Instance.new("Frame")
		triangleContainer.BackgroundTransparency = 1
		triangleContainer.Size = UDim2.new(1, 0, 1, 0)
		triangleContainer.ClipsDescendants = true
		triangleContainer.Parent = container
		
		createIconElement(triangleContainer, {
			position = UDim2.new(0.7, 0, 0.7, 0),
			size = UDim2.new(0, s * 0.9, 0, s * 0.9),
			rotation = 45,
			cornerRadius = 2,
		})
		
	elseif shapeId == BrushShape.CornerWedge then
		-- Corner wedge - triangle in corner
		local triangleContainer = Instance.new("Frame")
		triangleContainer.BackgroundTransparency = 1
		triangleContainer.Size = UDim2.new(1, 0, 1, 0)
		triangleContainer.ClipsDescendants = true
		triangleContainer.Parent = container
		
		createIconElement(triangleContainer, {
			position = UDim2.new(0.75, 0, 0.75, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.85),
			rotation = 45,
			cornerRadius = 2,
		})
		
	elseif shapeId == BrushShape.Dome then
		-- Half circle (dome) - clip bottom half
		local domeClip = Instance.new("Frame")
		domeClip.BackgroundTransparency = 1
		domeClip.Position = UDim2.new(0, 0, 0, 0)
		domeClip.Size = UDim2.new(1, 0, 0.55, 0)
		domeClip.ClipsDescendants = true
		domeClip.Parent = container
		
		createIconElement(domeClip, {
			position = UDim2.new(0.5, 0, 1, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.85),
			cornerRadius = s,
		})
		
	elseif shapeId == BrushShape.RotatedDome then
		-- Arch shape (U turned upside down)
		-- Outer circle with inner cutout effect
		local archOuter = createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.42, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.85),
			cornerRadius = s,
		})
		
		-- Inner cutout (using background color)
		local innerCut = Instance.new("Frame")
		innerCut.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		innerCut.BorderSizePixel = 0
		innerCut.Position = UDim2.new(0.5, 0, 0.6, 0)
		innerCut.Size = UDim2.new(0, s * 0.5, 0, s * 0.5)
		innerCut.AnchorPoint = Vector2.new(0.5, 0.5)
		innerCut.Parent = archOuter
		
		local innerCorner = Instance.new("UICorner")
		innerCorner.CornerRadius = UDim.new(1, 0)
		innerCorner.Parent = innerCut
		
		-- Bottom extension bars
		createIconElement(container, {
			position = UDim2.new(0.22, 0, 0.75, 0),
			size = UDim2.new(0, s * 0.17, 0, s * 0.4),
		})
		createIconElement(container, {
			position = UDim2.new(0.78, 0, 0.75, 0),
			size = UDim2.new(0, s * 0.17, 0, s * 0.4),
		})
		
	elseif shapeId == BrushShape.Torus then
		-- Donut shape - circle with hole
		local outerRing = createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.85),
			cornerRadius = s,
		})
		
		-- Inner hole
		local innerHole = Instance.new("Frame")
		innerHole.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		innerHole.BorderSizePixel = 0
		innerHole.Position = UDim2.new(0.5, 0, 0.5, 0)
		innerHole.Size = UDim2.new(0, s * 0.4, 0, s * 0.4)
		innerHole.AnchorPoint = Vector2.new(0.5, 0.5)
		innerHole.Parent = outerRing
		
		local holeCorner = Instance.new("UICorner")
		holeCorner.CornerRadius = UDim.new(1, 0)
		holeCorner.Parent = innerHole
		
	elseif shapeId == BrushShape.Ring then
		-- Flat ring (horizontal donut view) - ellipse with hole
		local outerRing = createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.9, 0, s * 0.45),
			cornerRadius = s,
		})
		
		-- Inner hole (ellipse)
		local innerHole = Instance.new("Frame")
		innerHole.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		innerHole.BorderSizePixel = 0
		innerHole.Position = UDim2.new(0.5, 0, 0.5, 0)
		innerHole.Size = UDim2.new(0, s * 0.45, 0, s * 0.22)
		innerHole.AnchorPoint = Vector2.new(0.5, 0.5)
		innerHole.Parent = outerRing
		
		local holeCorner = Instance.new("UICorner")
		holeCorner.CornerRadius = UDim.new(1, 0)
		holeCorner.Parent = innerHole
		
	elseif shapeId == BrushShape.ZigZag then
		-- Z shape using 3 bars
		local barW = s * 0.65
		local barH = s * 0.18
		-- Top horizontal
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.22, 0),
			size = UDim2.new(0, barW, 0, barH),
			cornerRadius = 2,
		})
		-- Diagonal (rotated)
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, barW * 0.8, 0, barH),
			rotation = -55,
			cornerRadius = 2,
		})
		-- Bottom horizontal
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.78, 0),
			size = UDim2.new(0, barW, 0, barH),
			cornerRadius = 2,
		})
		
	elseif shapeId == BrushShape.Sheet then
		-- Curved sheet / arc shape
		-- Use multiple small dots to form arc
		local arcRadius = s * 0.35
		local dotSize = s * 0.12
		for i = 0, 6 do
			local angle = math.rad(180 + i * 25) -- Arc from left to right
			local x = 0.5 + math.cos(angle) * (arcRadius / s)
			local y = 0.55 + math.sin(angle) * (arcRadius / s)
			createIconElement(container, {
				position = UDim2.new(x, 0, y, 0),
				size = UDim2.new(0, dotSize, 0, dotSize),
				cornerRadius = dotSize,
			})
		end
		
	elseif shapeId == BrushShape.Grid then
		-- 2x2 checkerboard pattern
		local cellSize = s * 0.35
		local gap = s * 0.08
		local offset = (s - 2 * cellSize - gap) / 2
		
		-- Top-left
		createIconElement(container, {
			position = UDim2.new(0, offset + cellSize/2, 0, offset + cellSize/2),
			size = UDim2.new(0, cellSize, 0, cellSize),
			cornerRadius = 2,
		})
		-- Top-right (dimmer)
		createIconElement(container, {
			position = UDim2.new(0, offset + cellSize + gap + cellSize/2, 0, offset + cellSize/2),
			size = UDim2.new(0, cellSize, 0, cellSize),
			color = SHAPE_ICON_COLOR_DIM,
			cornerRadius = 2,
		})
		-- Bottom-left (dimmer)
		createIconElement(container, {
			position = UDim2.new(0, offset + cellSize/2, 0, offset + cellSize + gap + cellSize/2),
			size = UDim2.new(0, cellSize, 0, cellSize),
			color = SHAPE_ICON_COLOR_DIM,
			cornerRadius = 2,
		})
		-- Bottom-right
		createIconElement(container, {
			position = UDim2.new(0, offset + cellSize + gap + cellSize/2, 0, offset + cellSize + gap + cellSize/2),
			size = UDim2.new(0, cellSize, 0, cellSize),
			cornerRadius = 2,
		})
		
	elseif shapeId == BrushShape.Stick then
		-- Thin vertical rod
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.22, 0, s * 0.9),
			cornerRadius = s * 0.1,
		})
		
	elseif shapeId == BrushShape.Spinner then
		-- Rotating cube indicator - cube with motion lines
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.6, 0, s * 0.6),
			rotation = 15,
			cornerRadius = 2,
		})
		-- Motion arc
		local arcDots = 3
		for i = 1, arcDots do
			local angle = math.rad(100 + i * 30)
			local radius = s * 0.42
			createIconElement(container, {
				position = UDim2.new(0.5 + math.cos(angle) * radius / s, 0, 0.5 + math.sin(angle) * radius / s, 0),
				size = UDim2.new(0, s * 0.08, 0, s * 0.08),
				color = SHAPE_ICON_COLOR_DIM,
				cornerRadius = s,
			})
		end
		
	elseif shapeId == BrushShape.Spikepad then
		-- Square base with triangular spikes on top
		-- Base
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.72, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.35),
			cornerRadius = 2,
		})
		-- Spikes (3 triangles using rotated squares clipped)
		local spikeClip = Instance.new("Frame")
		spikeClip.BackgroundTransparency = 1
		spikeClip.Position = UDim2.new(0, 0, 0, 0)
		spikeClip.Size = UDim2.new(1, 0, 0.6, 0)
		spikeClip.ClipsDescendants = true
		spikeClip.Parent = container
		
		local spikePositions = {0.25, 0.5, 0.75}
		for _, xPos in ipairs(spikePositions) do
			createIconElement(spikeClip, {
				position = UDim2.new(xPos, 0, 0.85, 0),
				size = UDim2.new(0, s * 0.22, 0, s * 0.22),
				rotation = 45,
				cornerRadius = 1,
			})
		end
		
	else
		-- Fallback: simple square
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.7, 0, s * 0.7),
			cornerRadius = 2,
		})
	end
	
	return container
end

-- ============================================================================
-- RandomizeSeedButton Component
-- Standard "Randomize Seed" action button
-- ============================================================================

function UIComponents.createRandomizeSeedButton(parent: Frame, onRandomize: (seed: number) -> ()): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Theme.Colors.ButtonDefault
	button.BorderSizePixel = 0
	button.AutomaticSize = Enum.AutomaticSize.X  -- Natural width
	button.Size = UDim2.new(0, 0, 0, Theme.Sizes.ButtonHeight)
	button.Font = Theme.Fonts.Medium
	button.TextSize = Theme.Sizes.TextNormal
	button.TextColor3 = Theme.Colors.Text
	button.Text = "🎲 Randomize"
	button.AutoButtonColor = true
	button.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = button

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Sizes.CornerRadius)
	corner.Parent = button

	button.MouseButton1Click:Connect(function()
		local seed = math.random(0, 99999)
		onRandomize(seed)
	end)

	return button
end

return UIComponents

