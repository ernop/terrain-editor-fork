-- TerrainEditorFork - Module Version for Live Development
-- This module is loaded by the loader plugin for hot-reloading

local VERSION = "0.0.00000022"
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
	local terrain = workspace.Terrain
	local brushConnection = nil
	local renderConnection = nil

	-- Brush settings
	local currentTool = ToolId.Add
	local brushSizeX = Constants.INITIAL_BRUSH_SIZE
	local brushSizeY = Constants.INITIAL_BRUSH_SIZE
	local brushSizeZ = Constants.INITIAL_BRUSH_SIZE
	local brushStrength = Constants.INITIAL_BRUSH_STRENGTH
	local brushShape = BrushShape.Sphere
	local brushRotation = CFrame.new() -- Rotation only (no position)
	local brushMaterial = Enum.Material.Grass
	local pivotType = PivotType.Center
	local flattenMode = FlattenMode.Both
	local autoMaterial = false
	local ignoreWater = false
	local planeLockMode = PlaneLockType.Off
	local planePositionY = Constants.INITIAL_PLANE_POSITION_Y
	local autoPlaneActive = false -- True when Auto mode has captured a plane during stroke

	-- Shape capabilities: which shapes support rotation and multi-axis sizing
	local ShapeSupportsRotation = {
		[BrushShape.Sphere] = false, -- Sphere looks the same from all angles
		[BrushShape.Cube] = true,
		[BrushShape.Cylinder] = true,
	}

	local ShapeSizingMode = {
		-- "uniform" = single size (X=Y=Z), "cylinder" = radius + height, "box" = X, Y, Z independent
		[BrushShape.Sphere] = "uniform",
		[BrushShape.Cube] = "box",
		[BrushShape.Cylinder] = "cylinder", -- X=Z (radius), Y (height)
	}

	-- Mouse state
	local mouse = pluginInstance:GetMouse()
	local isMouseDown = false
	local lastBrushPosition = nil

	-- Brush visualization
	local brushPart = nil
	local planePart = nil -- Visual indicator for locked plane
	
	-- 3D Handles for rotation and sizing
	local rotationHandles = nil
	local sizeHandles = nil
	local isHandleDragging = false -- Prevent brush painting while dragging handles
	
	-- Forward declarations for handle functions (defined later, after brush viz)
	local updateHandlesAdornee
	local hideHandles
	local destroyHandles

	-- Config panels (will be populated later)
	local configPanels: { [string]: Frame } = {}
	local updateConfigPanelVisibility: (() -> ())?
	local updateSizeSliderVisibility: (() -> ())? -- Forward declaration
	local updateRotationPanelVisibility: (() -> ())? -- Forward declaration

	-- ============================================================================
	-- Tool Config Definitions
	-- Define which settings each tool needs
	-- ============================================================================

	local ToolConfigs = {
		[ToolId.Add] = {
			"brushShape",
			"brushSize",
			"brushRotation",
			"strength",
			"pivot",
			"planeLock",
			"ignoreWater",
			"material",
		},
		[ToolId.Subtract] = {
			"brushShape",
			"brushSize",
			"brushRotation",
			"strength",
			"pivot",
			"planeLock",
			"ignoreWater",
		},
		[ToolId.Grow] = { "brushShape", "brushSize", "brushRotation", "strength", "pivot", "planeLock", "ignoreWater" },
		[ToolId.Erode] = { "brushShape", "brushSize", "brushRotation", "strength", "pivot", "planeLock", "ignoreWater" },
		[ToolId.Smooth] = {
			"brushShape",
			"brushSize",
			"brushRotation",
			"strength",
			"pivot",
			"planeLock",
			"ignoreWater",
		},
		[ToolId.Flatten] = {
			"brushShape",
			"brushSize",
			"brushRotation",
			"strength",
			"pivot",
			"planeLock",
			"ignoreWater",
			"flattenMode",
		},
		[ToolId.Paint] = { "brushShape", "brushSize", "brushRotation", "strength", "material", "autoMaterial" },
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

	local function createButton(
		parent: Frame,
		text: string,
		position: UDim2,
		size: UDim2,
		callback: () -> ()
	): TextButton
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

		local labelText =
			createLabel(container, label .. ": " .. tostring(initial), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 18))

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
				local relativeX =
					math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
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

	local toolButtons: { [string]: TextButton } = {}

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

	local function createBrushVisualization()
		if brushPart then
			brushPart:Destroy()
		end

		brushPart = Instance.new("Part")
		brushPart.Name = "TerrainBrushVisualization"
		brushPart.Anchored = true
		brushPart.CanCollide = false
		brushPart.CanQuery = false
		brushPart.CanTouch = false
		brushPart.CastShadow = false
		brushPart.Transparency = 0.7
		brushPart.Material = Enum.Material.Neon
		brushPart.Color = Color3.fromRGB(0, 162, 255)

		if brushShape == BrushShape.Sphere then
			brushPart.Shape = Enum.PartType.Ball
		elseif brushShape == BrushShape.Cube then
			brushPart.Shape = Enum.PartType.Block
		elseif brushShape == BrushShape.Cylinder then
			brushPart.Shape = Enum.PartType.Cylinder
		end

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

			-- Base CFrame at position
			local baseCFrame = CFrame.new(position)

			-- Apply user rotation if shape supports it
			local finalCFrame = baseCFrame
			if ShapeSupportsRotation[brushShape] then
				finalCFrame = baseCFrame * brushRotation
			end

			if brushShape == BrushShape.Sphere then
				brushPart.Shape = Enum.PartType.Ball
				-- Sphere uses uniform size (X for all dimensions)
				brushPart.Size = Vector3.new(sizeX, sizeX, sizeX)
				brushPart.CFrame = finalCFrame
			elseif brushShape == BrushShape.Cube then
				brushPart.Shape = Enum.PartType.Block
				-- Cube uses all three dimensions
				brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
				brushPart.CFrame = finalCFrame
			else			if brushShape == BrushShape.Cylinder then
				brushPart.Shape = Enum.PartType.Cylinder
				-- Cylinder: Part cylinder has height along X axis, so we rotate 90° to make it vertical
				-- Size = (height, diameter, diameter) after rotation becomes (diameter, height, diameter)
				-- X and Z are the radius (use sizeX), Y is the height (use sizeY)
				brushPart.Size = Vector3.new(sizeY, sizeX, sizeX)
				-- Apply base rotation to make cylinder vertical, then user rotation
				finalCFrame = baseCFrame * brushRotation * CFrame.Angles(0, 0, math.rad(90))
				brushPart.CFrame = finalCFrame
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

			if sizingMode == "uniform" then
				-- Sphere: all axes change together
				local newSize = math.clamp(dragStartSizeX + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				brushSizeX = newSize
				brushSizeY = newSize
				brushSizeZ = newSize
			elseif sizingMode == "cylinder" then
				-- Cylinder: Top/Bottom change height (Y), others change radius (X=Z)
				if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
					brushSizeY = math.clamp(dragStartSizeY + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				else
					local newRadius = math.clamp(dragStartSizeX + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
					brushSizeX = newRadius
					brushSizeZ = newRadius
				end
			else -- "box"
				-- Cube: each face changes its axis
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
		local usePlaneLock = (planeLockMode == PlaneLockType.Manual)
			or (planeLockMode == PlaneLockType.Auto and autoPlaneActive)

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
		local usePlaneLock = (planeLockMode == PlaneLockType.Manual)
			or (planeLockMode == PlaneLockType.Auto and autoPlaneActive)
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
		end
		-- "box" mode: use all three independently (no changes needed)

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
			-- Rotation (only applied if shape supports it)
			brushRotation = ShapeSupportsRotation[brushShape] and brushRotation or CFrame.new(),
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
			-- Don't paint if mouse isn't down, no tool selected, or dragging handles
			if not isMouseDown or currentTool == ToolId.None or isHandleDragging then
				return
			end

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

	createHeader(mainFrame, "Paint", UDim2.new(0, 0, 0, 155))
	local paintBtn = createToolButton(mainFrame, ToolId.Paint, "Paint", UDim2.new(0, 0, 0, 180))
	toolButtons[ToolId.Paint] = paintBtn
	paintBtn.MouseButton1Click:Connect(function()
		selectTool(ToolId.Paint)
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
	shapeButtonsContainer.Size = UDim2.new(1, 0, 0, 35)
	shapeButtonsContainer.LayoutOrder = 2
	shapeButtonsContainer.Parent = shapePanel

	local shapes = {
		{ id = BrushShape.Sphere, name = "Sphere" },
		{ id = BrushShape.Cube, name = "Cube" },
		{ id = BrushShape.Cylinder, name = "Cylinder" },
	}
	local shapeButtons: { [string]: TextButton } = {}

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
			UDim2.new(0, (i - 1) * 78, 0, 0),
			UDim2.new(0, 70, 0, 28),
			function()
				brushShape = shapeInfo.id
				updateShapeButtons()
				-- Update size sliders visibility for new shape
				if updateSizeSliderVisibility then
					updateSizeSliderVisibility()
				end
				-- Update rotation panel visibility for new shape
				if updateRotationPanelVisibility then
					updateRotationPanelVisibility()
				end
			end
		)
		shapeButtons[shapeInfo.id] = btn
	end
	updateShapeButtons()

	configPanels["brushShape"] = shapePanel

	-- Brush Size Panel (with X, Y, Z sliders)
	local sizePanel = createConfigPanel("brushSize")
	local sizeHeader = createHeader(sizePanel, "Brush Size", UDim2.new(0, 0, 0, 0))
	sizeHeader.LayoutOrder = 1

	-- Forward declare the set functions so they can reference each other
	local setSizeXValue: (number) -> ()
	local setSizeYValue: (number) -> ()
	local setSizeZValue: (number) -> ()

	-- Size X slider (also acts as "uniform" size for Sphere, or "radius" for Cylinder)
	local sizeXLabel, sizeXSliderContainer, setSizeXValueInternal = createSlider(
		sizePanel,
		"X",
		Constants.MIN_BRUSH_SIZE,
		Constants.MAX_BRUSH_SIZE,
		brushSizeX,
		function(value)
			brushSizeX = value
			-- For uniform shapes, sync all dimensions
			local sizingMode = ShapeSizingMode[brushShape] or "uniform"
			if sizingMode == "uniform" then
				brushSizeY = value
				brushSizeZ = value
				setSizeYValue(value)
				setSizeZValue(value)
			elseif sizingMode == "cylinder" then
				-- Cylinder: X and Z are linked (radius)
				brushSizeZ = value
				setSizeZValue(value)
			end
		end
	)
	sizeXSliderContainer.LayoutOrder = 2
	setSizeXValue = setSizeXValueInternal

	-- Size Y slider (height)
	local sizeYLabel, sizeYSliderContainer, setSizeYValueInternal = createSlider(
		sizePanel,
		"Y",
		Constants.MIN_BRUSH_SIZE,
		Constants.MAX_BRUSH_SIZE,
		brushSizeY,
		function(value)
			brushSizeY = value
			-- For uniform shapes, sync all dimensions
			local sizingMode = ShapeSizingMode[brushShape] or "uniform"
			if sizingMode == "uniform" then
				brushSizeX = value
				brushSizeZ = value
				setSizeXValue(value)
				setSizeZValue(value)
			end
		end
	)
	sizeYSliderContainer.LayoutOrder = 3
	setSizeYValue = setSizeYValueInternal

	-- Size Z slider (depth)
	local sizeZLabel, sizeZSliderContainer, setSizeZValueInternal = createSlider(
		sizePanel,
		"Z",
		Constants.MIN_BRUSH_SIZE,
		Constants.MAX_BRUSH_SIZE,
		brushSizeZ,
		function(value)
			brushSizeZ = value
			-- For uniform shapes, sync all dimensions
			local sizingMode = ShapeSizingMode[brushShape] or "uniform"
			if sizingMode == "uniform" then
				brushSizeX = value
				brushSizeY = value
				setSizeXValue(value)
				setSizeYValue(value)
			elseif sizingMode == "cylinder" then
				-- Cylinder: X and Z are linked (radius)
				brushSizeX = value
				setSizeXValue(value)
			end
		end
	)
	sizeZSliderContainer.LayoutOrder = 4
	setSizeZValue = setSizeZValueInternal

	-- Function to update slider visibility/labels based on shape
	updateSizeSliderVisibility = function()
		local sizingMode = ShapeSizingMode[brushShape] or "uniform"

		if sizingMode == "uniform" then
			-- Sphere: Show only one slider labeled "Size"
			sizeXLabel.Text = "Size"
			sizeXSliderContainer.Visible = true
			sizeYSliderContainer.Visible = false
			sizeZSliderContainer.Visible = false
		elseif sizingMode == "cylinder" then
			-- Cylinder: Show Radius (X) and Height (Y)
			sizeXLabel.Text = "Radius"
			sizeYLabel.Text = "Height"
			sizeXSliderContainer.Visible = true
			sizeYSliderContainer.Visible = true
			sizeZSliderContainer.Visible = false
		else -- "box"
			-- Cube: Show all three as X, Y, Z
			sizeXLabel.Text = "X"
			sizeYLabel.Text = "Y"
			sizeZLabel.Text = "Z"
			sizeXSliderContainer.Visible = true
			sizeYSliderContainer.Visible = true
			sizeZSliderContainer.Visible = true
		end
	end

	-- Initialize visibility for default shape
	updateSizeSliderVisibility()

	-- Legacy function for scroll wheel (adjusts X, which propagates to others as needed)
	local function setSizeValue(value: number)
		setSizeXValue(value)
		brushSizeX = value
		local sizingMode = ShapeSizingMode[brushShape] or "uniform"
		if sizingMode == "uniform" then
			brushSizeY = value
			brushSizeZ = value
			setSizeYValue(value)
			setSizeZValue(value)
		elseif sizingMode == "cylinder" then
			brushSizeZ = value
			setSizeZValue(value)
		end
	end

	configPanels["brushSize"] = sizePanel

	-- Brush Rotation Panel
	local rotationPanel = createConfigPanel("brushRotation")
	local rotationHeader = createHeader(rotationPanel, "Brush Rotation", UDim2.new(0, 0, 0, 0))
	rotationHeader.LayoutOrder = 1

	-- Store rotation as Euler angles (degrees) for easier UI
	local rotationX: number = 0
	local rotationY: number = 0
	local rotationZ: number = 0

	local function updateBrushRotationFromEuler()
		brushRotation = CFrame.Angles(math.rad(rotationX), math.rad(rotationY), math.rad(rotationZ))
	end

	-- Rotation X slider (Pitch)
	local rotXLabel, rotXSliderContainer, setRotXValue = createSlider(
		rotationPanel,
		"Pitch",
		-180,
		180,
		rotationX,
		function(value)
			rotationX = value
			updateBrushRotationFromEuler()
		end
	)
	rotXSliderContainer.LayoutOrder = 2

	-- Rotation Y slider (Yaw)
	local rotYLabel, rotYSliderContainer, setRotYValue = createSlider(
		rotationPanel,
		"Yaw",
		-180,
		180,
		rotationY,
		function(value)
			rotationY = value
			updateBrushRotationFromEuler()
		end
	)
	rotYSliderContainer.LayoutOrder = 3

	-- Rotation Z slider (Roll)
	local rotZLabel, rotZSliderContainer, setRotZValue = createSlider(
		rotationPanel,
		"Roll",
		-180,
		180,
		rotationZ,
		function(value)
			rotationZ = value
			updateBrushRotationFromEuler()
		end
	)
	rotZSliderContainer.LayoutOrder = 4

	-- Reset rotation button (auto-sized)
	local resetRotationBtn = Instance.new("TextButton")
	resetRotationBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	resetRotationBtn.BorderSizePixel = 0
	resetRotationBtn.Size = UDim2.new(0, 0, 0, 28)
	resetRotationBtn.AutomaticSize = Enum.AutomaticSize.X
	resetRotationBtn.Font = Enum.Font.GothamMedium
	resetRotationBtn.TextSize = 13
	resetRotationBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	resetRotationBtn.Text = "Reset Rotation"
	resetRotationBtn.AutoButtonColor = true
	resetRotationBtn.Parent = rotationPanel

	local resetBtnCorner = Instance.new("UICorner")
	resetBtnCorner.CornerRadius = UDim.new(0, 4)
	resetBtnCorner.Parent = resetRotationBtn

	local resetBtnPadding = Instance.new("UIPadding")
	resetBtnPadding.PaddingLeft = UDim.new(0, 12)
	resetBtnPadding.PaddingRight = UDim.new(0, 12)
	resetBtnPadding.Parent = resetRotationBtn

	resetRotationBtn.MouseButton1Click:Connect(function()
		rotationX = 0
		rotationY = 0
		rotationZ = 0
		setRotXValue(0)
		setRotYValue(0)
		setRotZValue(0)
		brushRotation = CFrame.new()
	end)
	resetRotationBtn.LayoutOrder = 5

	-- Function to show/hide rotation panel based on shape
	updateRotationPanelVisibility = function()
		local supportsRotation = ShapeSupportsRotation[brushShape]
		rotationPanel.Visible = supportsRotation
	end

	-- Initialize visibility
	updateRotationPanelVisibility()

	configPanels["brushRotation"] = rotationPanel

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
	local pivotButtons: { [string]: TextButton } = {}

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

	local planeLockModeButtons: { [string]: TextButton } = {}

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
	local flattenButtons: { [string]: TextButton } = {}

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

	local materialButtons: { [Enum.Material]: Frame } = {}
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
		"brushShape",
		"brushSize",
		"brushRotation",
		"strength",
		"pivot",
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
		local ctrlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		if shiftHeld then
			-- Shift+Scroll: Adjust SIZE (uses X dimension as the primary size)
			-- Larger increments for bigger brush sizes (proportional feel)
			local increment = brushSizeX < 10 and 1 or (brushSizeX < 30 and 2 or 4)
			local delta = scrollUp and increment or -increment
			local newSize = math.clamp(brushSizeX + delta, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
			setSizeValue(newSize)
		elseif ctrlHeld then
			-- Ctrl+Scroll: Adjust STRENGTH
			local delta = scrollUp and 10 or -10
			local newStrength = math.clamp(math.floor(brushStrength * 100) + delta, 1, 100)
			setStrengthValue(newStrength)
		end
	end))

	-- Render visualization
	renderConnection = RunService.RenderStepped:Connect(function()
		if currentTool ~= ToolId.None and parentGui.Enabled then
			local hitPosition = getTerrainHit()
			if hitPosition then
				updateBrushVisualization(hitPosition)

				-- Show plane visualization when plane lock is active
				local showPlane = (planeLockMode == PlaneLockType.Manual)
					or (planeLockMode == PlaneLockType.Auto and autoPlaneActive)
				if showPlane then
					updatePlaneVisualization(hitPosition.X, hitPosition.Z)
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
		hideBrushVisualization()
		hidePlaneVisualization()
		destroyHandles() -- Clean up 3D handles
		pluginInstance:Deactivate()
	end
end

return TerrainEditorModule
