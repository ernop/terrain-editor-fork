--!strict

-- TerrainEditorFork - Module Version for Live Development
-- This module is loaded by the loader plugin for hot-reloading

local VERSION = "0.0.00000034"
local DEBUG = false

local TerrainEditorModule = {}

function TerrainEditorModule.init(pluginInstance, parentGui)
	-- script is the TerrainEditorFork module in ServerStorage
	-- Src and Packages are children of script (synced by Rojo)
	local Src = script.Src

	-- Services
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local ChangeHistoryService = game:GetService("ChangeHistoryService")
	local CoreGui = game:GetService("CoreGui")

	-- Load utilities
	local TerrainEnums = require(Src.Util.TerrainEnums)
	local Constants = require(Src.Util.Constants)
	local ToolId = TerrainEnums.ToolId
	local BrushShape = TerrainEnums.BrushShape
	local PivotType = TerrainEnums.PivotType
	local FlattenMode = TerrainEnums.FlattenMode
	local PlaneLockType = TerrainEnums.PlaneLockType

	-- Load terrain operations
	local performTerrainBrushOperation = require(Src.TerrainOperations.performTerrainBrushOperation)

	-- Plugin state
	local terrain: Terrain = workspace.Terrain
	local brushConnection: RBXScriptConnection? = nil
	local renderConnection: RBXScriptConnection? = nil

	-- Brush settings
	local currentTool: string = ToolId.Add
	local brushSizeX: number = Constants.INITIAL_BRUSH_SIZE
	local brushSizeY: number = Constants.INITIAL_BRUSH_SIZE
	local brushSizeZ: number = Constants.INITIAL_BRUSH_SIZE
	local brushStrength: number = Constants.INITIAL_BRUSH_STRENGTH
	local brushShape: string = BrushShape.Sphere
	local brushRotation: CFrame = CFrame.new() -- Rotation only (no position)
	local brushMaterial: Enum.Material = Enum.Material.Grass
	local pivotType: string = PivotType.Center
	local flattenMode: string = FlattenMode.Both
	local autoMaterial: boolean = false
	local ignoreWater: boolean = false
	local planeLockMode: string = PlaneLockType.Off
	local planePositionY: number = Constants.INITIAL_PLANE_POSITION_Y
	local autoPlaneActive: boolean = false -- True when Auto mode has captured a plane during stroke

	-- Shape capabilities: which shapes support rotation and multi-axis sizing
	local ShapeSupportsRotation = {
		[BrushShape.Sphere] = false, -- Sphere looks the same from all angles
		[BrushShape.Cube] = true,
		[BrushShape.Cylinder] = true,
		[BrushShape.Wedge] = true,
		[BrushShape.CornerWedge] = true,
		[BrushShape.Dome] = false, -- Dome is symmetric around Y axis
		-- Creative shapes
		[BrushShape.Torus] = true,
		[BrushShape.Ring] = true,
		[BrushShape.ZigZag] = true,
		[BrushShape.Sheet] = true,
		[BrushShape.Grid] = true,
		[BrushShape.Stick] = true,
		[BrushShape.Spinner] = false, -- Auto-rotates, no manual rotation
		[BrushShape.Spikepad] = true, -- Can rotate the spike orientation
	}

	local ShapeSizingMode = {
		-- "uniform" = single size (X=Y=Z), "box" = X, Y, Z independent
		-- Most shapes now support full independent sizing for maximum flexibility
		[BrushShape.Sphere] = "uniform", -- Sphere must be uniform
		[BrushShape.Cube] = "box",
		[BrushShape.Cylinder] = "box", -- Elliptical cylinder: X, Z = radii, Y = height
		[BrushShape.Wedge] = "box",
		[BrushShape.CornerWedge] = "box",
		[BrushShape.Dome] = "box", -- Elliptical dome: X, Z = radii, Y = height
		[BrushShape.Torus] = "box", -- X = major radius, Y = tube radius, Z = depth stretch
		[BrushShape.Ring] = "box", -- X = outer radius, Y = thickness, Z = depth
		[BrushShape.ZigZag] = "box",
		[BrushShape.Sheet] = "box",
		[BrushShape.Grid] = "box", -- Non-uniform grid
		[BrushShape.Stick] = "box", -- X = thickness, Y = length, Z = depth
		[BrushShape.Spinner] = "box",
		[BrushShape.Spikepad] = "box",
	}

	-- Spin mode (can be applied to any brush)
	local spinEnabled = false
	local spinAngle = 0

	-- Hollow mode (can be applied to any brush)
	local hollowEnabled = false
	local wallThickness = 0.2 -- 0.1 to 0.5 (proportion of radius)

	-- Brush rate limiting (prevent firing too fast)
	local BRUSH_COOLDOWN = 0.05 -- 50ms between brush operations (20 ops/sec max)
	local lastBrushTime = 0

	-- Mouse state
	local mouse = pluginInstance:GetMouse()
	local isMouseDown = false
	local lastBrushPosition: Vector3? = nil

	-- Brush visualization
	local brushPart: BasePart? = nil -- Main brush part (can be Part, WedgePart, or CornerWedgePart)
	local brushExtraParts: { BasePart } = {} -- Additional parts for complex shapes (torus, grid, spikes, etc.)
	local planePart: Part? = nil -- Visual indicator for locked plane

	-- 3D Handles for rotation and sizing
	local rotationHandles: ArcHandles? = nil
	local sizeHandles: Handles? = nil
	local isHandleDragging: boolean = false -- Prevent brush painting while dragging handles

	-- Brush lock mode (for interacting with handles)
	local brushLocked: boolean = false
	local lockedBrushPosition: Vector3? = nil

	-- Bridge tool state
	local bridgeStartPoint: Vector3? = nil
	local bridgeEndPoint: Vector3? = nil
	local bridgePreviewParts: { BasePart } = {}
	local bridgeWidth: number = 4 -- Voxels wide

	-- Forward declarations for handle functions (defined later, after brush viz)
	local updateHandlesAdornee
	local hideHandles
	local destroyHandles

	-- Config panels (will be populated later)
	local configPanels: { [string]: Frame } = {}
	local updateConfigPanelVisibility: (() -> ())? = nil

	-- ============================================================================
	-- Tool Config Definitions
	-- Define which settings each tool needs
	-- ============================================================================

	local ToolConfigs = {
		[ToolId.Add] = {
			"brushShape",
			"handleHint",
			"strength",
			"pivot",
			"spin",
			"hollow",
			"planeLock",
			"ignoreWater",
			"material",
		},
		[ToolId.Subtract] = {
			"brushShape",
			"handleHint",
			"strength",
			"pivot",
			"spin",
			"hollow",
			"planeLock",
			"ignoreWater",
		},
		[ToolId.Grow] = { "brushShape", "handleHint", "strength", "pivot", "spin", "hollow", "planeLock", "ignoreWater" },
		[ToolId.Erode] = { "brushShape", "handleHint", "strength", "pivot", "spin", "hollow", "planeLock", "ignoreWater" },
		[ToolId.Smooth] = {
			"brushShape",
			"handleHint",
			"strength",
			"pivot",
			"spin",
			"hollow",
			"planeLock",
			"ignoreWater",
		},
		[ToolId.Flatten] = {
			"brushShape",
			"handleHint",
			"strength",
			"pivot",
			"spin",
			"hollow",
			"planeLock",
			"ignoreWater",
			"flattenMode",
		},
		[ToolId.Paint] = { "brushShape", "handleHint", "strength", "spin", "hollow", "material", "autoMaterial" },
		[ToolId.Bridge] = { "bridgeInfo", "strength", "material" },
	}

	-- ============================================================================
	-- UI Helpers
	-- ============================================================================

	local function createLabel(parent: Frame, text: string, position: UDim2, size: UDim2): TextLabel
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

	local function createHeader(parent: Frame, text: string, position: UDim2): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = position
		label.Size = UDim2.new(1, 0, 0, 22)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 15
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = text
		label.Parent = parent
		return label
	end

	local function createButton(parent: Frame, text: string, position: UDim2, size: UDim2, callback: () -> ()): TextButton
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

	local function createSlider(
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
		container.Size = UDim2.new(1, 0, 0, 75)
		container.Parent = parent

		local labelText = createLabel(container, label .. ": " .. tostring(initial), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 18))

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

	local function createToolButton(parent: Frame, toolId: string, displayName: string, position: UDim2): TextButton
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

	local toolButtons = {}

	local function updateToolButtonVisuals()
		for toolId, button in pairs(toolButtons) do
			if toolId == currentTool then
				button.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
				button.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				button.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end

	local function selectTool(toolId: string)
		-- Clean up bridge preview if switching away from bridge tool
		if currentTool == ToolId.Bridge and toolId ~= ToolId.Bridge then
			bridgeStartPoint = nil
			bridgeEndPoint = nil
			for _, part in ipairs(bridgePreviewParts) do
				part:Destroy()
			end
			bridgePreviewParts = {}
		end

		if currentTool == toolId then
			currentTool = ToolId.None
			-- Deactivate plugin when no tool selected
			pluginInstance:Deactivate()
		else
			currentTool = toolId
			-- Activate plugin so mouse events work in 3D viewport
			pluginInstance:Activate(true)
		end
		updateToolButtonVisuals()
		if updateConfigPanelVisibility then
			updateConfigPanelVisibility()
		end
	end

	-- ============================================================================
	-- Brush Visualization
	-- ============================================================================

	-- Helper to create a small preview part with consistent styling
	local function createPreviewPart(shape: Enum.PartType?): Part
		local part = Instance.new("Part")
		part.Name = "TerrainBrushExtra"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		-- Use locked color (orange) or normal color (blue)
		part.Color = brushLocked and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(0, 162, 255)
		part.Transparency = 0.6
		if shape then
			part.Shape = shape
		end
		part.Parent = workspace
		return part
	end

	-- Clear extra preview parts
	local function clearExtraParts()
		for _, part in ipairs(brushExtraParts) do
			part:Destroy()
		end
		brushExtraParts = {}
	end

	local function createBrushVisualization()
		if brushPart then
			brushPart:Destroy()
		end
		clearExtraParts()

		-- Create appropriate part type based on shape
		if brushShape == BrushShape.Wedge then
			brushPart = Instance.new("WedgePart")
		elseif brushShape == BrushShape.CornerWedge then
			brushPart = Instance.new("CornerWedgePart")
		else
			brushPart = Instance.new("Part")
			if brushShape == BrushShape.Sphere or brushShape == BrushShape.Dome then
				brushPart.Shape = Enum.PartType.Ball
			elseif
				brushShape == BrushShape.Cube
				or brushShape == BrushShape.Grid
				or brushShape == BrushShape.ZigZag
				or brushShape == BrushShape.Spinner
			then
				brushPart.Shape = Enum.PartType.Block
			elseif
				brushShape == BrushShape.Cylinder
				or brushShape == BrushShape.Stick
				or brushShape == BrushShape.Torus
				or brushShape == BrushShape.Ring
				or brushShape == BrushShape.Sheet
			then
				brushPart.Shape = Enum.PartType.Cylinder
			end
		end

		brushPart.Name = "TerrainBrushVisualization"
		brushPart.Anchored = true
		brushPart.CanCollide = false
		brushPart.CanQuery = false
		brushPart.CanTouch = false
		brushPart.CastShadow = false
		brushPart.Transparency = 0.7
		brushPart.Material = Enum.Material.Neon
		brushPart.Color = Color3.fromRGB(0, 162, 255)

		brushPart.Parent = workspace
	end

	local function updateBrushVisualization(position: Vector3)
		if not brushPart then
			createBrushVisualization()
		end

		if brushPart then
			-- Calculate per-axis sizes in studs
			local sizeX = brushSizeX * Constants.VOXEL_RESOLUTION
			local sizeY = brushSizeY * Constants.VOXEL_RESOLUTION
			local sizeZ = brushSizeZ * Constants.VOXEL_RESOLUTION

			-- Opacity based on strength: low strength = more transparent, high strength = more solid
			-- brushStrength ranges 0.01-1.0, transparency ranges 0.85 (weak) to 0.35 (strong)
			brushPart.Transparency = 0.85 - (brushStrength * 0.5)

			-- Change color when locked (orange = locked, blue = normal)
			if brushLocked then
				brushPart.Color = Color3.fromRGB(255, 170, 0) -- Orange when locked
			else
				brushPart.Color = Color3.fromRGB(0, 162, 255) -- Blue when normal
			end

			-- Base CFrame at position
			local baseCFrame = CFrame.new(position)

			-- Update spin angle if spin mode is enabled (pauses when locked)
			if spinEnabled and not brushLocked then
				spinAngle = spinAngle + 0.05
			end

			-- Apply user rotation if shape supports it, then spin if enabled
			local finalCFrame = baseCFrame
			if ShapeSupportsRotation[brushShape] then
				finalCFrame = baseCFrame * brushRotation
			end
			if spinEnabled then
				local spinCFrame = CFrame.Angles(spinAngle * 0.7, spinAngle, spinAngle * 0.3)
				finalCFrame = finalCFrame * spinCFrame
			end

			if brushShape == BrushShape.Sphere then
				-- Sphere uses uniform size (X for all dimensions)
				brushPart.Size = Vector3.new(sizeX, sizeX, sizeX)
				brushPart.CFrame = finalCFrame
			elseif brushShape == BrushShape.Cube then
				-- Cube uses all three dimensions
				brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
				brushPart.CFrame = finalCFrame
			elseif brushShape == BrushShape.Cylinder then
				-- Cylinder: Part cylinder has height along X axis, so we rotate 90° to make it vertical
				-- Size = (height, diameter, diameter) after rotation becomes (diameter, height, diameter)
				-- X and Z are the radius (use sizeX), Y is the height (use sizeY)
				brushPart.Size = Vector3.new(sizeY, sizeX, sizeX)
				-- Apply base rotation to make cylinder vertical, then user rotation
				finalCFrame = baseCFrame * brushRotation * CFrame.Angles(0, 0, math.rad(90))
				brushPart.CFrame = finalCFrame
			elseif brushShape == BrushShape.Wedge then
				-- Wedge: slope goes from bottom-back to top-front
				brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
				brushPart.CFrame = finalCFrame
			elseif brushShape == BrushShape.CornerWedge then
				-- CornerWedge: triangular corner piece
				brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
				brushPart.CFrame = finalCFrame
			elseif brushShape == BrushShape.Dome then
				-- Dome: half-sphere, uses radius (X=Z) for width, Y for height
				-- Visualized as a ball (actual dome effect is in the brush operation)
				brushPart.Size = Vector3.new(sizeX, sizeY, sizeX)
				brushPart.CFrame = finalCFrame
			elseif brushShape == BrushShape.Torus then
				-- Torus: donut shape - use ring of spheres to show actual shape
				brushPart.Transparency = 1 -- Hide main part, use spheres instead
				brushPart.Size = Vector3.new(1, 1, 1)
				brushPart.CFrame = finalCFrame

				-- Create spheres around the ring
				clearExtraParts()
				local majorRadius = sizeX * 0.5
				local tubeRadius = sizeY * 0.5
				local segments = 12
				for i = 0, segments - 1 do
					local angle = (i / segments) * math.pi * 2
					local localPos = Vector3.new(math.cos(angle) * majorRadius, 0, math.sin(angle) * majorRadius)
					local worldPos = finalCFrame:PointToWorldSpace(localPos)

					local sphere = createPreviewPart(Enum.PartType.Ball)
					sphere.Size = Vector3.new(tubeRadius * 2, tubeRadius * 2, tubeRadius * 2)
					sphere.CFrame = CFrame.new(worldPos)
					table.insert(brushExtraParts, sphere)
				end
			elseif brushShape == BrushShape.Ring then
				-- Ring: flat washer - use cylinders to show the ring shape
				brushPart.Transparency = 1
				brushPart.Size = Vector3.new(1, 1, 1)
				brushPart.CFrame = finalCFrame

				clearExtraParts()
				local outerRadius = sizeX * 0.5
				local thickness = sizeY * 0.5
				local segments = 16
				for i = 0, segments - 1 do
					local angle = (i / segments) * math.pi * 2
					local nextAngle = ((i + 1) / segments) * math.pi * 2
					local midAngle = (angle + nextAngle) / 2
					local localPos = Vector3.new(math.cos(midAngle) * outerRadius * 0.85, 0, math.sin(midAngle) * outerRadius * 0.85)
					local worldPos = finalCFrame:PointToWorldSpace(localPos)

					local seg = createPreviewPart(Enum.PartType.Block)
					local segLength = outerRadius * 0.4
					seg.Size = Vector3.new(segLength, thickness, outerRadius * 0.15)
					seg.CFrame = CFrame.new(worldPos) * CFrame.Angles(0, -midAngle, 0)
					table.insert(brushExtraParts, seg)
				end
			elseif brushShape == BrushShape.ZigZag then
				-- ZigZag: Z-shaped pattern - show with angled boxes
				brushPart.Transparency = 1
				brushPart.Size = Vector3.new(1, 1, 1)
				brushPart.CFrame = finalCFrame

				clearExtraParts()
				local zigWidth = sizeX * 0.3
				-- Create Z shape with 3 boxes
				local box1 = createPreviewPart(Enum.PartType.Block)
				box1.Size = Vector3.new(sizeX, sizeY * 0.3, zigWidth)
				box1.CFrame = finalCFrame * CFrame.new(0, sizeY * 0.35, -sizeZ * 0.3)
				table.insert(brushExtraParts, box1)

				local box2 = createPreviewPart(Enum.PartType.Block)
				box2.Size = Vector3.new(sizeX, sizeY * 0.5, zigWidth)
				box2.CFrame = finalCFrame * CFrame.Angles(math.rad(45), 0, 0)
				table.insert(brushExtraParts, box2)

				local box3 = createPreviewPart(Enum.PartType.Block)
				box3.Size = Vector3.new(sizeX, sizeY * 0.3, zigWidth)
				box3.CFrame = finalCFrame * CFrame.new(0, -sizeY * 0.35, sizeZ * 0.3)
				table.insert(brushExtraParts, box3)
			elseif brushShape == BrushShape.Sheet then
				-- Sheet: curved surface - show with arc of boxes
				brushPart.Transparency = 1
				brushPart.Size = Vector3.new(1, 1, 1)
				brushPart.CFrame = finalCFrame

				clearExtraParts()
				local arcSegments = 8
				local sheetThickness = sizeZ * 0.1
				for i = 0, arcSegments - 1 do
					local t = (i / (arcSegments - 1)) - 0.5 -- -0.5 to 0.5
					local angle = t * math.pi * 0.5 -- Quarter arc
					local localPos = Vector3.new(0, math.sin(angle) * sizeY * 0.4, math.cos(angle) * sizeX * 0.4)
					local worldPos = finalCFrame:PointToWorldSpace(localPos)

					local seg = createPreviewPart(Enum.PartType.Block)
					seg.Size = Vector3.new(sizeX * 0.9, sizeY / arcSegments * 1.2, sheetThickness)
					seg.CFrame = CFrame.new(worldPos) * finalCFrame.Rotation * CFrame.Angles(angle, 0, 0)
					table.insert(brushExtraParts, seg)
				end
			elseif brushShape == BrushShape.Grid then
				-- Grid: 3D checkerboard - show actual grid pattern
				brushPart.Transparency = 1
				brushPart.Size = Vector3.new(1, 1, 1)
				brushPart.CFrame = finalCFrame

				clearExtraParts()
				local gridSize = 3 -- 3x3x3 grid
				local cellSize = sizeX / gridSize
				for gx = 0, gridSize - 1 do
					for gy = 0, gridSize - 1 do
						for gz = 0, gridSize - 1 do
							-- Checkerboard pattern
							if (gx + gy + gz) % 2 == 0 then
								local localPos = Vector3.new(
									(gx - (gridSize - 1) / 2) * cellSize,
									(gy - (gridSize - 1) / 2) * cellSize,
									(gz - (gridSize - 1) / 2) * cellSize
								)
								local worldPos = finalCFrame:PointToWorldSpace(localPos)

								local cell = createPreviewPart(Enum.PartType.Block)
								cell.Size = Vector3.new(cellSize * 0.9, cellSize * 0.9, cellSize * 0.9)
								cell.CFrame = CFrame.new(worldPos) * finalCFrame.Rotation
								table.insert(brushExtraParts, cell)
							end
						end
					end
				end
			elseif brushShape == BrushShape.Stick then
				-- Stick: long thin rod - already well represented by cylinder
				brushPart.Size = Vector3.new(sizeY, sizeX * 0.3, sizeX * 0.3)
				finalCFrame = baseCFrame * brushRotation * CFrame.Angles(0, 0, math.rad(90))
				brushPart.CFrame = finalCFrame
			elseif brushShape == BrushShape.Spikepad then
				-- Spikepad: base platform with spike cones
				local baseHeight = sizeY * 0.15
				brushPart.Size = Vector3.new(sizeX, baseHeight, sizeZ)
				brushPart.CFrame = finalCFrame * CFrame.new(0, -sizeY * 0.5 + baseHeight * 0.5, 0)

				-- Add spike cones using wedges arranged in a pattern
				clearExtraParts()
				local spikeHeight = sizeY * 0.85
				local spikeRadius = math.min(sizeX, sizeZ) * 0.12
				local cols = 3
				local rows = 3
				for col = 0, cols - 1 do
					for row = 0, rows - 1 do
						local xPos = (col - (cols - 1) / 2) * (sizeX * 0.33)
						local zPos = (row - (rows - 1) / 2) * (sizeZ * 0.33)
						local spikeBase = finalCFrame * CFrame.new(xPos, -sizeY * 0.5 + baseHeight, zPos)

						-- Create a cone-like spike using 4 wedges
						for wedgeIdx = 0, 3 do
							local wedge = Instance.new("WedgePart")
							wedge.Name = "TerrainBrushExtra"
							wedge.Anchored = true
							wedge.CanCollide = false
							wedge.CanQuery = false
							wedge.CastShadow = false
							wedge.Material = Enum.Material.Neon
							wedge.Color = Color3.fromRGB(0, 162, 255)
							wedge.Transparency = 0.6
							wedge.Size = Vector3.new(spikeRadius, spikeHeight, spikeRadius)
							wedge.CFrame = spikeBase * CFrame.new(0, spikeHeight * 0.5, 0) * CFrame.Angles(0, math.rad(90 * wedgeIdx), 0)
							wedge.Parent = workspace
							table.insert(brushExtraParts, wedge)
						end
					end
				end
			end

			-- Make brush more transparent when hollow mode is enabled
			if hollowEnabled then
				brushPart.Transparency = math.max(brushPart.Transparency, 0.7)
			end

			-- Update extra parts color based on locked state and hollow mode
			local extraColor = brushLocked and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(0, 162, 255)
			for _, extraPart in ipairs(brushExtraParts) do
				extraPart.Color = extraColor
				if hollowEnabled then
					extraPart.Transparency = math.max(extraPart.Transparency, 0.7)
				end
			end

			-- Update 3D handles to follow the brush
			updateHandlesAdornee()
		end
	end

	local function hideBrushVisualization()
		if brushPart then
			brushPart:Destroy()
			brushPart = nil
		end
		-- Clean up extra parts for complex shapes
		for _, part in ipairs(brushExtraParts) do
			part:Destroy()
		end
		brushExtraParts = {}
		hideHandles()
	end

	-- ============================================================================
	-- 3D Handles for Rotation and Sizing
	-- ============================================================================

	-- Track cumulative rotation during drag (ArcHandles gives relative angles)
	local dragStartRotation = CFrame.new()

	local function createRotationHandles()
		if rotationHandles then
			rotationHandles:Destroy()
		end

		rotationHandles = Instance.new("ArcHandles")
		rotationHandles.Name = "BrushRotationHandles"
		rotationHandles.Color3 = Color3.fromRGB(255, 170, 0) -- Orange to stand out
		rotationHandles.Visible = false -- Start hidden, show when brush is visible
		rotationHandles.Parent = CoreGui

		-- Mouse button down - start drag
		rotationHandles.MouseButton1Down:Connect(function()
			isHandleDragging = true
			dragStartRotation = brushRotation
		end)

		-- Mouse button up - end drag
		rotationHandles.MouseButton1Up:Connect(function()
			isHandleDragging = false
		end)

		-- Mouse drag - apply rotation
		rotationHandles.MouseDrag:Connect(function(axis, relativeAngle, deltaRadius)
			-- relativeAngle is cumulative from drag start, in radians
			local rotationAxis
			if axis == Enum.Axis.X then
				rotationAxis = Vector3.new(1, 0, 0)
			elseif axis == Enum.Axis.Y then
				rotationAxis = Vector3.new(0, 1, 0)
			else -- Z
				rotationAxis = Vector3.new(0, 0, 1)
			end

			-- Apply rotation relative to drag start
			brushRotation = dragStartRotation * CFrame.fromAxisAngle(rotationAxis, relativeAngle)
		end)
	end

	local function createSizeHandles()
		if sizeHandles then
			sizeHandles:Destroy()
		end

		sizeHandles = Instance.new("Handles")
		sizeHandles.Name = "BrushSizeHandles"
		sizeHandles.Color3 = Color3.fromRGB(0, 200, 255) -- Cyan
		sizeHandles.Style = Enum.HandlesStyle.Resize
		sizeHandles.Visible = false
		sizeHandles.Parent = CoreGui

		-- Track drag start values
		local dragStartSizeX = brushSizeX
		local dragStartSizeY = brushSizeY
		local dragStartSizeZ = brushSizeZ

		sizeHandles.MouseButton1Down:Connect(function()
			isHandleDragging = true
			dragStartSizeX = brushSizeX
			dragStartSizeY = brushSizeY
			dragStartSizeZ = brushSizeZ
		end)

		sizeHandles.MouseButton1Up:Connect(function()
			isHandleDragging = false
		end)

		sizeHandles.MouseDrag:Connect(function(face, distance)
			-- Convert distance from studs to voxel units
			local deltaVoxels = distance / Constants.VOXEL_RESOLUTION
			local sizingMode = ShapeSizingMode[brushShape] or "uniform"

			-- For shapes with axis swaps (Cylinder, Torus, Ring, Sheet, Stick), the Part's
			-- axes don't match the brush's logical axes. We need to map correctly:
			-- - Cylinder/Stick: Part.Size = (sizeY, sizeX, sizeX) + 90° Z rotation
			--   So Part's Right/Left (±X) = height (sizeY), Top/Bottom/Front/Back = radius (sizeX)
			-- - Torus/Ring: Part.Size = (sizeY, sizeX*2, sizeX*2) + 90° Z rotation
			--   So Part's Right/Left = tube thickness (sizeY), others = major radius (sizeX)
			-- - Sheet: Part.Size = (sizeZ*0.2, sizeX*2, sizeY*2) + 90° Z rotation

			if sizingMode == "uniform" then
				-- Sphere/Grid: all axes change together
				local newSize = math.clamp(dragStartSizeX + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				brushSizeX = newSize
				brushSizeY = newSize
				brushSizeZ = newSize
			elseif sizingMode == "cylinder" then
				-- Cylinder/Stick/Dome: Part's X = height (sizeY), Part's Y/Z = radius (sizeX)
				-- Due to 90° Z rotation: visually top/bottom = Part's Right/Left
				if face == Enum.NormalId.Right or face == Enum.NormalId.Left then
					-- Dragging the visual top/bottom = height
					brushSizeY = math.clamp(dragStartSizeY + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				else
					-- Dragging the visual sides = radius
					local newRadius = math.clamp(dragStartSizeX + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
					brushSizeX = newRadius
					brushSizeZ = newRadius
				end
			elseif sizingMode == "torus" then
				-- Torus/Ring: Part's X = tube/thickness (sizeY), Part's Y/Z = major radius (sizeX)
				if face == Enum.NormalId.Right or face == Enum.NormalId.Left then
					-- Dragging the visual "thickness" direction
					brushSizeY = math.clamp(dragStartSizeY + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				else
					-- Dragging the major radius
					local newRadius = math.clamp(dragStartSizeX + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
					brushSizeX = newRadius
					brushSizeZ = newRadius
				end
			else -- "box" mode (Cube, Wedge, CornerWedge, ZigZag, Spikepad, etc.)
				-- Standard mapping: each face changes its corresponding axis
				if face == Enum.NormalId.Right or face == Enum.NormalId.Left then
					brushSizeX = math.clamp(dragStartSizeX + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
					brushSizeY = math.clamp(dragStartSizeY + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				else -- Front/Back
					brushSizeZ = math.clamp(dragStartSizeZ + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				end
			end
		end)
	end

	updateHandlesAdornee = function()
		if rotationHandles then
			rotationHandles.Adornee = brushPart
			rotationHandles.Visible = brushPart ~= nil and ShapeSupportsRotation[brushShape] == true
		end
		if sizeHandles then
			sizeHandles.Adornee = brushPart
			sizeHandles.Visible = brushPart ~= nil
		end
	end

	hideHandles = function()
		if rotationHandles then
			rotationHandles.Visible = false
			rotationHandles.Adornee = nil
		end
		if sizeHandles then
			sizeHandles.Visible = false
			sizeHandles.Adornee = nil
		end
		isHandleDragging = false
	end

	destroyHandles = function()
		if rotationHandles then
			rotationHandles:Destroy()
			rotationHandles = nil
		end
		if sizeHandles then
			sizeHandles:Destroy()
			sizeHandles = nil
		end
		isHandleDragging = false
	end

	-- Create handles at startup
	createRotationHandles()
	createSizeHandles()

	-- ============================================================================
	-- Plane Visualization
	-- ============================================================================

	local PLANE_SIZE = 200 -- Size of the visual plane indicator

	local function createPlaneVisualization()
		if planePart then
			planePart:Destroy()
		end

		planePart = Instance.new("Part")
		planePart.Name = "TerrainPlaneLockVisualization"
		planePart.Anchored = true
		planePart.CanCollide = false
		planePart.CanQuery = false
		planePart.CanTouch = false
		planePart.CastShadow = false
		planePart.Shape = Enum.PartType.Cylinder
		planePart.Size = Vector3.new(0.5, PLANE_SIZE, PLANE_SIZE) -- Thin disc
		planePart.Transparency = 0.85
		planePart.Material = Enum.Material.Neon
		planePart.Color = Color3.fromRGB(0, 200, 100) -- Green to distinguish from brush
		planePart.Parent = workspace
	end

	local function updatePlaneVisualization(centerX: number, centerZ: number)
		if not planePart then
			createPlaneVisualization()
		end

		if planePart then
			-- Position the disc at the locked plane height, centered on cursor X/Z
			planePart.CFrame = CFrame.new(centerX, planePositionY, centerZ) * CFrame.Angles(0, 0, math.rad(90)) -- Rotate to be horizontal
		end
	end

	local function hidePlaneVisualization()
		if planePart then
			planePart:Destroy()
			planePart = nil
		end
	end

	-- ============================================================================
	-- Terrain Operations
	-- ============================================================================

	-- Helper to intersect ray with the locked horizontal plane
	local function intersectPlane(ray: any): Vector3?
		if ray.Direction.Y ~= 0 then
			local t = (planePositionY - ray.Origin.Y) / ray.Direction.Y
			if t > 0 and t < 1000 then
				return ray.Origin + ray.Direction * t
			end
		end
		return nil
	end

	local function getTerrainHit(): Vector3?
		local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { brushPart, planePart }

		-- Check if plane lock should constrain cursor position
		local usePlaneLock = (planeLockMode == PlaneLockType.Manual) or (planeLockMode == PlaneLockType.Auto and autoPlaneActive)

		if usePlaneLock then
			-- When plane locked, cursor slides along the plane
			local planeHit = intersectPlane(ray)
			if planeHit then
				return planeHit
			end
		end

		-- Try hitting existing terrain
		local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
		if result and result.Instance == terrain then
			return result.Position
		end

		-- Hit any other object (baseplate, parts, etc)
		if result then
			return result.Position
		end

		-- Fallback: intersect with Y=0 plane (ground level)
		if ray.Direction.Y ~= 0 then
			local t = -ray.Origin.Y / ray.Direction.Y
			if t > 0 and t < 1000 then
				return ray.Origin + ray.Direction * t
			end
		end

		-- Last resort: use mouse.Hit or a point in front of camera
		if mouse.Hit then
			return mouse.Hit.Position
		end

		-- Place at a fixed distance from camera
		return ray.Origin + ray.Direction * 50
	end

	-- Get terrain hit WITHOUT plane lock (for sampling height in Auto mode)
	local function getTerrainHitRaw(): Vector3?
		local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { brushPart, planePart }

		local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
		if result then
			return result.Position
		end

		-- Fallback: intersect with Y=0 plane
		if ray.Direction.Y ~= 0 then
			local t = -ray.Origin.Y / ray.Direction.Y
			if t > 0 and t < 1000 then
				return ray.Origin + ray.Direction * t
			end
		end

		return nil
	end

	local function performBrushOperation(position: Vector3)
		local usePlaneLock = (planeLockMode == PlaneLockType.Manual) or (planeLockMode == PlaneLockType.Auto and autoPlaneActive)
		local planePoint = usePlaneLock and Vector3.new(position.X, planePositionY, position.Z) or position
		local planeNormal = Vector3.new(0, 1, 0)

		-- Determine actual sizes based on shape's sizing mode
		local actualSizeX = brushSizeX
		local actualSizeY = brushSizeY
		local actualSizeZ = brushSizeZ

		local sizingMode = ShapeSizingMode[brushShape] or "uniform"
		if sizingMode == "uniform" then
			-- Sphere: use X for all dimensions
			actualSizeY = brushSizeX
			actualSizeZ = brushSizeX
		elseif sizingMode == "cylinder" then
			-- Cylinder: X is radius, Y is height, Z matches X
			actualSizeZ = brushSizeX
		elseif sizingMode == "torus" then
			-- Torus: X is major radius, Y is minor radius (tube), Z matches X
			actualSizeZ = brushSizeX
		end
		-- "box" mode: use all three independently (no changes needed)

		-- Handle rotation: user rotation + spin mode
		local effectiveRotation = brushRotation
		if not ShapeSupportsRotation[brushShape] then
			effectiveRotation = CFrame.new()
		end
		-- Apply spin if enabled
		if spinEnabled then
			spinAngle = spinAngle + 0.1
			local spinCFrame = CFrame.Angles(spinAngle * 0.7, spinAngle, spinAngle * 0.3)
			effectiveRotation = effectiveRotation * spinCFrame
		end

		local opSet = {
			currentTool = currentTool,
			brushShape = brushShape,
			flattenMode = flattenMode,
			pivot = pivotType,
			centerPoint = position,
			planePoint = planePoint,
			planeNormal = planeNormal,
			cursorSizeX = actualSizeX,
			cursorSizeY = actualSizeY,
			cursorSizeZ = actualSizeZ,
			-- Legacy fields for backward compatibility
			cursorSize = actualSizeX,
			cursorHeight = actualSizeY,
			strength = brushStrength,
			autoMaterial = autoMaterial,
			material = brushMaterial,
			ignoreWater = ignoreWater,
			source = Enum.Material.Grass,
			target = brushMaterial,
			-- Rotation (uses effective rotation for spinner, user rotation for others)
			brushRotation = effectiveRotation,
			-- Hollow mode
			hollowEnabled = hollowEnabled,
			wallThickness = wallThickness,
		}

		if DEBUG then
			print("[DEBUG] About to call performTerrainBrushOperation")
		end
		local success, err = pcall(function()
			performTerrainBrushOperation(terrain, opSet)
		end)
		if DEBUG then
			print("[DEBUG] performTerrainBrushOperation returned, success =", success)
		end

		if not success then
			warn("[TerrainEditorFork] Brush operation failed:", err)
		end
	end

	local function startBrushing()
		if brushConnection then
			return
		end

		ChangeHistoryService:SetWaypoint("TerrainEdit_Start")

		brushConnection = RunService.Heartbeat:Connect(function()
			-- Don't paint if mouse isn't down, no tool selected, dragging handles, or brush is locked
			if not isMouseDown or currentTool == ToolId.None or isHandleDragging or brushLocked then
				return
			end

			-- Rate limit brush operations
			local now = tick()
			if now - lastBrushTime < BRUSH_COOLDOWN then
				return
			end
			lastBrushTime = now

			local hitPosition = getTerrainHit()
			if hitPosition then
				performBrushOperation(hitPosition)
				lastBrushPosition = hitPosition
			end
		end)
	end

	local function stopBrushing()
		if brushConnection then
			brushConnection:Disconnect()
			brushConnection = nil
		end
		ChangeHistoryService:SetWaypoint("TerrainEdit_End")
		lastBrushPosition = nil
	end

	-- ============================================================================
	-- Build UI
	-- ============================================================================

	local mainFrame = Instance.new("ScrollingFrame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromScale(1, 1)
	mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	mainFrame.BorderSizePixel = 0
	mainFrame.ScrollBarThickness = 6
	mainFrame.CanvasSize = UDim2.new(0, 0, 0, 1200)
	mainFrame.Parent = parentGui

	-- Version label in upper right (faint)
	local versionLabel = Instance.new("TextLabel")
	versionLabel.Name = "VersionLabel"
	versionLabel.BackgroundTransparency = 1
	versionLabel.Position = UDim2.new(1, -8, 0, 4)
	versionLabel.Size = UDim2.new(0, 100, 0, 14)
	versionLabel.AnchorPoint = Vector2.new(1, 0) -- Anchor to right
	versionLabel.Font = Enum.Font.Gotham
	versionLabel.TextSize = 10
	versionLabel.TextColor3 = Color3.fromRGB(120, 120, 120) -- Faint grey
	versionLabel.TextXAlignment = Enum.TextXAlignment.Right
	versionLabel.Text = "v" .. VERSION
	versionLabel.ZIndex = 10 -- Above scroll content
	versionLabel.Parent = parentGui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 18)
	padding.PaddingTop = UDim.new(0, 10)
	padding.Parent = mainFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 0, 0, 0)
	title.Size = UDim2.new(1, 0, 0, 24)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "🌋 Terrain Editor Fork v" .. VERSION
	title.Parent = mainFrame

	-- ============================================================================
	-- Tool Selection Section
	-- ============================================================================

	createHeader(mainFrame, "Sculpt Tools", UDim2.new(0, 0, 0, 40))

	local sculptTools = {
		{ id = ToolId.Add, name = "Add", row = 0, col = 0 },
		{ id = ToolId.Subtract, name = "Subtract", row = 0, col = 1 },
		{ id = ToolId.Grow, name = "Grow", row = 0, col = 2 },
		{ id = ToolId.Erode, name = "Erode", row = 1, col = 0 },
		{ id = ToolId.Smooth, name = "Smooth", row = 1, col = 1 },
		{ id = ToolId.Flatten, name = "Flatten", row = 1, col = 2 },
	}

	for _, toolInfo in ipairs(sculptTools) do
		local pos = UDim2.new(0, toolInfo.col * 78, 0, 65 + toolInfo.row * 40)
		local btn = createToolButton(mainFrame, toolInfo.id, toolInfo.name, pos)
		toolButtons[toolInfo.id] = btn
		btn.MouseButton1Click:Connect(function()
			selectTool(toolInfo.id)
		end)
	end

	createHeader(mainFrame, "Other Tools", UDim2.new(0, 0, 0, 155))
	local paintBtn = createToolButton(mainFrame, ToolId.Paint, "Paint", UDim2.new(0, 0, 0, 180))
	toolButtons[ToolId.Paint] = paintBtn
	paintBtn.MouseButton1Click:Connect(function()
		selectTool(ToolId.Paint)
	end)

	local bridgeBtn = createToolButton(mainFrame, ToolId.Bridge, "Bridge", UDim2.new(0, 78, 0, 180))
	toolButtons[ToolId.Bridge] = bridgeBtn
	bridgeBtn.MouseButton1Click:Connect(function()
		selectTool(ToolId.Bridge)
	end)

	-- ============================================================================
	-- Config Panels Container (starts after tool buttons)
	-- ============================================================================

	local CONFIG_START_Y = 230

	local configContainer = Instance.new("Frame")
	configContainer.Name = "ConfigContainer"
	configContainer.BackgroundTransparency = 1
	configContainer.Position = UDim2.new(0, 0, 0, CONFIG_START_Y)
	configContainer.Size = UDim2.new(1, 0, 0, 800)
	configContainer.Parent = mainFrame

	-- Helper to create a config section
	local function createConfigPanel(name: string): Frame
		local panel = Instance.new("Frame")
		panel.Name = name
		panel.BackgroundTransparency = 1
		panel.Size = UDim2.new(1, 0, 0, 0) -- Height will be set by UIListLayout
		panel.AutomaticSize = Enum.AutomaticSize.Y
		panel.Visible = false
		panel.Parent = configContainer

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = panel

		return panel
	end

	-- ============================================================================
	-- Create Individual Config Panels
	-- ============================================================================

	-- Brush Shape Panel
	local shapePanel = createConfigPanel("brushShape")
	local shapeHeader = createHeader(shapePanel, "Brush Shape", UDim2.new(0, 0, 0, 0))
	shapeHeader.LayoutOrder = 1

	local shapeButtonsContainer = Instance.new("Frame")
	shapeButtonsContainer.BackgroundTransparency = 1
	shapeButtonsContainer.Size = UDim2.new(1, 0, 0, 0)
	shapeButtonsContainer.AutomaticSize = Enum.AutomaticSize.Y
	shapeButtonsContainer.LayoutOrder = 2
	shapeButtonsContainer.Parent = shapePanel

	-- Use UIGridLayout for wrapping buttons
	local shapeGridLayout = Instance.new("UIGridLayout")
	shapeGridLayout.CellSize = UDim2.new(0, 70, 0, 28)
	shapeGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	shapeGridLayout.FillDirection = Enum.FillDirection.Horizontal
	shapeGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	shapeGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	shapeGridLayout.Parent = shapeButtonsContainer

	-- Standard shapes
	local shapes = {
		{ id = BrushShape.Sphere, name = "Sphere" },
		{ id = BrushShape.Cube, name = "Cube" },
		{ id = BrushShape.Cylinder, name = "Cyl" },
		{ id = BrushShape.Wedge, name = "Wedge" },
		{ id = BrushShape.CornerWedge, name = "Corner" },
		{ id = BrushShape.Dome, name = "Dome" },
		-- Creative shapes (new row)
		{ id = BrushShape.Torus, name = "Torus" },
		{ id = BrushShape.Ring, name = "Ring" },
		{ id = BrushShape.ZigZag, name = "ZigZag" },
		{ id = BrushShape.Sheet, name = "Sheet" },
		{ id = BrushShape.Grid, name = "Grid" },
		{ id = BrushShape.Stick, name = "Stick" },
		{ id = BrushShape.Spikepad, name = "Spikes" },
	}
	local shapeButtons = {}

	local function updateShapeButtons()
		for shapeId, btn in pairs(shapeButtons) do
			if shapeId == brushShape then
				btn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end

	for i, shapeInfo in ipairs(shapes) do
		local btn = createButton(
			shapeButtonsContainer,
			shapeInfo.name,
			UDim2.new(0, 0, 0, 0), -- Position handled by grid layout
			UDim2.new(0, 70, 0, 28),
			function()
				brushShape = shapeInfo.id
				updateShapeButtons()
				-- Recreate brush visualization for the new shape
				if brushPart then
					createBrushVisualization()
				end
			end
		)
		btn.LayoutOrder = i -- For grid layout ordering
		shapeButtons[shapeInfo.id] = btn
	end
	updateShapeButtons()

	configPanels["brushShape"] = shapePanel

	-- Handle Hint Panel - prominent instruction to press R
	local handleHintPanel = createConfigPanel("handleHint")

	-- Container for the hint (centered)
	local hintContainer = Instance.new("Frame")
	hintContainer.BackgroundTransparency = 1
	hintContainer.Size = UDim2.new(1, 0, 0, 0)
	hintContainer.AutomaticSize = Enum.AutomaticSize.Y
	hintContainer.LayoutOrder = 1
	hintContainer.Parent = handleHintPanel

	local hintLayout = Instance.new("UIListLayout")
	hintLayout.FillDirection = Enum.FillDirection.Horizontal
	hintLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hintLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hintLayout.Padding = UDim.new(0, 8)
	hintLayout.Parent = hintContainer

	-- "Press" text
	local pressLabel = Instance.new("TextLabel")
	pressLabel.BackgroundTransparency = 1
	pressLabel.Size = UDim2.new(0, 0, 0, 32)
	pressLabel.AutomaticSize = Enum.AutomaticSize.X
	pressLabel.Font = Enum.Font.GothamMedium
	pressLabel.TextSize = 15
	pressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	pressLabel.Text = "Press"
	pressLabel.LayoutOrder = 1
	pressLabel.Parent = hintContainer

	-- Big "R" key badge
	local keyBadge = Instance.new("Frame")
	keyBadge.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
	keyBadge.Size = UDim2.new(0, 36, 0, 32)
	keyBadge.LayoutOrder = 2
	keyBadge.Parent = hintContainer

	local keyBadgeCorner = Instance.new("UICorner")
	keyBadgeCorner.CornerRadius = UDim.new(0, 6)
	keyBadgeCorner.Parent = keyBadge

	local keyLabel = Instance.new("TextLabel")
	keyLabel.BackgroundTransparency = 1
	keyLabel.Size = UDim2.new(1, 0, 1, 0)
	keyLabel.Font = Enum.Font.GothamBlack
	keyLabel.TextSize = 20
	keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	keyLabel.Text = "R"
	keyLabel.Parent = keyBadge

	-- "to lock brush" text
	local toLockLabel = Instance.new("TextLabel")
	toLockLabel.BackgroundTransparency = 1
	toLockLabel.Size = UDim2.new(0, 0, 0, 32)
	toLockLabel.AutomaticSize = Enum.AutomaticSize.X
	toLockLabel.Font = Enum.Font.GothamMedium
	toLockLabel.TextSize = 15
	toLockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	toLockLabel.Text = "to lock brush"
	toLockLabel.LayoutOrder = 3
	toLockLabel.Parent = hintContainer

	-- Subtext explaining what happens
	local subtextLabel = Instance.new("TextLabel")
	subtextLabel.BackgroundTransparency = 1
	subtextLabel.Size = UDim2.new(1, 0, 0, 0)
	subtextLabel.AutomaticSize = Enum.AutomaticSize.Y
	subtextLabel.Font = Enum.Font.Gotham
	subtextLabel.TextSize = 13
	subtextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	subtextLabel.TextWrapped = true
	subtextLabel.TextXAlignment = Enum.TextXAlignment.Center
	subtextLabel.Text = "Then drag handles to resize and rotate"
	subtextLabel.LayoutOrder = 2
	subtextLabel.Parent = handleHintPanel

	configPanels["handleHint"] = handleHintPanel

	-- Strength Panel
	local strengthPanel = createConfigPanel("strength")
	local strengthHeader = createHeader(strengthPanel, "Strength", UDim2.new(0, 0, 0, 0))
	strengthHeader.LayoutOrder = 1

	local _strengthSliderLabel, strengthSliderContainer, setStrengthValue = createSlider(
		strengthPanel,
		"Strength",
		1,
		100,
		math.floor(brushStrength * 100),
		function(value)
			brushStrength = value / 100
		end
	)
	strengthSliderContainer.LayoutOrder = 2

	configPanels["strength"] = strengthPanel

	-- Pivot Panel
	local pivotPanel = createConfigPanel("pivot")
	local pivotHeader = createHeader(pivotPanel, "Pivot Position", UDim2.new(0, 0, 0, 0))
	pivotHeader.LayoutOrder = 1

	local pivotButtonsContainer = Instance.new("Frame")
	pivotButtonsContainer.BackgroundTransparency = 1
	pivotButtonsContainer.Size = UDim2.new(1, 0, 0, 35)
	pivotButtonsContainer.LayoutOrder = 2
	pivotButtonsContainer.Parent = pivotPanel

	local pivots = {
		{ id = PivotType.Bottom, name = "Bottom" },
		{ id = PivotType.Center, name = "Center" },
		{ id = PivotType.Top, name = "Top" },
	}
	local pivotButtons = {}

	local function updatePivotButtons()
		for pivotId, btn in pairs(pivotButtons) do
			if pivotId == pivotType then
				btn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end

	for i, pivotInfo in ipairs(pivots) do
		local btn = createButton(
			pivotButtonsContainer,
			pivotInfo.name,
			UDim2.new(0, (i - 1) * 78, 0, 0),
			UDim2.new(0, 70, 0, 28),
			function()
				pivotType = pivotInfo.id
				updatePivotButtons()
			end
		)
		pivotButtons[pivotInfo.id] = btn
	end
	updatePivotButtons()

	configPanels["pivot"] = pivotPanel

	-- Spin Mode Toggle
	local spinPanel = createConfigPanel("spin")
	local spinHeader = createHeader(spinPanel, "Spin Mode", UDim2.new(0, 0, 0, 0))
	spinHeader.LayoutOrder = 1

	local spinToggleBtn: TextButton? = nil

	local function updateSpinButton()
		if spinToggleBtn then
			if spinEnabled then
				spinToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0) -- Orange when spinning
				spinToggleBtn.Text = "SPINNING"
			else
				spinToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				spinToggleBtn.Text = "Off"
			end
		end
	end

	spinToggleBtn = createButton(spinPanel, "Off", UDim2.new(0, 0, 0, 0), UDim2.new(0, 120, 0, 28), function()
		spinEnabled = not spinEnabled
		if not spinEnabled then
			spinAngle = 0 -- Reset angle when disabled
		end
		updateSpinButton()
	end)
	spinToggleBtn.LayoutOrder = 2
	updateSpinButton()

	configPanels["spin"] = spinPanel

	-- Hollow Mode Panel
	local hollowPanel = createConfigPanel("hollow")
	local hollowHeader = createHeader(hollowPanel, "Hollow Mode", UDim2.new(0, 0, 0, 0))
	hollowHeader.LayoutOrder = 1

	local hollowToggleBtn: TextButton? = nil
	local hollowThicknessContainer: Frame? = nil

	local function updateHollowButton()
		if hollowToggleBtn then
			if hollowEnabled then
				hollowToggleBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 150) -- Purple when hollow
				hollowToggleBtn.Text = "HOLLOW"
			else
				hollowToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				hollowToggleBtn.Text = "Solid"
			end
		end
		-- Show/hide thickness slider
		if hollowThicknessContainer then
			hollowThicknessContainer.Visible = hollowEnabled
		end
	end

	hollowToggleBtn = createButton(hollowPanel, "Solid", UDim2.new(0, 0, 0, 0), UDim2.new(0, 100, 0, 28), function()
		hollowEnabled = not hollowEnabled
		updateHollowButton()
	end)
	hollowToggleBtn.LayoutOrder = 2

	-- Wall thickness slider (only visible when hollow is enabled)
	local _, thicknessSliderContainer, setThickness = createSlider(
		hollowPanel,
		"Thickness",
		10,
		50,
		math.floor(wallThickness * 100),
		function(val)
			wallThickness = val / 100 -- Convert 10-50 to 0.1-0.5
		end
	)
	thicknessSliderContainer.LayoutOrder = 3
	hollowThicknessContainer = thicknessSliderContainer
	hollowThicknessContainer.Visible = false -- Hidden by default

	updateHollowButton()

	configPanels["hollow"] = hollowPanel

	-- Plane Lock Panel
	local planeLockPanel = createConfigPanel("planeLock")
	local planeLockHeader = createHeader(planeLockPanel, "Plane Lock", UDim2.new(0, 0, 0, 0))
	planeLockHeader.LayoutOrder = 1

	-- Mode buttons container (Off / Auto / Manual)
	local planeLockModeContainer = Instance.new("Frame")
	planeLockModeContainer.BackgroundTransparency = 1
	planeLockModeContainer.Size = UDim2.new(1, 0, 0, 28)
	planeLockModeContainer.LayoutOrder = 2
	planeLockModeContainer.Parent = planeLockPanel

	local planeLockModeButtons = {}

	-- Manual mode controls container (created first so updatePlaneLockVisuals can reference it)
	local manualControlsContainer = Instance.new("Frame")
	manualControlsContainer.Name = "ManualControls"
	manualControlsContainer.BackgroundTransparency = 1
	manualControlsContainer.Size = UDim2.new(1, 0, 0, 0)
	manualControlsContainer.AutomaticSize = Enum.AutomaticSize.Y
	manualControlsContainer.LayoutOrder = 3
	manualControlsContainer.Parent = planeLockPanel

	local manualLayout = Instance.new("UIListLayout")
	manualLayout.SortOrder = Enum.SortOrder.LayoutOrder
	manualLayout.Padding = UDim.new(0, 8)
	manualLayout.Parent = manualControlsContainer

	-- Define update functions before buttons that use them
	local function updatePlaneLockModeButtons()
		for modeId, btn in pairs(planeLockModeButtons) do
			if modeId == planeLockMode then
				btn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end

	local function updatePlaneLockVisuals()
		manualControlsContainer.Visible = (planeLockMode == PlaneLockType.Manual)

		-- Hide plane visualization when mode is Off
		if planeLockMode == PlaneLockType.Off then
			hidePlaneVisualization()
		end
	end

	-- Create mode buttons
	local planeLockModes = {
		{ id = PlaneLockType.Off, name = "Off" },
		{ id = PlaneLockType.Auto, name = "Auto" },
		{ id = PlaneLockType.Manual, name = "Manual" },
	}

	for i, modeInfo in ipairs(planeLockModes) do
		local btn = createButton(
			planeLockModeContainer,
			modeInfo.name,
			UDim2.new(0, (i - 1) * 78, 0, 0),
			UDim2.new(0, 70, 0, 28),
			function()
				planeLockMode = modeInfo.id
				autoPlaneActive = false -- Reset auto plane when changing modes
				updatePlaneLockModeButtons()
				updatePlaneLockVisuals()
			end
		)
		planeLockModeButtons[modeInfo.id] = btn
	end

	-- Plane height slider (only for Manual mode)
	local _planeHeightLabel, planeHeightContainer, setPlaneHeightValue = createSlider(
		manualControlsContainer,
		"Height",
		-100,
		500,
		planePositionY,
		function(value)
			planePositionY = value
		end
	)
	planeHeightContainer.LayoutOrder = 1

	-- Set from cursor button
	local setHeightBtnContainer = Instance.new("Frame")
	setHeightBtnContainer.BackgroundTransparency = 1
	setHeightBtnContainer.Size = UDim2.new(1, 0, 0, 28)
	setHeightBtnContainer.LayoutOrder = 2
	setHeightBtnContainer.Parent = manualControlsContainer

	local setHeightBtn = createButton(
		setHeightBtnContainer,
		"Set from Cursor",
		UDim2.new(0, 0, 0, 0),
		UDim2.new(0, 120, 0, 28),
		function() end
	)
	setHeightBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

	-- Set Height button samples current terrain hit position
	setHeightBtn.MouseButton1Click:Connect(function()
		local hitPosition = getTerrainHitRaw()
		if hitPosition then
			planePositionY = math.floor(hitPosition.Y + 0.5)
			setPlaneHeightValue(planePositionY)
		end
	end)

	-- Initialize button states
	updatePlaneLockModeButtons()
	updatePlaneLockVisuals()

	configPanels["planeLock"] = planeLockPanel

	-- Ignore Water Panel
	local ignoreWaterPanel = createConfigPanel("ignoreWater")
	local ignoreWaterHeader = createHeader(ignoreWaterPanel, "Options", UDim2.new(0, 0, 0, 0))
	ignoreWaterHeader.LayoutOrder = 1

	-- Ignore Water button (auto-sized)
	local ignoreWaterBtn = Instance.new("TextButton")
	ignoreWaterBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	ignoreWaterBtn.BorderSizePixel = 0
	ignoreWaterBtn.Size = UDim2.new(0, 0, 0, 28)
	ignoreWaterBtn.AutomaticSize = Enum.AutomaticSize.X
	ignoreWaterBtn.Font = Enum.Font.GothamMedium
	ignoreWaterBtn.TextSize = 13
	ignoreWaterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	ignoreWaterBtn.Text = "Ignore Water: OFF"
	ignoreWaterBtn.AutoButtonColor = true
	ignoreWaterBtn.Parent = ignoreWaterPanel

	local ignoreWaterCorner = Instance.new("UICorner")
	ignoreWaterCorner.CornerRadius = UDim.new(0, 4)
	ignoreWaterCorner.Parent = ignoreWaterBtn

	local ignoreWaterPadding = Instance.new("UIPadding")
	ignoreWaterPadding.PaddingLeft = UDim.new(0, 12)
	ignoreWaterPadding.PaddingRight = UDim.new(0, 12)
	ignoreWaterPadding.Parent = ignoreWaterBtn

	ignoreWaterBtn.LayoutOrder = 2
	ignoreWaterBtn.MouseButton1Click:Connect(function()
		ignoreWater = not ignoreWater
		ignoreWaterBtn.Text = "Ignore Water: " .. (ignoreWater and "ON" or "OFF")
		ignoreWaterBtn.BackgroundColor3 = ignoreWater and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(60, 60, 60)
	end)

	configPanels["ignoreWater"] = ignoreWaterPanel

	-- Flatten Mode Panel
	local flattenModePanel = createConfigPanel("flattenMode")
	local flattenModeHeader = createHeader(flattenModePanel, "Flatten Mode", UDim2.new(0, 0, 0, 0))
	flattenModeHeader.LayoutOrder = 1

	local flattenButtonsContainer = Instance.new("Frame")
	flattenButtonsContainer.BackgroundTransparency = 1
	flattenButtonsContainer.Size = UDim2.new(1, 0, 0, 35)
	flattenButtonsContainer.LayoutOrder = 2
	flattenButtonsContainer.Parent = flattenModePanel

	local flattenModes = {
		{ id = FlattenMode.Erode, name = "Erode" },
		{ id = FlattenMode.Both, name = "Both" },
		{ id = FlattenMode.Grow, name = "Grow" },
	}
	local flattenButtons = {}

	local function updateFlattenButtons()
		for modeId, btn in pairs(flattenButtons) do
			if modeId == flattenMode then
				btn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end

	for i, modeInfo in ipairs(flattenModes) do
		local btn = createButton(
			flattenButtonsContainer,
			modeInfo.name,
			UDim2.new(0, (i - 1) * 78, 0, 0),
			UDim2.new(0, 70, 0, 28),
			function()
				flattenMode = modeInfo.id
				updateFlattenButtons()
			end
		)
		flattenButtons[modeInfo.id] = btn
	end
	updateFlattenButtons()

	configPanels["flattenMode"] = flattenModePanel

	-- Auto Material Panel
	local autoMaterialPanel = createConfigPanel("autoMaterial")

	-- Auto Material button (auto-sized)
	local autoMaterialBtn = Instance.new("TextButton")
	autoMaterialBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	autoMaterialBtn.BorderSizePixel = 0
	autoMaterialBtn.Size = UDim2.new(0, 0, 0, 28)
	autoMaterialBtn.AutomaticSize = Enum.AutomaticSize.X
	autoMaterialBtn.Font = Enum.Font.GothamMedium
	autoMaterialBtn.TextSize = 13
	autoMaterialBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoMaterialBtn.Text = "Auto Material: OFF"
	autoMaterialBtn.AutoButtonColor = true
	autoMaterialBtn.Parent = autoMaterialPanel

	local autoMaterialCorner = Instance.new("UICorner")
	autoMaterialCorner.CornerRadius = UDim.new(0, 4)
	autoMaterialCorner.Parent = autoMaterialBtn

	local autoMaterialPadding = Instance.new("UIPadding")
	autoMaterialPadding.PaddingLeft = UDim.new(0, 12)
	autoMaterialPadding.PaddingRight = UDim.new(0, 12)
	autoMaterialPadding.Parent = autoMaterialBtn

	autoMaterialBtn.LayoutOrder = 1
	autoMaterialBtn.MouseButton1Click:Connect(function()
		autoMaterial = not autoMaterial
		autoMaterialBtn.Text = "Auto Material: " .. (autoMaterial and "ON" or "OFF")
		autoMaterialBtn.BackgroundColor3 = autoMaterial and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(60, 60, 60)
	end)

	configPanels["autoMaterial"] = autoMaterialPanel

	-- Material Panel
	local materialPanel = createConfigPanel("material")
	local materialHeader = createHeader(materialPanel, "Material", UDim2.new(0, 0, 0, 0))
	materialHeader.LayoutOrder = 1

	local materialGridContainer = Instance.new("Frame")
	materialGridContainer.Name = "MaterialGrid"
	materialGridContainer.BackgroundTransparency = 1
	materialGridContainer.Size = UDim2.new(1, 0, 0, 630)
	materialGridContainer.LayoutOrder = 2
	materialGridContainer.Parent = materialPanel

	local terrainTileAssets = {
		asphalt = "rbxassetid://78614136624014",
		basalt = "rbxassetid://71488841892968",
		brick = "rbxassetid://86199875827473",
		cobblestone = "rbxassetid://138302697949882",
		concrete = "rbxassetid://81313531028668",
		crackedlava = "rbxassetid://115898687343919",
		glacier = "rbxassetid://90944124973144",
		grass = "rbxassetid://99269182833344",
		ground = "rbxassetid://98068530890664",
		ice = "rbxassetid://130640331811455",
		leafygrass = "rbxassetid://132107716629085",
		limestone = "rbxassetid://81415278652229",
		mud = "rbxassetid://76887606792976",
		pavement = "rbxassetid://114087276888883",
		rock = "rbxassetid://92599200690067",
		salt = "rbxassetid://134960396477809",
		sand = "rbxassetid://83926858135627",
		sandstone = "rbxassetid://130446207383659",
		slate = "rbxassetid://106648045724926",
		snow = "rbxassetid://91289820814306",
		water = "rbxassetid://95030501428333",
		woodplanks = "rbxassetid://104230772282297",
	}

	local materials = {
		{ enum = Enum.Material.Grass, key = "grass", name = "Grass" },
		{ enum = Enum.Material.Sand, key = "sand", name = "Sand" },
		{ enum = Enum.Material.Rock, key = "rock", name = "Rock" },
		{ enum = Enum.Material.Ground, key = "ground", name = "Ground" },
		{ enum = Enum.Material.Snow, key = "snow", name = "Snow" },
		{ enum = Enum.Material.Ice, key = "ice", name = "Ice" },
		{ enum = Enum.Material.Glacier, key = "glacier", name = "Glacier" },
		{ enum = Enum.Material.Water, key = "water", name = "Water" },
		{ enum = Enum.Material.Mud, key = "mud", name = "Mud" },
		{ enum = Enum.Material.Slate, key = "slate", name = "Slate" },
		{ enum = Enum.Material.Concrete, key = "concrete", name = "Concrete" },
		{ enum = Enum.Material.Brick, key = "brick", name = "Brick" },
		{ enum = Enum.Material.Cobblestone, key = "cobblestone", name = "Cobblestone" },
		{ enum = Enum.Material.Asphalt, key = "asphalt", name = "Asphalt" },
		{ enum = Enum.Material.Pavement, key = "pavement", name = "Pavement" },
		{ enum = Enum.Material.Basalt, key = "basalt", name = "Basalt" },
		{ enum = Enum.Material.CrackedLava, key = "crackedlava", name = "Cracked Lava" },
		{ enum = Enum.Material.Salt, key = "salt", name = "Salt" },
		{ enum = Enum.Material.Sandstone, key = "sandstone", name = "Sandstone" },
		{ enum = Enum.Material.Limestone, key = "limestone", name = "Limestone" },
		{ enum = Enum.Material.LeafyGrass, key = "leafygrass", name = "Leafy Grass" },
		{ enum = Enum.Material.WoodPlanks, key = "woodplanks", name = "Wood Planks" },
	}

	local materialButtons = {}
	local TILE_SIZE = 72
	local TILE_GAP = 6
	local COLS = 4

	local function updateMaterialButtons()
		for mat, container in pairs(materialButtons) do
			local tileBtn = container:FindFirstChild("TileButton")
			if tileBtn then
				local border = tileBtn:FindFirstChild("SelectionBorder") :: UIStroke?
				if border then
					border.Transparency = (mat == brushMaterial) and 0 or 1
				end
			end
		end
	end

	for i, matInfo in ipairs(materials) do
		local row = math.floor((i - 1) / COLS)
		local col = (i - 1) % COLS

		local container = Instance.new("Frame")
		container.Name = matInfo.key
		container.BackgroundTransparency = 1
		container.Position = UDim2.new(0, col * (TILE_SIZE + TILE_GAP), 0, row * (TILE_SIZE + 24 + TILE_GAP))
		container.Size = UDim2.new(0, TILE_SIZE, 0, TILE_SIZE + 22)
		container.Parent = materialGridContainer

		local tileBtn = Instance.new("ImageButton")
		tileBtn.Name = "TileButton"
		tileBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		tileBtn.BorderSizePixel = 0
		tileBtn.Size = UDim2.new(0, TILE_SIZE, 0, TILE_SIZE)
		tileBtn.Image = terrainTileAssets[matInfo.key] or ""
		tileBtn.ScaleType = Enum.ScaleType.Crop
		tileBtn.Parent = container

		local tileCorner = Instance.new("UICorner")
		tileCorner.CornerRadius = UDim.new(0, 6)
		tileCorner.Parent = tileBtn

		local selectionBorder = Instance.new("UIStroke")
		selectionBorder.Name = "SelectionBorder"
		selectionBorder.Color = Color3.fromRGB(0, 180, 255)
		selectionBorder.Thickness = 3
		selectionBorder.Transparency = (matInfo.enum == brushMaterial) and 0 or 1
		selectionBorder.Parent = tileBtn

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0, 0, 0, TILE_SIZE + 2)
		label.Size = UDim2.new(1, 0, 0, 18)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = matInfo.name
		label.Parent = container

		materialButtons[matInfo.enum] = container

		tileBtn.MouseButton1Click:Connect(function()
			brushMaterial = matInfo.enum
			updateMaterialButtons()
		end)
	end
	updateMaterialButtons()

	configPanels["material"] = materialPanel

	-- Bridge Info Panel
	local bridgeInfoPanel = createConfigPanel("bridgeInfo")
	local bridgeHeader = createHeader(bridgeInfoPanel, "Bridge Tool", UDim2.new(0, 0, 0, 0))
	bridgeHeader.LayoutOrder = 1

	local bridgeInstructions = Instance.new("TextLabel")
	bridgeInstructions.Name = "Instructions"
	bridgeInstructions.BackgroundTransparency = 1
	bridgeInstructions.Size = UDim2.new(1, 0, 0, 50)
	bridgeInstructions.Font = Enum.Font.Gotham
	bridgeInstructions.TextSize = 12
	bridgeInstructions.TextColor3 = Color3.fromRGB(200, 200, 200)
	bridgeInstructions.TextWrapped = true
	bridgeInstructions.TextXAlignment = Enum.TextXAlignment.Left
	bridgeInstructions.TextYAlignment = Enum.TextYAlignment.Top
	bridgeInstructions.Text = "Click to set START point, then click again to set END point. A terrain bridge will be created between them."
	bridgeInstructions.LayoutOrder = 2
	bridgeInstructions.Parent = bridgeInfoPanel

	local bridgeStatusLabel = Instance.new("TextLabel")
	bridgeStatusLabel.Name = "Status"
	bridgeStatusLabel.BackgroundTransparency = 1
	bridgeStatusLabel.Size = UDim2.new(1, 0, 0, 24)
	bridgeStatusLabel.Font = Enum.Font.GothamBold
	bridgeStatusLabel.TextSize = 14
	bridgeStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	bridgeStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
	bridgeStatusLabel.Text = "Status: Click to set START"
	bridgeStatusLabel.LayoutOrder = 3
	bridgeStatusLabel.Parent = bridgeInfoPanel

	local _, bridgeWidthContainer, _ = createSlider(bridgeInfoPanel, "Width", 1, 20, bridgeWidth, function(val)
		bridgeWidth = val
	end)
	bridgeWidthContainer.LayoutOrder = 4

	local clearBridgeBtn = createButton(bridgeInfoPanel, "Clear Points", UDim2.new(0, 0, 0, 0), UDim2.new(0, 100, 0, 28), function()
		bridgeStartPoint = nil
		bridgeEndPoint = nil
		bridgeStatusLabel.Text = "Status: Click to set START"
		-- Clear preview parts
		for _, part in ipairs(bridgePreviewParts) do
			part:Destroy()
		end
		bridgePreviewParts = {}
	end)
	clearBridgeBtn.LayoutOrder = 6

	configPanels["bridgeInfo"] = bridgeInfoPanel

	-- Function to update bridge status
	local function updateBridgeStatus()
		if bridgeStartPoint and bridgeEndPoint then
			bridgeStatusLabel.Text = "Status: READY - Click to build!"
			bridgeStatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
		elseif bridgeStartPoint then
			bridgeStatusLabel.Text = "Status: Click to set END"
			bridgeStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
		else
			bridgeStatusLabel.Text = "Status: Click to set START"
			bridgeStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
		end
	end

	-- Function to create bridge preview
	local function updateBridgePreview()
		-- Clear old preview
		for _, part in ipairs(bridgePreviewParts) do
			part:Destroy()
		end
		bridgePreviewParts = {}

		if not bridgeStartPoint then
			return
		end

		-- Show start marker
		local startMarker = Instance.new("Part")
		startMarker.Size = Vector3.new(bridgeWidth, bridgeWidth, bridgeWidth) * Constants.VOXEL_RESOLUTION
		startMarker.CFrame = CFrame.new(bridgeStartPoint)
		startMarker.Anchored = true
		startMarker.CanCollide = false
		startMarker.Material = Enum.Material.Neon
		startMarker.Color = Color3.fromRGB(0, 255, 0) -- Green for start
		startMarker.Transparency = 0.5
		startMarker.Parent = workspace
		table.insert(bridgePreviewParts, startMarker)

		if bridgeEndPoint then
			-- Show end marker
			local endMarker = Instance.new("Part")
			endMarker.Size = Vector3.new(bridgeWidth, bridgeWidth, bridgeWidth) * Constants.VOXEL_RESOLUTION
			endMarker.CFrame = CFrame.new(bridgeEndPoint)
			endMarker.Anchored = true
			endMarker.CanCollide = false
			endMarker.Material = Enum.Material.Neon
			endMarker.Color = Color3.fromRGB(255, 100, 0) -- Orange for end
			endMarker.Transparency = 0.5
			endMarker.Parent = workspace
			table.insert(bridgePreviewParts, endMarker)

			-- Show path preview (line of parts)
			local distance = (bridgeEndPoint - bridgeStartPoint).Magnitude
			local steps = math.max(2, math.floor(distance / (Constants.VOXEL_RESOLUTION * 2)))

			for i = 1, steps - 1 do
				local t = i / steps
				local pos = bridgeStartPoint:Lerp(bridgeEndPoint, t)
				-- Add a slight arc (parabola) for natural bridge shape
				local arcHeight = math.sin(t * math.pi) * distance * 0.1

				local pathMarker = Instance.new("Part")
				pathMarker.Size = Vector3.new(bridgeWidth * 0.5, bridgeWidth * 0.5, bridgeWidth * 0.5) * Constants.VOXEL_RESOLUTION
				pathMarker.CFrame = CFrame.new(pos + Vector3.new(0, arcHeight, 0))
				pathMarker.Anchored = true
				pathMarker.CanCollide = false
				pathMarker.Material = Enum.Material.Neon
				pathMarker.Color = Color3.fromRGB(100, 200, 255) -- Cyan for path
				pathMarker.Transparency = 0.7
				pathMarker.Shape = Enum.PartType.Ball
				pathMarker.Parent = workspace
				table.insert(bridgePreviewParts, pathMarker)
			end
		end
	end

	-- Function to build the actual bridge
	local function buildBridge()
		if not bridgeStartPoint or not bridgeEndPoint then
			return
		end

		ChangeHistoryService:SetWaypoint("TerrainBridge_Start")

		local distance = (bridgeEndPoint - bridgeStartPoint).Magnitude
		local steps = math.max(3, math.floor(distance / Constants.VOXEL_RESOLUTION))
		local radius = bridgeWidth * Constants.VOXEL_RESOLUTION / 2

		for i = 0, steps do
			local t = i / steps
			local pos = bridgeStartPoint:Lerp(bridgeEndPoint, t)
			-- Add arc for natural bridge shape
			local arcHeight = math.sin(t * math.pi) * distance * 0.1

			local bridgePos = pos + Vector3.new(0, arcHeight, 0)

			-- Fill a cylinder/sphere at each point along the path
			terrain:FillBall(bridgePos, radius, brushMaterial)
		end

		ChangeHistoryService:SetWaypoint("TerrainBridge_End")

		-- Clear points after building
		bridgeStartPoint = nil
		bridgeEndPoint = nil
		updateBridgeStatus()
		updateBridgePreview()
	end

	-- ============================================================================
	-- Config Panel Visibility Logic
	-- ============================================================================

	-- Add UIListLayout to configContainer for automatic positioning
	local configLayout = Instance.new("UIListLayout")
	configLayout.SortOrder = Enum.SortOrder.LayoutOrder
	configLayout.Padding = UDim.new(0, 10)
	configLayout.Parent = configContainer

	-- Set layout order for panels
	local panelOrder = {
		"bridgeInfo",
		"brushShape",
		"handleHint",
		"strength",
		"pivot",
		"spin",
		"hollow",
		"planeLock",
		"ignoreWater",
		"flattenMode",
		"autoMaterial",
		"material",
	}
	for i, panelName in ipairs(panelOrder) do
		if configPanels[panelName] then
			configPanels[panelName].LayoutOrder = i
		end
	end

	-- No tool selected message
	local noToolMessage = Instance.new("TextLabel")
	noToolMessage.Name = "NoToolMessage"
	noToolMessage.BackgroundTransparency = 1
	noToolMessage.Size = UDim2.new(1, 0, 0, 60)
	noToolMessage.Font = Enum.Font.Gotham
	noToolMessage.TextSize = 14
	noToolMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
	noToolMessage.Text = "Select a tool above to see its settings"
	noToolMessage.TextWrapped = true
	noToolMessage.LayoutOrder = 0
	noToolMessage.Parent = configContainer

	updateConfigPanelVisibility = function()
		local toolConfig = ToolConfigs[currentTool]

		-- Hide all panels first
		for _, panel in pairs(configPanels) do
			panel.Visible = false
		end

		if currentTool == ToolId.None or not toolConfig then
			noToolMessage.Visible = true
		else
			noToolMessage.Visible = false
			-- Show only panels needed for this tool
			for _, panelName in ipairs(toolConfig) do
				if configPanels[panelName] then
					configPanels[panelName].Visible = true
				end
			end
		end

		-- Update canvas size based on visible content
		task.defer(function()
			local totalHeight = CONFIG_START_Y + configLayout.AbsoluteContentSize.Y + 50
			mainFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(totalHeight, 400))
		end)
	end

	-- Initial visibility update
	updateConfigPanelVisibility()
	updateToolButtonVisuals()

	-- Activate plugin since Add tool is preselected
	pluginInstance:Activate(true)

	-- ============================================================================
	-- Mouse & Input Handling
	-- ============================================================================

	-- Store ALL connections for proper cleanup on reload
	local allConnections: { RBXScriptConnection } = {}

	local function addConnection(conn: RBXScriptConnection)
		table.insert(allConnections, conn)
	end

	addConnection(mouse.Button1Down:Connect(function()
		if DEBUG then
			print("[DEBUG] Mouse down, currentTool =", currentTool)
		end
		if currentTool ~= ToolId.None then
			-- Bridge tool has special click handling
			if currentTool == ToolId.Bridge then
				local hitPosition = getTerrainHit()
				if hitPosition then
					if not bridgeStartPoint then
						-- Set start point
						bridgeStartPoint = hitPosition
						updateBridgeStatus()
						updateBridgePreview()
					elseif not bridgeEndPoint then
						-- Set end point
						bridgeEndPoint = hitPosition
						updateBridgeStatus()
						updateBridgePreview()
					else
						-- Both points set - build the bridge!
						buildBridge()
					end
				end
				return -- Don't start brushing for bridge tool
			end

			-- In Auto mode, capture the plane height on mousedown
			if planeLockMode == PlaneLockType.Auto then
				local hitPosition = getTerrainHitRaw()
				if hitPosition then
					planePositionY = math.floor(hitPosition.Y + 0.5)
					autoPlaneActive = true
				end
			end

			isMouseDown = true
			startBrushing()
		end
	end))

	addConnection(mouse.Button1Up:Connect(function()
		isMouseDown = false
		stopBrushing()

		-- In Auto mode, release the plane lock when mouse is released
		if planeLockMode == PlaneLockType.Auto then
			autoPlaneActive = false
		end
	end))

	-- Handle external deactivation (user clicks another Studio tool)
	addConnection(pluginInstance.Deactivation:Connect(function()
		if currentTool ~= ToolId.None then
			currentTool = ToolId.None
			updateToolButtonVisuals()
			if updateConfigPanelVisibility then
				updateConfigPanelVisibility()
			end
			hideBrushVisualization()
			hidePlaneVisualization()
			stopBrushing()
			autoPlaneActive = false
		end
	end))

	-- Shift+Scroll = adjust size, Ctrl+Scroll = adjust strength
	-- Works anywhere when a tool is active
	addConnection(UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		-- Only adjust when a tool is selected
		if currentTool == ToolId.None then
			return
		end

		local scrollUp = input.Position.Z > 0
		local ctrlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		if shiftHeld then
			-- Shift+Scroll: Adjust SIZE (uses X dimension as the primary size)
			-- Larger increments for bigger brush sizes (proportional feel)
			local increment = brushSizeX < 10 and 1 or (brushSizeX < 30 and 2 or 4)
			local delta = scrollUp and increment or -increment
			local newSize = math.clamp(brushSizeX + delta, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
			-- Set all size dimensions based on shape's sizing mode
			brushSizeX = newSize
			local sizingMode = ShapeSizingMode[brushShape] or "uniform"
			if sizingMode == "uniform" then
				brushSizeY = newSize
				brushSizeZ = newSize
			elseif sizingMode == "cylinder" then
				brushSizeZ = newSize
			end
		elseif ctrlHeld then
			-- Ctrl+Scroll: Adjust STRENGTH
			local delta = scrollUp and 10 or -10
			local newStrength = math.clamp(math.floor(brushStrength * 100) + delta, 1, 100)
			setStrengthValue(newStrength)
		end
	end))

	-- 'R' key to toggle brush lock mode (for interacting with rotation/size handles)
	addConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.R then
			-- Only toggle when a tool is active
			if currentTool == ToolId.None then
				return
			end

			brushLocked = not brushLocked

			if brushLocked then
				print("[TerrainEditor] Brush LOCKED - drag handles to rotate/resize, press R to unlock")
			else
				print("[TerrainEditor] Brush UNLOCKED - brush follows mouse")
			end

			-- Force update visualization to show color change
			if lockedBrushPosition then
				updateBrushVisualization(lockedBrushPosition)
			end
		end
	end))

	-- Render visualization
	renderConnection = RunService.RenderStepped:Connect(function()
		if currentTool ~= ToolId.None and parentGui.Enabled then
			local hitPosition = getTerrainHit()

			-- Determine which position to use for brush visualization
			local brushPosition = hitPosition
			if brushLocked and lockedBrushPosition then
				-- When locked, keep brush at locked position
				brushPosition = lockedBrushPosition
			elseif hitPosition then
				-- Store current position (for when we lock)
				lockedBrushPosition = hitPosition
			end

			if brushPosition then
				updateBrushVisualization(brushPosition)

				-- Show plane visualization when plane lock is active
				local showPlane = (planeLockMode == PlaneLockType.Manual) or (planeLockMode == PlaneLockType.Auto and autoPlaneActive)
				if showPlane then
					updatePlaneVisualization(brushPosition.X, brushPosition.Z)
				else
					hidePlaneVisualization()
				end
			end
		else
			hideBrushVisualization()
			hidePlaneVisualization()
		end
	end)
	addConnection(renderConnection)

	-- Cleanup ALL connections when GUI is destroyed (on reload)
	parentGui.AncestryChanged:Connect(function()
		if not parentGui:IsDescendantOf(game) then
			if DEBUG then
				print("[DEBUG] Cleaning up - disconnecting all connections")
			end
			for _, conn in ipairs(allConnections) do
				if conn.Connected then
					conn:Disconnect()
				end
			end
			if brushConnection then
				brushConnection:Disconnect()
			end
			hideBrushVisualization()
			hidePlaneVisualization()
		end
	end)

	print("[TerrainEditorFork] v" .. VERSION .. " loaded! (Dynamic tool configs)")

	-- Return cleanup function for the loader to call on reload
	return function()
		if DEBUG then
			print("[DEBUG] Cleanup function called")
		end
		for _, conn in ipairs(allConnections) do
			if conn.Connected then
				conn:Disconnect()
			end
		end
		if brushConnection then
			brushConnection:Disconnect()
		end
		if renderConnection then
			renderConnection:Disconnect()
		end
		hideBrushVisualization()
		hidePlaneVisualization()
		destroyHandles() -- Clean up 3D handles
		-- Clean up bridge preview parts
		for _, part in ipairs(bridgePreviewParts) do
			part:Destroy()
		end
		bridgePreviewParts = {}
		pluginInstance:Deactivate()
	end
end

return TerrainEditorModule
