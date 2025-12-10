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

	local container = Instance.new("Frame")
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

