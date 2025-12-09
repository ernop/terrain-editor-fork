--!strict

-- TerrainEditorFork - Module Version for Live Development
-- This module is loaded by the loader plugin for hot-reloading

local VERSION = "0.0.00000046"
local _DEBUG = false

local TerrainEditorModule = {}

function TerrainEditorModule.init(pluginInstance: Plugin, parentGui: GuiObject)
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
	local UIHelpers = require(Src.Util.UIHelpers) :: any
	local BrushData = require(Src.Util.BrushData) :: any
	local BridgePathGenerator = require(Src.Util.BridgePathGenerator) :: any
	local ToolId = TerrainEnums.ToolId
	local BrushShape = TerrainEnums.BrushShape
	local PivotType = TerrainEnums.PivotType
	local FlattenMode = TerrainEnums.FlattenMode
	local PlaneLockType = TerrainEnums.PlaneLockType
	local SpinMode = TerrainEnums.SpinMode

	-- Load terrain operations
	local performTerrainBrushOperation = require(Src.TerrainOperations.performTerrainBrushOperation)

	-- All state grouped into single table S to reduce local register count
	local S = {
		terrain = workspace.Terrain :: Terrain,
		brushConnection = nil :: RBXScriptConnection?,
		renderConnection = nil :: RBXScriptConnection?,
		currentTool = ToolId.Add,
		brushSizeX = Constants.INITIAL_BRUSH_SIZE,
		brushSizeY = Constants.INITIAL_BRUSH_SIZE,
		brushSizeZ = Constants.INITIAL_BRUSH_SIZE,
		brushStrength = Constants.INITIAL_BRUSH_STRENGTH,
		brushShape = BrushShape.Sphere,
		brushRotation = CFrame.new(),
		brushMaterial = Enum.Material.Grass,
		pivotType = PivotType.Center,
		flattenMode = FlattenMode.Both,
		autoMaterial = false,
		ignoreWater = false,
		planeLockMode = PlaneLockType.Off,
		planePositionY = Constants.INITIAL_PLANE_POSITION_Y,
		autoPlaneActive = false,
		spinMode = SpinMode.Off,
		spinAngle = 0,
		hollowEnabled = false,
		wallThickness = 0.2,
		noiseScale = 4,
		noiseIntensity = 0.5,
		noiseSeed = 0,
		stepHeight = 8,
		stepSharpness = 0.8,
		cliffAngle = 90,
		cliffDirectionX = 1,
		cliffDirectionZ = 0,
		pathDepth = 6,
		pathProfile = "U",
		pathDirectionX = 0,
		pathDirectionZ = 1,
		cloneSourceBuffer = nil :: { [number]: { [number]: { [number]: { occupancy: number, material: Enum.Material } } } }?,
		cloneSourceCenter = nil :: Vector3?,
		blobIntensity = 0.5,
		blobSmoothness = 0.7,
		brushRate = "normal", -- Brush rate preset: "no_repeat", "on_move_only", "very_slow", "slow", "normal", "fast"
		lastMouseWorldPos = nil :: Vector3?,
		lastBrushTime = 0,
		lastBrushPosition = nil :: Vector3?,
		isMouseDown = false,
		brushPart = nil :: BasePart?,
		brushExtraParts = {} :: { BasePart },
		planePart = nil :: Part?,
		rotationHandles = nil :: ArcHandles?,
		sizeHandles = nil :: Handles?,
		isHandleDragging = false,
		brushLocked = false,
		lockedBrushPosition = nil :: Vector3?,
		bridgeStartPoint = nil :: Vector3?,
		bridgeEndPoint = nil :: Vector3?,
		bridgePreviewParts = {} :: { BasePart },
		bridgeWidth = 4,
		bridgeVariant = "Arc",
		bridgeCurves = {} :: { { type: string, amplitude: number, frequency: number, phase: number, offset: Vector3 } },
		bridgeEditMode = false,
		bridgeSelectedConnection = nil :: number?,
		bridgeMeanderComplexity = 5,
	}
	local mouse = pluginInstance:GetMouse()

	-- Forward declarations for handle functions (defined later, after brush viz)
	local updateHandlesAdornee
	local hideHandles
	local destroyHandles

	-- Config panels (will be populated later)
	local configPanels: { [string]: Frame } = {}
	local updateConfigPanelVisibility: (() -> ())? = nil

	local toolButtons = {}

	local function updateToolButtonVisuals()
		for toolId, button in pairs(toolButtons) do
			if toolId == S.currentTool then
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
		if S.currentTool == ToolId.Bridge and toolId ~= ToolId.Bridge then
			S.bridgeStartPoint = nil
			S.bridgeEndPoint = nil
			for _, part in ipairs(S.bridgePreviewParts) do
				part:Destroy()
			end
			S.bridgePreviewParts = {}
		end

		if S.currentTool == toolId then
			S.currentTool = ToolId.None
			pluginInstance:Deactivate()
		else
			S.currentTool = toolId
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

	local function createPreviewPart(shape: Enum.PartType?): Part
		local part = Instance.new("Part")
		part.Name = "TerrainBrushExtra"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = S.brushLocked and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(0, 162, 255)
		part.Transparency = 0.6
		if shape then
			part.Shape = shape
		end
		part.Parent = workspace
		return part
	end

	local function clearExtraParts()
		for _, part in ipairs(S.brushExtraParts) do
			part:Destroy()
		end
		S.brushExtraParts = {}
	end

	local function createBrushVisualization()
		if S.brushPart then
			S.brushPart:Destroy()
		end
		clearExtraParts()

		if S.brushShape == BrushShape.Wedge then
			S.brushPart = Instance.new("WedgePart")
		elseif S.brushShape == BrushShape.CornerWedge then
			S.brushPart = Instance.new("CornerWedgePart")
		else
			S.brushPart = Instance.new("Part")
			local part = S.brushPart :: Part
			if S.brushShape == BrushShape.Sphere or S.brushShape == BrushShape.Dome then
				part.Shape = Enum.PartType.Ball
			elseif
				S.brushShape == BrushShape.Cube
				or S.brushShape == BrushShape.Grid
				or S.brushShape == BrushShape.ZigZag
				or S.brushShape == BrushShape.Spinner
			then
				part.Shape = Enum.PartType.Block
			elseif
				S.brushShape == BrushShape.Cylinder
				or S.brushShape == BrushShape.Stick
				or S.brushShape == BrushShape.Torus
				or S.brushShape == BrushShape.Ring
				or S.brushShape == BrushShape.Sheet
			then
				part.Shape = Enum.PartType.Cylinder
			end
		end

		if S.brushPart then
			S.brushPart.Name = "TerrainBrushVisualization"
			S.brushPart.Anchored = true
			S.brushPart.CanCollide = false
			S.brushPart.CanQuery = false
			S.brushPart.CanTouch = false
			S.brushPart.CastShadow = false
			S.brushPart.Transparency = 0.7
			S.brushPart.Material = Enum.Material.Neon
			S.brushPart.Color = Color3.fromRGB(0, 162, 255)
			S.brushPart.Parent = workspace
		end
	end

	-- Calculate spin rotation based on mode
	local function calculateSpinRotation(spinMode: string, spinAngle: number): CFrame
		if spinMode == SpinMode.Off then
			return CFrame.new()
		elseif spinMode == SpinMode.Full3D then
			-- Original 3D rotation: all axes with different speeds
			return CFrame.Angles(spinAngle * 0.7, spinAngle, spinAngle * 0.3)
		elseif spinMode == SpinMode.XZ then
			-- Horizontal plane rotation only (around Y axis)
			return CFrame.Angles(0, spinAngle, 0)
		elseif spinMode == SpinMode.Y then
			-- Vertical axis rotation only (around Y axis, same as XZ but clearer name)
			return CFrame.Angles(0, spinAngle, 0)
		elseif spinMode == SpinMode.Fast3D then
			-- Faster 3D rotation (2x speed)
			return CFrame.Angles(spinAngle * 1.4, spinAngle * 2, spinAngle * 0.6)
		elseif spinMode == SpinMode.XZFast then
			-- Fast horizontal rotation (2x speed)
			return CFrame.Angles(0, spinAngle * 2, 0)
		else
			return CFrame.new()
		end
	end

	-- Update spin angle based on mode and speed
	local function updateSpinAngle(spinMode: string, currentAngle: number, deltaTime: number): number
		if spinMode == SpinMode.Off then
			return currentAngle
		elseif spinMode == SpinMode.Full3D then
			-- Original speed: 0.05 per frame (visualization), 0.1 per operation
			return currentAngle + 0.05
		elseif spinMode == SpinMode.XZ or spinMode == SpinMode.Y then
			-- Same speed as Full3D for consistency
			return currentAngle + 0.05
		elseif spinMode == SpinMode.Fast3D then
			-- 2x speed
			return currentAngle + 0.1
		elseif spinMode == SpinMode.XZFast then
			-- 2x speed
			return currentAngle + 0.1
		else
			return currentAngle
		end
	end

	local function updateBrushVisualization(position: Vector3)
		if not S.brushPart then
			createBrushVisualization()
		end

		if S.brushPart then
			local sizeX = S.brushSizeX * Constants.VOXEL_RESOLUTION
			local sizeY = S.brushSizeY * Constants.VOXEL_RESOLUTION
			local sizeZ = S.brushSizeZ * Constants.VOXEL_RESOLUTION

			S.brushPart.Transparency = 0.8 - (S.brushStrength * 0.3)

			if S.brushLocked then
				S.brushPart.Color = Color3.fromRGB(255, 170, 0)
			else
				S.brushPart.Color = Color3.fromRGB(0, 162, 255)
			end

			local baseCFrame = CFrame.new(position)

			if S.spinMode ~= SpinMode.Off and not S.brushLocked then
				S.spinAngle = updateSpinAngle(S.spinMode, S.spinAngle, 0)
			end

			local finalCFrame = baseCFrame
			if BrushData.ShapeSupportsRotation[S.brushShape] then
				finalCFrame = baseCFrame * S.brushRotation
			end
			if S.spinMode ~= SpinMode.Off then
				local spinCFrame = calculateSpinRotation(S.spinMode, S.spinAngle)
				finalCFrame = finalCFrame * spinCFrame
			end

			if S.brushShape == BrushShape.Sphere then
				S.brushPart.Size = Vector3.new(sizeX, sizeX, sizeX)
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Cube then
				S.brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Cylinder then
				-- Roblox PartType.Cylinder has height along Y axis
				-- FillCylinder also uses Y axis as height direction
				-- Size: (height, radius, radius) = (sizeY, sizeX, sizeX)
				S.brushPart.Size = Vector3.new(sizeY, sizeX, sizeX)
				-- Use the same finalCFrame as other shapes to ensure rotation handles match
				-- Both visualization and operation use Y as height, so no extra rotation needed
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Wedge then
				S.brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.CornerWedge then
				S.brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Dome then
				S.brushPart.Size = Vector3.new(sizeX, sizeY, sizeX)
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Torus then
				S.brushPart.Transparency = 1
				S.brushPart.Size = Vector3.new(1, 1, 1)
				S.brushPart.CFrame = finalCFrame
				clearExtraParts()
				local majorRadius = sizeX * 0.5
				local tubeRadius = sizeY * 0.5
				for i = 0, 11 do
					local angle = (i / 12) * math.pi * 2
					local localPos = Vector3.new(math.cos(angle) * majorRadius, 0, math.sin(angle) * majorRadius)
					local worldPos = finalCFrame:PointToWorldSpace(localPos)
					local sphere = createPreviewPart(Enum.PartType.Ball)
					sphere.Size = Vector3.new(tubeRadius * 2, tubeRadius * 2, tubeRadius * 2)
					sphere.CFrame = CFrame.new(worldPos)
					table.insert(S.brushExtraParts, sphere)
				end
			elseif S.brushShape == BrushShape.Ring then
				S.brushPart.Transparency = 1
				S.brushPart.Size = Vector3.new(1, 1, 1)
				S.brushPart.CFrame = finalCFrame
				clearExtraParts()
				local outerRadius = sizeX * 0.5
				local thickness = sizeY * 0.5
				for i = 0, 15 do
					local angle = (i / 16) * math.pi * 2
					local nextAngle = ((i + 1) / 16) * math.pi * 2
					local midAngle = (angle + nextAngle) / 2
					local localPos = Vector3.new(math.cos(midAngle) * outerRadius * 0.85, 0, math.sin(midAngle) * outerRadius * 0.85)
					local worldPos = finalCFrame:PointToWorldSpace(localPos)
					local seg = createPreviewPart(Enum.PartType.Block)
					seg.Size = Vector3.new(outerRadius * 0.4, thickness, outerRadius * 0.15)
					seg.CFrame = CFrame.new(worldPos) * CFrame.Angles(0, -midAngle, 0)
					table.insert(S.brushExtraParts, seg)
				end
			elseif S.brushShape == BrushShape.ZigZag then
				S.brushPart.Transparency = 1
				S.brushPart.Size = Vector3.new(1, 1, 1)
				S.brushPart.CFrame = finalCFrame
				clearExtraParts()
				local zigWidth = sizeX * 0.3
				local box1 = createPreviewPart(Enum.PartType.Block)
				box1.Size = Vector3.new(sizeX, sizeY * 0.3, zigWidth)
				box1.CFrame = finalCFrame * CFrame.new(0, sizeY * 0.35, -sizeZ * 0.3)
				table.insert(S.brushExtraParts, box1)
				local box2 = createPreviewPart(Enum.PartType.Block)
				box2.Size = Vector3.new(sizeX, sizeY * 0.5, zigWidth)
				box2.CFrame = finalCFrame * CFrame.Angles(math.rad(45), 0, 0)
				table.insert(S.brushExtraParts, box2)
				local box3 = createPreviewPart(Enum.PartType.Block)
				box3.Size = Vector3.new(sizeX, sizeY * 0.3, zigWidth)
				box3.CFrame = finalCFrame * CFrame.new(0, -sizeY * 0.35, sizeZ * 0.3)
				table.insert(S.brushExtraParts, box3)
			elseif S.brushShape == BrushShape.Sheet then
				S.brushPart.Transparency = 1
				S.brushPart.Size = Vector3.new(1, 1, 1)
				S.brushPart.CFrame = finalCFrame
				clearExtraParts()
				local sheetThickness = sizeZ * 0.1
				for i = 0, 7 do
					local t = (i / 7) - 0.5
					local angle = t * math.pi * 0.5
					local localPos = Vector3.new(0, math.sin(angle) * sizeY * 0.4, math.cos(angle) * sizeX * 0.4)
					local worldPos = finalCFrame:PointToWorldSpace(localPos)
					local seg = createPreviewPart(Enum.PartType.Block)
					seg.Size = Vector3.new(sizeX * 0.9, sizeY / 8 * 1.2, sheetThickness)
					seg.CFrame = CFrame.new(worldPos) * finalCFrame.Rotation * CFrame.Angles(angle, 0, 0)
					table.insert(S.brushExtraParts, seg)
				end
			elseif S.brushShape == BrushShape.Grid then
				S.brushPart.Transparency = 1
				S.brushPart.Size = Vector3.new(1, 1, 1)
				S.brushPart.CFrame = finalCFrame
				clearExtraParts()
				local gridSize = 3
				local cellSize = sizeX / gridSize
				for gx = 0, gridSize - 1 do
					for gy = 0, gridSize - 1 do
						for gz = 0, gridSize - 1 do
							if (gx + gy + gz) % 2 == 0 then
								local localPos = Vector3.new((gx - 1) * cellSize, (gy - 1) * cellSize, (gz - 1) * cellSize)
								local worldPos = finalCFrame:PointToWorldSpace(localPos)
								local cell = createPreviewPart(Enum.PartType.Block)
								cell.Size = Vector3.new(cellSize * 0.9, cellSize * 0.9, cellSize * 0.9)
								cell.CFrame = CFrame.new(worldPos) * finalCFrame.Rotation
								table.insert(S.brushExtraParts, cell)
							end
						end
					end
				end
			elseif S.brushShape == BrushShape.Stick then
				S.brushPart.Size = Vector3.new(sizeY, sizeX * 0.3, sizeX * 0.3)
				finalCFrame = baseCFrame * S.brushRotation * CFrame.Angles(0, 0, math.rad(90))
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Spikepad then
				local baseHeight = sizeY * 0.15
				S.brushPart.Size = Vector3.new(sizeX, baseHeight, sizeZ)
				S.brushPart.CFrame = finalCFrame * CFrame.new(0, -sizeY * 0.5 + baseHeight * 0.5, 0)
				clearExtraParts()
				local spikeHeight = sizeY * 0.85
				local spikeRadius = math.min(sizeX, sizeZ) * 0.12
				for col = 0, 2 do
					for row = 0, 2 do
						local xPos = (col - 1) * (sizeX * 0.33)
						local zPos = (row - 1) * (sizeZ * 0.33)
						local spikeBase = finalCFrame * CFrame.new(xPos, -sizeY * 0.5 + baseHeight, zPos)
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
							table.insert(S.brushExtraParts, wedge)
						end
					end
				end
			end

			if S.hollowEnabled then
				S.brushPart.Transparency = math.max(S.brushPart.Transparency, 0.7)
			end

			local extraColor = S.brushLocked and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(0, 162, 255)
			for _, extraPart in ipairs(S.brushExtraParts) do
				extraPart.Color = extraColor
				if S.hollowEnabled then
					extraPart.Transparency = math.max(extraPart.Transparency, 0.7)
				end
			end

			updateHandlesAdornee()
		end
	end

	local function hideBrushVisualization()
		if S.brushPart then
			S.brushPart:Destroy()
			S.brushPart = nil
		end
		for _, part in ipairs(S.brushExtraParts) do
			part:Destroy()
		end
		S.brushExtraParts = {}
		hideHandles()
	end

	-- ============================================================================
	-- 3D Handles for Rotation and Sizing
	-- ============================================================================

	local dragStartRotation = CFrame.new()

	local function createRotationHandles()
		if S.rotationHandles then
			S.rotationHandles:Destroy()
		end
		S.rotationHandles = Instance.new("ArcHandles")
		local handles = S.rotationHandles :: ArcHandles
		handles.Name = "BrushRotationHandles"
		handles.Color3 = Color3.fromRGB(255, 170, 0)
		handles.Visible = false
		handles.Parent = CoreGui
		handles.MouseButton1Down:Connect(function()
			S.isHandleDragging = true
			dragStartRotation = S.brushRotation
		end)
		handles.MouseButton1Up:Connect(function()
			S.isHandleDragging = false
		end)
		handles.MouseDrag:Connect(function(axis, relativeAngle, deltaRadius)
			local rotationAxis
			if axis == Enum.Axis.X then
				rotationAxis = Vector3.new(1, 0, 0)
			elseif axis == Enum.Axis.Y then
				rotationAxis = Vector3.new(0, 1, 0)
			else
				rotationAxis = Vector3.new(0, 0, 1)
			end
			S.brushRotation = dragStartRotation * CFrame.fromAxisAngle(rotationAxis, relativeAngle)
		end)
	end

	local function createSizeHandles()
		if S.sizeHandles then
			S.sizeHandles:Destroy()
		end
		S.sizeHandles = Instance.new("Handles")
		local handles = S.sizeHandles :: Handles
		handles.Name = "BrushSizeHandles"
		handles.Color3 = Color3.fromRGB(0, 200, 255)
		handles.Style = Enum.HandlesStyle.Resize
		handles.Visible = false
		handles.Parent = CoreGui
		local dragStartSizeX = S.brushSizeX
		local dragStartSizeY = S.brushSizeY
		local dragStartSizeZ = S.brushSizeZ
		handles.MouseButton1Down:Connect(function()
			S.isHandleDragging = true
			dragStartSizeX = S.brushSizeX
			dragStartSizeY = S.brushSizeY
			dragStartSizeZ = S.brushSizeZ
		end)
		handles.MouseButton1Up:Connect(function()
			S.isHandleDragging = false
		end)
		handles.MouseDrag:Connect(function(face, distance)
			if not S.isHandleDragging then
				return
			end
			local deltaVoxels = distance / Constants.VOXEL_RESOLUTION
			local sizingMode = BrushData.ShapeSizingMode[S.brushShape] or "uniform"
			if sizingMode == "uniform" then
				local newSize = math.clamp(dragStartSizeX + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				S.brushSizeX = newSize
				S.brushSizeY = newSize
				S.brushSizeZ = newSize
			else
				-- "box" mode: independent X, Y, Z sizing
				if face == Enum.NormalId.Right or face == Enum.NormalId.Left then
					S.brushSizeX = math.clamp(dragStartSizeX + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
					S.brushSizeY = math.clamp(dragStartSizeY + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				else
					S.brushSizeZ = math.clamp(dragStartSizeZ + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				end
			end
		end)
	end

	updateHandlesAdornee = function()
		if S.rotationHandles then
			S.rotationHandles.Adornee = S.brushPart
			S.rotationHandles.Visible = S.brushPart ~= nil and BrushData.ShapeSupportsRotation[S.brushShape] == true
		end
		if S.sizeHandles then
			S.sizeHandles.Adornee = S.brushPart
			S.sizeHandles.Visible = S.brushPart ~= nil
		end
	end

	hideHandles = function()
		if S.rotationHandles then
			S.rotationHandles.Visible = false
			S.rotationHandles.Adornee = nil
		end
		if S.sizeHandles then
			S.sizeHandles.Visible = false
			S.sizeHandles.Adornee = nil
		end
		S.isHandleDragging = false
	end

	destroyHandles = function()
		if S.rotationHandles then
			S.rotationHandles:Destroy()
			S.rotationHandles = nil
		end
		if S.sizeHandles then
			S.sizeHandles:Destroy()
			S.sizeHandles = nil
		end
		S.isHandleDragging = false
	end

	createRotationHandles()
	createSizeHandles()

	-- ============================================================================
	-- Plane Visualization
	-- ============================================================================

	local PLANE_SIZE = 200

	local function createPlaneVisualization()
		if S.planePart then
			S.planePart:Destroy()
		end
		S.planePart = Instance.new("Part")
		local part = S.planePart :: Part
		part.Name = "TerrainPlaneLockVisualization"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.5, PLANE_SIZE, PLANE_SIZE)
		part.Transparency = 0.85
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(0, 200, 100)
		part.Parent = workspace
	end

	local function updatePlaneVisualization(centerX: number, centerZ: number)
		if not S.planePart then
			createPlaneVisualization()
		end
		if S.planePart then
			S.planePart.CFrame = CFrame.new(centerX, S.planePositionY, centerZ) * CFrame.Angles(0, 0, math.rad(90))
		end
	end

	local function hidePlaneVisualization()
		if S.planePart then
			S.planePart:Destroy()
			S.planePart = nil
		end
	end

	-- ============================================================================
	-- Terrain Operations
	-- ============================================================================

	local function intersectPlane(ray: any): Vector3?
		if ray.Direction.Y ~= 0 then
			local t = (S.planePositionY - ray.Origin.Y) / ray.Direction.Y
			if t > 0 and t < 10000 then
				return ray.Origin + ray.Direction * t
			end
		end
		return nil
	end

	local function getTerrainHit(): Vector3?
		local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local filterInstances: { Instance } = {}
		if S.brushPart then
			table.insert(filterInstances, S.brushPart)
		end
		if S.planePart then
			table.insert(filterInstances, S.planePart)
		end
		raycastParams.FilterDescendantsInstances = filterInstances
		local usePlaneLock = (S.planeLockMode == PlaneLockType.Manual) or (S.planeLockMode == PlaneLockType.Auto and S.autoPlaneActive)
		if usePlaneLock then
			local planeHit = intersectPlane(ray)
			if planeHit then
				return planeHit
			end
		end
		local result = workspace:Raycast(ray.Origin, ray.Direction * 10000, raycastParams)
		if result and result.Instance == S.terrain then
			return result.Position
		end
		if result then
			return result.Position
		end
		if ray.Direction.Y ~= 0 then
			local t = -ray.Origin.Y / ray.Direction.Y
			if t > 0 and t < 10000 then
				return ray.Origin + ray.Direction * t
			end
		end
		if mouse.Hit then
			return mouse.Hit.Position
		end
		return ray.Origin + ray.Direction * 50
	end

	local function getTerrainHitRaw(): Vector3?
		local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local filterInstances: { Instance } = {}
		if S.brushPart then
			table.insert(filterInstances, S.brushPart)
		end
		if S.planePart then
			table.insert(filterInstances, S.planePart)
		end
		raycastParams.FilterDescendantsInstances = filterInstances
		local result = workspace:Raycast(ray.Origin, ray.Direction * 10000, raycastParams)
		if result then
			return result.Position
		end
		if ray.Direction.Y ~= 0 then
			local t = -ray.Origin.Y / ray.Direction.Y
			if t > 0 and t < 10000 then
				return ray.Origin + ray.Direction * t
			end
		end
		return nil
	end

	local function performBrushOperation(position: Vector3)
		local usePlaneLock = (S.planeLockMode == PlaneLockType.Manual) or (S.planeLockMode == PlaneLockType.Auto and S.autoPlaneActive)
		local planePoint = usePlaneLock and Vector3.new(position.X, S.planePositionY, position.Z) or position
		local planeNormal = Vector3.new(0, 1, 0)
		local actualSizeX = S.brushSizeX
		local actualSizeY = S.brushSizeY
		local actualSizeZ = S.brushSizeZ
		local sizingMode = BrushData.ShapeSizingMode[S.brushShape] or "uniform"
		if sizingMode == "uniform" then
			actualSizeY = S.brushSizeX
			actualSizeZ = S.brushSizeX
		end
		-- For "box" mode, use the actual stored values (no modification needed)
		local effectiveRotation = S.brushRotation
		if not BrushData.ShapeSupportsRotation[S.brushShape] then
			effectiveRotation = CFrame.new()
		end
		if S.spinMode ~= SpinMode.Off then
			-- For operations, use faster update (0.1 instead of 0.05)
			local operationSpeed = 1
			if S.spinMode == SpinMode.Fast3D or S.spinMode == SpinMode.XZFast then
				operationSpeed = 2
			end
			S.spinAngle = S.spinAngle + (0.1 * operationSpeed)
			local spinCFrame = calculateSpinRotation(S.spinMode, S.spinAngle)
			effectiveRotation = effectiveRotation * spinCFrame
		end
		local opSet = {
			currentTool = S.currentTool,
			brushShape = S.brushShape,
			flattenMode = S.flattenMode,
			pivot = S.pivotType,
			centerPoint = position,
			planePoint = planePoint,
			planeNormal = planeNormal,
			cursorSizeX = actualSizeX,
			cursorSizeY = actualSizeY,
			cursorSizeZ = actualSizeZ,
			cursorSize = actualSizeX,
			cursorHeight = actualSizeY,
			strength = S.brushStrength,
			autoMaterial = S.autoMaterial,
			material = S.brushMaterial,
			ignoreWater = S.ignoreWater,
			source = Enum.Material.Grass,
			target = S.brushMaterial,
			brushRotation = effectiveRotation,
			hollowEnabled = S.hollowEnabled,
			wallThickness = S.wallThickness,
			noiseScale = S.noiseScale,
			noiseIntensity = S.noiseIntensity,
			noiseSeed = S.noiseSeed,
			stepHeight = S.stepHeight,
			stepSharpness = S.stepSharpness,
			cliffAngle = S.cliffAngle,
			cliffDirectionX = S.cliffDirectionX,
			cliffDirectionZ = S.cliffDirectionZ,
			-- Path tool parameters
			pathDepth = S.pathDepth,
			pathProfile = S.pathProfile,
			pathDirectionX = S.pathDirectionX,
			pathDirectionZ = S.pathDirectionZ,
			-- Clone tool parameters
			cloneSourceBuffer = S.cloneSourceBuffer,
			cloneSourceCenter = S.cloneSourceCenter,
			-- Blobify tool parameters
			blobIntensity = S.blobIntensity,
			blobSmoothness = S.blobSmoothness,
		}
		local success, err = pcall(function()
			performTerrainBrushOperation(S.terrain, opSet)
		end)
		if not success then
			warn("[TerrainEditorFork] Brush operation failed:", err)
		end
	end

	local function startBrushing()
		if S.brushConnection then
			return
		end
		ChangeHistoryService:SetWaypoint("TerrainEdit_Start")
		S.brushConnection = RunService.Heartbeat:Connect(function()
			if not S.isMouseDown or S.currentTool == ToolId.None or S.isHandleDragging or S.brushLocked then
				return
			end

			local hitPosition = getTerrainHit()
			if not hitPosition then
				return
			end

			local shouldActivate = false
			local mouseMoved = false

			-- Check if mouse has moved significantly since last brush operation
			-- Use a larger threshold to prevent excessive activations from tiny movements
			-- One voxel = 4 studs, so 4 studs is a reasonable minimum movement
			local MOVEMENT_THRESHOLD = 4 -- studs
			if S.lastBrushPosition then
				local moveDistance = (hitPosition - S.lastBrushPosition).Magnitude
				if moveDistance > MOVEMENT_THRESHOLD then
					mouseMoved = true
				end
			end

			local now = tick()
			local timeSinceLastActivation = now - S.lastBrushTime

			-- Handle "no_repeat" mode - only activate once per mouse down, never again until mouse is released
			if S.brushRate == "no_repeat" then
				if S.lastBrushTime == 0 then
					-- First activation on mouse down
					shouldActivate = true
					S.lastBrushTime = now
				else
					-- Already activated once, don't repeat even if mouse moved
					shouldActivate = false
				end
			elseif S.brushRate == "on_move_only" then
				-- Paint style: activate once on click, then only reactivate when mouse moves significantly
				if S.lastBrushTime == 0 then
					-- First activation on mouse down
					shouldActivate = true
					S.lastBrushTime = now
				else
					-- Only reactivate if mouse moved significantly
					shouldActivate = mouseMoved
					if mouseMoved then
						S.lastBrushTime = now
					end
				end
			else
				-- Repeat mode: activate on timer OR mouse movement (but movement also needs minimum time)
				local rateMap = {
					very_slow = 1000, -- 1 second between activations
					slow = 500,       -- 0.5 seconds
					normal = 200,     -- 0.2 seconds
					fast = 100,       -- 0.1 seconds
				}
				local brushCooldownMs = rateMap[S.brushRate] or 100
				local brushCooldown = brushCooldownMs / 1000 -- Convert milliseconds to seconds
				
				-- Minimum time between activations, even for movement (prevents excessive activations)
				local minCooldown = 0.05 -- 50ms minimum between any activations
				
				if mouseMoved and timeSinceLastActivation >= minCooldown then
					-- Mouse moved significantly AND enough time has passed
					shouldActivate = true
					S.lastBrushTime = now
				elseif timeSinceLastActivation >= brushCooldown then
					-- Timer cooldown has passed
					shouldActivate = true
					S.lastBrushTime = now
				end
			end

			if shouldActivate then
				-- Track mouse direction for Cliff and Path tools
				if (S.currentTool == ToolId.Cliff or S.currentTool == ToolId.Path) and S.lastMouseWorldPos then
					local delta = hitPosition - S.lastMouseWorldPos
					local horizDelta = Vector3.new(delta.X, 0, delta.Z)
					if horizDelta.Magnitude > 0.5 then
						local dir = horizDelta.Unit
						if S.currentTool == ToolId.Cliff then
							S.cliffDirectionX = dir.X
							S.cliffDirectionZ = dir.Z
						elseif S.currentTool == ToolId.Path then
							S.pathDirectionX = dir.X
							S.pathDirectionZ = dir.Z
						end
					end
				end
				S.lastMouseWorldPos = hitPosition
				performBrushOperation(hitPosition)
				S.lastBrushPosition = hitPosition
			end
		end)
	end

	local function stopBrushing()
		if S.brushConnection then
			S.brushConnection:Disconnect()
			S.brushConnection = nil
		end
		ChangeHistoryService:SetWaypoint("TerrainEdit_End")
		S.lastBrushPosition = nil
		S.lastBrushTime = 0 -- Reset for "no_repeat" mode
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

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Name = "VersionLabel"
	versionLabel.BackgroundTransparency = 1
	versionLabel.Position = UDim2.new(1, -8, 0, 4)
	versionLabel.Size = UDim2.new(0, 100, 0, 14)
	versionLabel.AnchorPoint = Vector2.new(1, 0)
	versionLabel.Font = Enum.Font.Gotham
	versionLabel.TextSize = 10
	versionLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
	versionLabel.TextXAlignment = Enum.TextXAlignment.Right
	versionLabel.Text = "v" .. VERSION
	versionLabel.ZIndex = 10
	versionLabel.Parent = parentGui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 18)
	padding.PaddingTop = UDim.new(0, 8)
	padding.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 0, 0, 0)
	title.Size = UDim2.new(1, 0, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "🌋 Terrain Editor Fork v" .. VERSION
	title.Parent = mainFrame

	UIHelpers.createHeader(mainFrame, "Tools", UDim2.new(0, 0, 0, 35))

	local sculptTools = {
		{ id = ToolId.Add, name = "Add", row = 0, col = 0 },
		{ id = ToolId.Subtract, name = "Subtract", row = 0, col = 1 },
		{ id = ToolId.Grow, name = "Grow", row = 0, col = 2 },
		{ id = ToolId.Erode, name = "Erode", row = 1, col = 0 },
		{ id = ToolId.Smooth, name = "Smooth", row = 1, col = 1 },
		{ id = ToolId.Flatten, name = "Flatten", row = 1, col = 2 },
		{ id = ToolId.Noise, name = "Noise", row = 2, col = 0 },
		{ id = ToolId.Terrace, name = "Terrace", row = 2, col = 1 },
		{ id = ToolId.Cliff, name = "Cliff", row = 2, col = 2 },
		{ id = ToolId.Path, name = "Path", row = 3, col = 0 },
		{ id = ToolId.Clone, name = "Clone", row = 3, col = 1 },
		{ id = ToolId.Blobify, name = "Blobify", row = 3, col = 2 },
		{ id = ToolId.Paint, name = "Paint", row = 3, col = 3 },
		{ id = ToolId.Bridge, name = "Bridge", row = 4, col = 0 },
	}

	for _, toolInfo in ipairs(sculptTools) do
		local pos = UDim2.new(0, toolInfo.col * 78, 0, 60 + toolInfo.row * 38)
		local btn = UIHelpers.createToolButton(mainFrame, toolInfo.id, toolInfo.name, pos)
		toolButtons[toolInfo.id] = btn
		btn.MouseButton1Click:Connect(function()
			selectTool(toolInfo.id)
		end)
	end

	local CONFIG_START_Y = 243

	local configContainer = Instance.new("Frame")
	configContainer.Name = "ConfigContainer"
	configContainer.BackgroundTransparency = 1
	configContainer.Position = UDim2.new(0, 0, 0, CONFIG_START_Y)
	configContainer.Size = UDim2.new(1, 0, 0, 800)
	configContainer.Parent = mainFrame

	-- Brush Shape Panel
	local shapePanel = UIHelpers.createConfigPanel(configContainer, "brushShape")
	UIHelpers.createHeader(shapePanel, "Brush Shape", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1

	local shapeButtonsContainer = Instance.new("Frame")
	shapeButtonsContainer.BackgroundTransparency = 1
	shapeButtonsContainer.Size = UDim2.new(1, 0, 0, 0)
	shapeButtonsContainer.AutomaticSize = Enum.AutomaticSize.Y
	shapeButtonsContainer.LayoutOrder = 2
	shapeButtonsContainer.Parent = shapePanel

	local shapeGridLayout = Instance.new("UIGridLayout")
	shapeGridLayout.CellSize = UDim2.new(0, 70, 0, 28)
	shapeGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	shapeGridLayout.FillDirection = Enum.FillDirection.Horizontal
	shapeGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	shapeGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	shapeGridLayout.Parent = shapeButtonsContainer

	local shapeButtons = {}

	local function updateShapeButtons()
		for shapeId, btn in pairs(shapeButtons) do
			if shapeId == S.brushShape then
				btn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
			else
				btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			end
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	for i, shapeInfo in ipairs(BrushData.Shapes) do
		local btn = UIHelpers.createButton(shapeButtonsContainer, shapeInfo.name, UDim2.new(0, 0, 0, 0), UDim2.new(0, 70, 0, 28), function()
			S.brushShape = shapeInfo.id
			updateShapeButtons()
			if S.brushPart then
				createBrushVisualization()
			end
		end)
		btn.LayoutOrder = i
		shapeButtons[shapeInfo.id] = btn
	end
	updateShapeButtons()
	configPanels["brushShape"] = shapePanel

	-- Strength Panel
	local strengthPanel = UIHelpers.createConfigPanel(configContainer, "strength")
	UIHelpers.createHeader(strengthPanel, "Strength", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1
	local _strengthSliderLabel, strengthSliderContainer, setStrengthValue = UIHelpers.createSlider(
		strengthPanel,
		"Strength",
		1,
		100,
		math.floor(S.brushStrength * 100),
		function(value: number)
			S.brushStrength = value / 100
		end
	)
	strengthSliderContainer.LayoutOrder = 2
	configPanels["strength"] = strengthPanel

	-- Brush Rate Panel
	local brushRatePanel = UIHelpers.createConfigPanel(configContainer, "brushRate")
	UIHelpers.createHeader(brushRatePanel, "Brush Rate", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1

	local brushRateButtonsContainer = Instance.new("Frame")
	brushRateButtonsContainer.BackgroundTransparency = 1
	brushRateButtonsContainer.Size = UDim2.new(1, 0, 0, 35)
	brushRateButtonsContainer.LayoutOrder = 2
	brushRateButtonsContainer.Parent = brushRatePanel

	local brushRates = {
		{ id = "no_repeat", name = "No repeat" },
		{ id = "on_move_only", name = "On move" },
		{ id = "very_slow", name = "Very slow" },
		{ id = "slow", name = "Slow" },
		{ id = "normal", name = "Normal" },
		{ id = "fast", name = "Fast" },
	}
	local brushRateButtons = {}
	local function updateBrushRateButtons()
		for rateId, btn in pairs(brushRateButtons) do
			btn.BackgroundColor3 = (rateId == S.brushRate) and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
	for i, rateInfo in ipairs(brushRates) do
		local btn = UIHelpers.createButton(
			brushRateButtonsContainer,
			rateInfo.name,
			UDim2.new(0, (i - 1) * 78, 0, 0),
			UDim2.new(0, 70, 0, 28),
			function()
				S.brushRate = rateInfo.id
				updateBrushRateButtons()
			end
		)
		brushRateButtons[rateInfo.id] = btn
	end
	updateBrushRateButtons()
	configPanels["brushRate"] = brushRatePanel

	-- Pivot Panel
	local pivotPanel = UIHelpers.createConfigPanel(configContainer, "pivot")
	UIHelpers.createHeader(pivotPanel, "Pivot Position", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1
	local pivotButtonsContainer = Instance.new("Frame")
	pivotButtonsContainer.BackgroundTransparency = 1
	pivotButtonsContainer.Size = UDim2.new(1, 0, 0, 35)
	pivotButtonsContainer.LayoutOrder = 2
	pivotButtonsContainer.Parent = pivotPanel
	local pivots =
		{ { id = PivotType.Bottom, name = "Bottom" }, { id = PivotType.Center, name = "Center" }, { id = PivotType.Top, name = "Top" } }
	local pivotButtons = {}
	local function updatePivotButtons()
		for pivotId, btn in pairs(pivotButtons) do
			btn.BackgroundColor3 = (pivotId == S.pivotType) and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
	for i, pivotInfo in ipairs(pivots) do
		local btn = UIHelpers.createButton(
			pivotButtonsContainer,
			pivotInfo.name,
			UDim2.new(0, (i - 1) * 78, 0, 0),
			UDim2.new(0, 70, 0, 28),
			function()
				S.pivotType = pivotInfo.id
				updatePivotButtons()
			end
		)
		pivotButtons[pivotInfo.id] = btn
	end
	updatePivotButtons()
	configPanels["pivot"] = pivotPanel

	-- Hollow Mode Panel
	local hollowPanel = UIHelpers.createConfigPanel(configContainer, "hollow")
	UIHelpers.createHeader(hollowPanel, "Hollow Mode", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1
	local hollowToggleBtn: TextButton? = nil
	local hollowThicknessContainer: Frame? = nil
	local function updateHollowButton()
		if hollowToggleBtn then
			hollowToggleBtn.BackgroundColor3 = S.hollowEnabled and Color3.fromRGB(100, 50, 150) or Color3.fromRGB(50, 50, 50)
			hollowToggleBtn.Text = S.hollowEnabled and "HOLLOW" or "Solid"
		end
		if hollowThicknessContainer then
			hollowThicknessContainer.Visible = S.hollowEnabled
		end
	end
	hollowToggleBtn = UIHelpers.createButton(hollowPanel, "Solid", UDim2.new(0, 0, 0, 0), UDim2.new(0, 100, 0, 28), function()
		S.hollowEnabled = not S.hollowEnabled
		updateHollowButton()
	end)
	if hollowToggleBtn then
		hollowToggleBtn.LayoutOrder = 2
	end
	local _, thicknessSliderContainer, _ = UIHelpers.createSlider(
		hollowPanel,
		"Thickness",
		10,
		50,
		math.floor(S.wallThickness * 100),
		function(val: number)
			S.wallThickness = val / 100
		end
	)
	thicknessSliderContainer.LayoutOrder = 3
	hollowThicknessContainer = thicknessSliderContainer
	if hollowThicknessContainer then
		hollowThicknessContainer.Visible = false
	end
	updateHollowButton()
	configPanels["hollow"] = hollowPanel

	-- Spin Mode Panel
	local spinPanel = UIHelpers.createConfigPanel(configContainer, "spin")
	UIHelpers.createHeader(spinPanel, "Spin Mode", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1
	local spinButtonsContainer = Instance.new("Frame")
	spinButtonsContainer.BackgroundTransparency = 1
	spinButtonsContainer.Size = UDim2.new(1, 0, 0, 0)
	spinButtonsContainer.AutomaticSize = Enum.AutomaticSize.Y
	spinButtonsContainer.LayoutOrder = 2
	spinButtonsContainer.Parent = spinPanel
	local spinLayout = Instance.new("UIListLayout")
	spinLayout.SortOrder = Enum.SortOrder.LayoutOrder
	spinLayout.Padding = UDim.new(0, 6)
	spinLayout.Parent = spinButtonsContainer
	local spinModes = {
		{ id = SpinMode.Off, name = "Off" },
		{ id = SpinMode.Full3D, name = "3D" },
		{ id = SpinMode.XZ, name = "XZ" },
		{ id = SpinMode.Fast3D, name = "Fast 3D" },
		{ id = SpinMode.XZFast, name = "Fast XZ" },
	}
	local spinButtons: { [string]: TextButton } = {}
	local function updateSpinButtons()
		for modeId, btn in pairs(spinButtons) do
			btn.BackgroundColor3 = (modeId == S.spinMode) and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
	for i, modeInfo in ipairs(spinModes) do
		local btn = Instance.new("TextButton")
		btn.Name = modeInfo.id
		btn.Size = UDim2.new(0, 80, 0, 28)
		btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 11
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Text = modeInfo.name
		btn.LayoutOrder = i
		btn.Parent = spinButtonsContainer
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn
		btn.MouseButton1Click:Connect(function()
			S.spinMode = modeInfo.id
			updateSpinButtons()
		end)
		spinButtons[modeInfo.id] = btn
	end
	updateSpinButtons()
	configPanels["spin"] = spinPanel

	-- Plane Lock Panel
	local planeLockPanel = UIHelpers.createConfigPanel(configContainer, "planeLock")
	UIHelpers.createHeader(planeLockPanel, "Plane Lock", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1
	local planeLockModeContainer = Instance.new("Frame")
	planeLockModeContainer.BackgroundTransparency = 1
	planeLockModeContainer.Size = UDim2.new(1, 0, 0, 28)
	planeLockModeContainer.LayoutOrder = 2
	planeLockModeContainer.Parent = planeLockPanel
	local planeLockModeButtons = {}
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
	local function updatePlaneLockModeButtons()
		for modeId, btn in pairs(planeLockModeButtons) do
			btn.BackgroundColor3 = (modeId == S.planeLockMode) and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
	local function updatePlaneLockVisuals()
		manualControlsContainer.Visible = (S.planeLockMode == PlaneLockType.Manual)
		if S.planeLockMode == PlaneLockType.Off then
			hidePlaneVisualization()
		end
	end
	local planeLockModes = {
		{ id = PlaneLockType.Off, name = "Off" },
		{ id = PlaneLockType.Auto, name = "Auto" },
		{ id = PlaneLockType.Manual, name = "Manual" },
	}
	for i, modeInfo in ipairs(planeLockModes) do
		local btn = UIHelpers.createButton(
			planeLockModeContainer,
			modeInfo.name,
			UDim2.new(0, (i - 1) * 78, 0, 0),
			UDim2.new(0, 70, 0, 28),
			function()
				S.planeLockMode = modeInfo.id
				S.autoPlaneActive = false
				updatePlaneLockModeButtons()
				updatePlaneLockVisuals()
			end
		)
		planeLockModeButtons[modeInfo.id] = btn
	end
	local _, planeHeightContainer, setPlaneHeightValue = UIHelpers.createSlider(
		manualControlsContainer,
		"Height",
		-100,
		500,
		S.planePositionY,
		function(value)
			S.planePositionY = value
		end
	)
	planeHeightContainer.LayoutOrder = 1
	local setHeightBtnContainer = Instance.new("Frame")
	setHeightBtnContainer.BackgroundTransparency = 1
	setHeightBtnContainer.Size = UDim2.new(1, 0, 0, 28)
	setHeightBtnContainer.LayoutOrder = 2
	setHeightBtnContainer.Parent = manualControlsContainer
	local setHeightBtn = UIHelpers.createButton(
		setHeightBtnContainer,
		"Set from Cursor",
		UDim2.new(0, 0, 0, 0),
		UDim2.new(0, 120, 0, 28),
		function() end
	)
	setHeightBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	setHeightBtn.MouseButton1Click:Connect(function()
		local hitPosition = getTerrainHitRaw()
		if hitPosition then
			S.planePositionY = math.floor(hitPosition.Y + 0.5)
			setPlaneHeightValue(S.planePositionY)
		end
	end)
	updatePlaneLockModeButtons()
	updatePlaneLockVisuals()
	configPanels["planeLock"] = planeLockPanel

	-- Flatten Mode Panel
	local flattenModePanel = UIHelpers.createConfigPanel(configContainer, "flattenMode")
	UIHelpers.createHeader(flattenModePanel, "Flatten Mode", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1
	local flattenButtonsContainer = Instance.new("Frame")
	flattenButtonsContainer.BackgroundTransparency = 1
	flattenButtonsContainer.Size = UDim2.new(1, 0, 0, 35)
	flattenButtonsContainer.LayoutOrder = 2
	flattenButtonsContainer.Parent = flattenModePanel
	local flattenModes =
		{ { id = FlattenMode.Erode, name = "Erode" }, { id = FlattenMode.Both, name = "Both" }, { id = FlattenMode.Grow, name = "Grow" } }
	local flattenButtons = {}
	local function updateFlattenButtons()
		for modeId, btn in pairs(flattenButtons) do
			btn.BackgroundColor3 = (modeId == S.flattenMode) and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
	for i, modeInfo in ipairs(flattenModes) do
		local btn = UIHelpers.createButton(
			flattenButtonsContainer,
			modeInfo.name,
			UDim2.new(0, (i - 1) * 78, 0, 0),
			UDim2.new(0, 70, 0, 28),
			function()
				S.flattenMode = modeInfo.id
				updateFlattenButtons()
			end
		)
		flattenButtons[modeInfo.id] = btn
	end
	updateFlattenButtons()
	configPanels["flattenMode"] = flattenModePanel

	-- Material Panel
	local materialPanel = UIHelpers.createConfigPanel(configContainer, "material")
	UIHelpers.createHeader(materialPanel, "Material", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1
	local materialGridContainer = Instance.new("Frame")
	materialGridContainer.Name = "MaterialGrid"
	materialGridContainer.BackgroundTransparency = 1
	materialGridContainer.Size = UDim2.new(1, 0, 0, 0)
	materialGridContainer.AutomaticSize = Enum.AutomaticSize.Y
	materialGridContainer.LayoutOrder = 2
	materialGridContainer.Parent = materialPanel
	local materialButtons = {}
	local function updateMaterialButtons()
		for mat, container in pairs(materialButtons) do
			local tileBtn = container:FindFirstChild("TileButton")
			if tileBtn then
				local border = tileBtn:FindFirstChild("SelectionBorder") :: UIStroke?
				if border then
					border.Transparency = (mat == S.brushMaterial) and 0 or 1
				end
			end
		end
	end
	local materialGridLayout = Instance.new("UIGridLayout")
	materialGridLayout.CellSize = UDim2.new(0, 72, 0, 94)
	materialGridLayout.CellPadding = UDim2.new(0, 6, 0, 8)
	materialGridLayout.FillDirection = Enum.FillDirection.Horizontal
	materialGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	materialGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	materialGridLayout.Parent = materialGridContainer

	for i, matInfo in ipairs(BrushData.Materials) do
		local container = Instance.new("Frame")
		container.Name = matInfo.key
		container.BackgroundTransparency = 1
		container.Size = UDim2.new(0, 72, 0, 94)
		container.LayoutOrder = i
		container.Parent = materialGridContainer
		local tileBtn = Instance.new("ImageButton")
		tileBtn.Name = "TileButton"
		tileBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		tileBtn.BorderSizePixel = 0
		tileBtn.Size = UDim2.new(0, 72, 0, 72)
		tileBtn.Image = BrushData.TerrainTileAssets[matInfo.key] or ""
		tileBtn.ScaleType = Enum.ScaleType.Crop
		tileBtn.Parent = container
		local tileCorner = Instance.new("UICorner")
		tileCorner.CornerRadius = UDim.new(0, 6)
		tileCorner.Parent = tileBtn
		local selectionBorder = Instance.new("UIStroke")
		selectionBorder.Name = "SelectionBorder"
		selectionBorder.Color = Color3.fromRGB(0, 180, 255)
		selectionBorder.Thickness = 3
		selectionBorder.Transparency = (matInfo.enum == S.brushMaterial) and 0 or 1
		selectionBorder.Parent = tileBtn
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0, 0, 0, 74)
		label.Size = UDim2.new(1, 0, 0, 18)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = matInfo.name
		label.Parent = container
		materialButtons[matInfo.enum] = container
		tileBtn.MouseButton1Click:Connect(function()
			S.brushMaterial = matInfo.enum
			updateMaterialButtons()
		end)
	end
	updateMaterialButtons()
	configPanels["material"] = materialPanel

	-- ============================================================================
	-- Path Tool Panels
	-- ============================================================================

	-- Path Depth Panel
	local pathDepthPanel = UIHelpers.createConfigPanel(configContainer, "pathDepth")
	UIHelpers.createHeader(pathDepthPanel, "Path Depth", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1

	local pathDepthDesc = Instance.new("TextLabel")
	pathDepthDesc.BackgroundTransparency = 1
	pathDepthDesc.Size = UDim2.new(1, 0, 0, 16)
	pathDepthDesc.Font = Enum.Font.Gotham
	pathDepthDesc.TextSize = 11
	pathDepthDesc.TextColor3 = Color3.fromRGB(180, 180, 180)
	pathDepthDesc.TextXAlignment = Enum.TextXAlignment.Left
	pathDepthDesc.Text = "How deep the channel is in studs"
	pathDepthDesc.LayoutOrder = 2
	pathDepthDesc.Parent = pathDepthPanel

	local _, pathDepthContainer, _setPathDepth = UIHelpers.createSlider(pathDepthPanel, "Depth", 2, 20, S.pathDepth, function(value)
		S.pathDepth = value
	end)
	pathDepthContainer.LayoutOrder = 3

	configPanels["pathDepth"] = pathDepthPanel

	-- Path Profile Panel
	local pathProfilePanel = UIHelpers.createConfigPanel(configContainer, "pathProfile")
	UIHelpers.createHeader(pathProfilePanel, "Path Profile", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1

	local pathProfileButtonsContainer = Instance.new("Frame")
	pathProfileButtonsContainer.BackgroundTransparency = 1
	pathProfileButtonsContainer.Size = UDim2.new(1, 0, 0, 35)
	pathProfileButtonsContainer.LayoutOrder = 2
	pathProfileButtonsContainer.Parent = pathProfilePanel

	local pathProfiles = { { id = "V", name = "V" }, { id = "U", name = "U" }, { id = "Flat", name = "Flat" } }
	local pathProfileButtons = {}
	local function updatePathProfileButtons()
		for profileId, btn in pairs(pathProfileButtons) do
			btn.BackgroundColor3 = (profileId == S.pathProfile) and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	for i, profileInfo in ipairs(pathProfiles) do
		local btn = UIHelpers.createButton(
			pathProfileButtonsContainer,
			profileInfo.name,
			UDim2.new(0, (i - 1) * 80, 0, 0),
			UDim2.new(0, 70, 0, 28),
			function()
				S.pathProfile = profileInfo.id
				updatePathProfileButtons()
			end
		)
		pathProfileButtons[profileInfo.id] = btn
	end
	updatePathProfileButtons()

	configPanels["pathProfile"] = pathProfilePanel

	-- Path Direction Info Panel
	local pathDirectionInfoPanel = UIHelpers.createConfigPanel(configContainer, "pathDirectionInfo")
	UIHelpers.createHeader(pathDirectionInfoPanel, "Path Direction", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1

	local pathDirDesc = Instance.new("TextLabel")
	pathDirDesc.BackgroundTransparency = 1
	pathDirDesc.Size = UDim2.new(1, 0, 0, 32)
	pathDirDesc.Font = Enum.Font.Gotham
	pathDirDesc.TextSize = 12
	pathDirDesc.TextColor3 = Color3.fromRGB(255, 255, 255)
	pathDirDesc.TextXAlignment = Enum.TextXAlignment.Left
	pathDirDesc.TextWrapped = true
	pathDirDesc.Text = "Drag mouse to set channel direction"
	pathDirDesc.LayoutOrder = 2
	pathDirDesc.Parent = pathDirectionInfoPanel

	configPanels["pathDirectionInfo"] = pathDirectionInfoPanel

	-- ============================================================================
	-- Clone Tool Panels
	-- ============================================================================

	local cloneInfoPanel = UIHelpers.createConfigPanel(configContainer, "cloneInfo")
	UIHelpers.createHeader(cloneInfoPanel, "Clone Tool", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1

	local cloneInstructions = Instance.new("TextLabel")
	cloneInstructions.BackgroundTransparency = 1
	cloneInstructions.Size = UDim2.new(1, 0, 0, 48)
	cloneInstructions.Font = Enum.Font.Gotham
	cloneInstructions.TextSize = 12
	cloneInstructions.TextColor3 = Color3.fromRGB(255, 255, 255)
	cloneInstructions.TextXAlignment = Enum.TextXAlignment.Left
	cloneInstructions.TextWrapped = true
	cloneInstructions.Text = "Alt+Click to sample source, then click to stamp"
	cloneInstructions.LayoutOrder = 2
	cloneInstructions.Parent = cloneInfoPanel

	local cloneStatusLabel = Instance.new("TextLabel")
	cloneStatusLabel.Name = "Status"
	cloneStatusLabel.BackgroundTransparency = 1
	cloneStatusLabel.Size = UDim2.new(1, 0, 0, 20)
	cloneStatusLabel.Font = Enum.Font.Gotham
	cloneStatusLabel.TextSize = 11
	cloneStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	cloneStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
	cloneStatusLabel.Text = "Status: No source sampled"
	cloneStatusLabel.LayoutOrder = 3
	cloneStatusLabel.Parent = cloneInfoPanel

	configPanels["cloneInfo"] = cloneInfoPanel

	-- ============================================================================
	-- Blobify Tool Panels
	-- ============================================================================

	-- Blob Intensity Panel
	local blobIntensityPanel = UIHelpers.createConfigPanel(configContainer, "blobIntensity")
	UIHelpers.createHeader(blobIntensityPanel, "Blob Intensity", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1

	local blobIntensityDesc = Instance.new("TextLabel")
	blobIntensityDesc.BackgroundTransparency = 1
	blobIntensityDesc.Size = UDim2.new(1, 0, 0, 16)
	blobIntensityDesc.Font = Enum.Font.Gotham
	blobIntensityDesc.TextSize = 11
	blobIntensityDesc.TextColor3 = Color3.fromRGB(180, 180, 180)
	blobIntensityDesc.TextXAlignment = Enum.TextXAlignment.Left
	blobIntensityDesc.Text = "How much the blob protrudes"
	blobIntensityDesc.LayoutOrder = 2
	blobIntensityDesc.Parent = blobIntensityPanel

	local _, blobIntensityContainer, _setBlobIntensity = UIHelpers.createSlider(
		blobIntensityPanel,
		"Intensity",
		10,
		100,
		math.floor(S.blobIntensity * 100),
		function(value: number)
			S.blobIntensity = value / 100
		end
	)
	blobIntensityContainer.LayoutOrder = 3

	configPanels["blobIntensity"] = blobIntensityPanel

	-- Blob Smoothness Panel
	local blobSmoothnessPanel = UIHelpers.createConfigPanel(configContainer, "blobSmoothness")
	UIHelpers.createHeader(blobSmoothnessPanel, "Blob Smoothness", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1

	local blobSmoothnessDesc = Instance.new("TextLabel")
	blobSmoothnessDesc.BackgroundTransparency = 1
	blobSmoothnessDesc.Size = UDim2.new(1, 0, 0, 16)
	blobSmoothnessDesc.Font = Enum.Font.Gotham
	blobSmoothnessDesc.TextSize = 11
	blobSmoothnessDesc.TextColor3 = Color3.fromRGB(180, 180, 180)
	blobSmoothnessDesc.TextXAlignment = Enum.TextXAlignment.Left
	blobSmoothnessDesc.Text = "How smooth/organic the blob shape is"
	blobSmoothnessDesc.LayoutOrder = 2
	blobSmoothnessDesc.Parent = blobSmoothnessPanel

	local _, blobSmoothnessContainer, _setBlobSmoothness = UIHelpers.createSlider(
		blobSmoothnessPanel,
		"Smoothness",
		10,
		100,
		math.floor(S.blobSmoothness * 100),
		function(value: number)
			S.blobSmoothness = value / 100
		end
	)
	blobSmoothnessContainer.LayoutOrder = 3

	configPanels["blobSmoothness"] = blobSmoothnessPanel

	-- Bridge Info Panel
	local bridgeInfoPanel = UIHelpers.createConfigPanel(configContainer, "bridgeInfo")
	UIHelpers.createHeader(bridgeInfoPanel, "Bridge Tool", UDim2.new(0, 0, 0, 0)).LayoutOrder = 1
	local updateBridgePreview
	local bridgeInstructions = Instance.new("TextLabel")
	bridgeInstructions.Name = "Instructions"
	bridgeInstructions.BackgroundTransparency = 1
	bridgeInstructions.Size = UDim2.new(1, 0, 0, 50)
	bridgeInstructions.Font = Enum.Font.Gotham
	bridgeInstructions.TextSize = 12
	bridgeInstructions.TextColor3 = Color3.fromRGB(255, 255, 255)
	bridgeInstructions.TextWrapped = true
	bridgeInstructions.TextXAlignment = Enum.TextXAlignment.Left
	bridgeInstructions.TextYAlignment = Enum.TextYAlignment.Top
	bridgeInstructions.Text = "Click to set START point, then click again to set END point."
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
	local _, bridgeWidthContainer, _ = UIHelpers.createSlider(bridgeInfoPanel, "Width", 1, 20, S.bridgeWidth, function(val)
		S.bridgeWidth = val
		if updateBridgePreview then
			updateBridgePreview()
		end
	end)
	bridgeWidthContainer.LayoutOrder = 4
	local variantLabel = UIHelpers.createHeader(bridgeInfoPanel, "Style", UDim2.new(0, 0, 0, 0))
	variantLabel.LayoutOrder = 5
	local variantButtonsContainer = Instance.new("Frame")
	variantButtonsContainer.Name = "VariantButtons"
	variantButtonsContainer.BackgroundTransparency = 1
	variantButtonsContainer.Size = UDim2.new(1, 0, 0, 0)
	variantButtonsContainer.AutomaticSize = Enum.AutomaticSize.Y
	variantButtonsContainer.LayoutOrder = 6
	variantButtonsContainer.Parent = bridgeInfoPanel
	local variantGridLayout = Instance.new("UIGridLayout")
	variantGridLayout.CellSize = UDim2.new(0, 80, 0, 26)
	variantGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	variantGridLayout.FillDirection = Enum.FillDirection.Horizontal
	variantGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	variantGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	variantGridLayout.Parent = variantButtonsContainer
	local variantButtons: { [string]: TextButton } = {}
	local function updateVariantButtons()
		for variant, btn in pairs(variantButtons) do
			btn.BackgroundColor3 = (variant == S.bridgeVariant) and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
	for i, variant in ipairs(BrushData.BridgeVariants) do
		local variantBtn = Instance.new("TextButton")
		variantBtn.Name = variant
		variantBtn.Size = UDim2.new(0, 80, 0, 26)
		variantBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		variantBtn.BorderSizePixel = 0
		variantBtn.Font = Enum.Font.Gotham
		variantBtn.TextSize = 11
		variantBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		variantBtn.Text = variant
		variantBtn.LayoutOrder = i
		variantBtn.Parent = variantButtonsContainer
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = variantBtn
		variantBtn.MouseButton1Click:Connect(function()
			S.bridgeVariant = variant
			updateVariantButtons()
			-- Initialize curves when switching to MegaMeander
			if variant == "MegaMeander" and S.bridgeStartPoint and S.bridgeEndPoint then
				if #S.bridgeCurves == 0 then
					S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
				end
			else
				-- Clear curves when switching away from MegaMeander
				S.bridgeCurves = {}
			end
			updateBridgeStatus()
			if updateBridgePreview then
				updateBridgePreview()
			end
		end)
		variantButtons[variant] = variantBtn
	end
	updateVariantButtons()
	local clearBridgeBtn = UIHelpers.createButton(
		bridgeInfoPanel,
		"Clear Points",
		UDim2.new(0, 0, 0, 0),
		UDim2.new(0, 100, 0, 28),
		function()
			S.bridgeStartPoint = nil
			S.bridgeEndPoint = nil
			S.bridgeCurves = {} -- Clear curves when clearing points
			bridgeStatusLabel.Text = "Status: Click to set START"
			for _, part in ipairs(S.bridgePreviewParts) do
				part:Destroy()
			end
			S.bridgePreviewParts = {}
			updateBridgeStatus()
		end
	)
	clearBridgeBtn.LayoutOrder = 10
	
	-- Meander controls (only visible when both points are set and MegaMeander is selected)
	local meanderControlsContainer = Instance.new("Frame")
	meanderControlsContainer.Name = "MeanderControls"
	meanderControlsContainer.BackgroundTransparency = 1
	meanderControlsContainer.Size = UDim2.new(1, 0, 0, 0)
	meanderControlsContainer.AutomaticSize = Enum.AutomaticSize.Y
	meanderControlsContainer.LayoutOrder = 11
	meanderControlsContainer.Visible = false
	meanderControlsContainer.Parent = bridgeInfoPanel
	
	local meanderLayout = Instance.new("UIListLayout")
	meanderLayout.SortOrder = Enum.SortOrder.LayoutOrder
	meanderLayout.Padding = UDim.new(0, 6)
	meanderLayout.Parent = meanderControlsContainer
	
	local redoLayoutBtn = UIHelpers.createButton(
		meanderControlsContainer,
		"🔄 Re-randomize Layout",
		UDim2.new(0, 0, 0, 0),
		UDim2.new(1, 0, 0, 32),
		function()
			if S.bridgeStartPoint and S.bridgeEndPoint then
				-- Generate new random curves for Mega Meander
				if S.bridgeVariant == "MegaMeander" then
					S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
				else
					-- For other variants, generate a few curves for added complexity
					S.bridgeCurves = BridgePathGenerator.generateRandomCurves(math.min(3, S.bridgeMeanderComplexity))
				end
				if updateBridgePreview then
					updateBridgePreview()
				end
			end
		end
	)
	redoLayoutBtn.LayoutOrder = 1
	
	local addCurveBtn = UIHelpers.createButton(
		meanderControlsContainer,
		"➕ Add Curve",
		UDim2.new(0, 0, 0, 0),
		UDim2.new(1, 0, 0, 32),
		function()
			if #S.bridgeCurves < 50 then
				table.insert(S.bridgeCurves, BridgePathGenerator.generateRandomCurve())
				if updateBridgePreview then
					updateBridgePreview()
				end
			end
		end
	)
	addCurveBtn.LayoutOrder = 2
	
	local complexityLabel = UIHelpers.createHeader(meanderControlsContainer, "Meander Complexity", UDim2.new(0, 0, 0, 0))
	complexityLabel.LayoutOrder = 3
	
	local _, complexityContainer, _setComplexity = UIHelpers.createSlider(
		meanderControlsContainer,
		"Curves",
		1,
		50,
		S.bridgeMeanderComplexity,
		function(value: number)
			S.bridgeMeanderComplexity = value
			if S.bridgeVariant == "MegaMeander" and S.bridgeStartPoint and S.bridgeEndPoint then
				S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
				if updateBridgePreview then
					updateBridgePreview()
				end
			end
		end
	)
	complexityContainer.LayoutOrder = 4
	
	configPanels["bridgeInfo"] = bridgeInfoPanel

	local function updateBridgeStatus()
		if S.bridgeStartPoint and S.bridgeEndPoint then
			bridgeStatusLabel.Text = "Status: READY - Click to build!"
			bridgeStatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
			-- Show meander controls only for MegaMeander variant
			meanderControlsContainer.Visible = (S.bridgeVariant == "MegaMeander")
		elseif S.bridgeStartPoint then
			bridgeStatusLabel.Text = "Status: Click to set END"
			bridgeStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
			meanderControlsContainer.Visible = false
		else
			bridgeStatusLabel.Text = "Status: Click to set START"
			bridgeStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
			meanderControlsContainer.Visible = false
		end
	end

	updateBridgePreview = function()
		for _, part in ipairs(S.bridgePreviewParts) do
			part:Destroy()
		end
		S.bridgePreviewParts = {}
		if not S.bridgeStartPoint then
			return
		end
		local startMarker = Instance.new("Part")
		startMarker.Size = Vector3.new(S.bridgeWidth, S.bridgeWidth, S.bridgeWidth) * Constants.VOXEL_RESOLUTION
		startMarker.CFrame = CFrame.new(S.bridgeStartPoint)
		startMarker.Anchored = true
		startMarker.CanCollide = false
		startMarker.Material = Enum.Material.Neon
		startMarker.Color = Color3.fromRGB(0, 255, 0)
		startMarker.Transparency = 0.5
		startMarker.Parent = workspace
		table.insert(S.bridgePreviewParts, startMarker)
		if S.bridgeEndPoint then
			local endMarker = Instance.new("Part")
			endMarker.Size = Vector3.new(S.bridgeWidth, S.bridgeWidth, S.bridgeWidth) * Constants.VOXEL_RESOLUTION
			endMarker.CFrame = CFrame.new(S.bridgeEndPoint)
			endMarker.Anchored = true
			endMarker.CanCollide = false
			endMarker.Material = Enum.Material.Neon
			endMarker.Color = Color3.fromRGB(255, 100, 0)
			endMarker.Transparency = 0.5
			endMarker.Parent = workspace
			table.insert(S.bridgePreviewParts, endMarker)
			
			local distance = (S.bridgeEndPoint - S.bridgeStartPoint).Magnitude
			local steps = math.max(2, math.floor(distance / (Constants.VOXEL_RESOLUTION * 2)))
			
			-- Use advanced path generation for MegaMeander mode
			if S.bridgeVariant == "MegaMeander" then
				-- Initialize curves if empty
				if #S.bridgeCurves == 0 then
					S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
				end
				
				-- Generate terrain-aware meandering path
				local path = BridgePathGenerator.generateMeanderingPath(
					S.bridgeStartPoint,
					S.bridgeEndPoint,
					S.bridgeCurves,
					S.terrain,
					steps,
					true -- terrain awareness enabled
				)
				
				-- Visualize path points
				for i, pathPoint in ipairs(path) do
					if i > 1 and i < #path then -- Skip first and last (already have markers)
						local pathMarker = Instance.new("Part")
						pathMarker.Size = Vector3.new(S.bridgeWidth * 0.5, S.bridgeWidth * 0.5, S.bridgeWidth * 0.5) * Constants.VOXEL_RESOLUTION
						pathMarker.CFrame = CFrame.new(pathPoint.position)
						pathMarker.Anchored = true
						pathMarker.CanCollide = false
						pathMarker.Material = Enum.Material.Neon
						pathMarker.Color = Color3.fromRGB(100, 200, 255)
						pathMarker.Transparency = 0.7
						pathMarker.Shape = Enum.PartType.Ball
						pathMarker.Parent = workspace
						table.insert(S.bridgePreviewParts, pathMarker)
					end
				end
			else
				-- Use original path generation for other variants
				local pathDir = (S.bridgeEndPoint - S.bridgeStartPoint).Unit
				local perpDir = Vector3.new(-pathDir.Z, 0, pathDir.X)
				for i = 1, steps - 1 do
					local t = i / steps
					local pos = S.bridgeStartPoint:Lerp(S.bridgeEndPoint, t)
					local offset = BrushData.getBridgeOffset(t, distance, S.bridgeVariant)
					local finalOffset = Vector3.new(0, offset.Y, 0) + perpDir * offset.X
					local pathMarker = Instance.new("Part")
					pathMarker.Size = Vector3.new(S.bridgeWidth * 0.5, S.bridgeWidth * 0.5, S.bridgeWidth * 0.5) * Constants.VOXEL_RESOLUTION
					pathMarker.CFrame = CFrame.new(pos + finalOffset)
					pathMarker.Anchored = true
					pathMarker.CanCollide = false
					pathMarker.Material = Enum.Material.Neon
					pathMarker.Color = Color3.fromRGB(100, 200, 255)
					pathMarker.Transparency = 0.7
					pathMarker.Shape = Enum.PartType.Ball
					pathMarker.Parent = workspace
					table.insert(S.bridgePreviewParts, pathMarker)
				end
			end
		end
	end

	local function buildBridge()
		if not S.bridgeStartPoint or not S.bridgeEndPoint then
			return
		end
		ChangeHistoryService:SetWaypoint("TerrainBridge_Start")
		local distance = (S.bridgeEndPoint - S.bridgeStartPoint).Magnitude
		local steps = math.max(3, math.floor(distance / Constants.VOXEL_RESOLUTION))
		local radius = S.bridgeWidth * Constants.VOXEL_RESOLUTION / 2
		
		-- Use advanced path generation for MegaMeander mode
		if S.bridgeVariant == "MegaMeander" then
			-- Initialize curves if empty
			if #S.bridgeCurves == 0 then
				S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
			end
			
			-- Generate terrain-aware meandering path
			local path = BridgePathGenerator.generateMeanderingPath(
				S.bridgeStartPoint,
				S.bridgeEndPoint,
				S.bridgeCurves,
				S.terrain,
				steps,
				true -- terrain awareness enabled
			)
			
			-- Build bridge along the generated path
			for _, pathPoint in ipairs(path) do
				S.terrain:FillBall(pathPoint.position, radius, S.brushMaterial)
			end
		else
			-- Use original path generation for other variants
			local pathDir = (S.bridgeEndPoint - S.bridgeStartPoint).Unit
			local perpDir = Vector3.new(-pathDir.Z, 0, pathDir.X)
			for i = 0, steps do
				local t = i / steps
				local pos = S.bridgeStartPoint:Lerp(S.bridgeEndPoint, t)
				local offset = BrushData.getBridgeOffset(t, distance, S.bridgeVariant)
				local finalOffset = Vector3.new(0, offset.Y, 0) + perpDir * offset.X
				local bridgePos = pos + finalOffset
				S.terrain:FillBall(bridgePos, radius, S.brushMaterial)
			end
		end
		
		ChangeHistoryService:SetWaypoint("TerrainBridge_End")
		S.bridgeStartPoint = nil
		S.bridgeEndPoint = nil
		S.bridgeCurves = {} -- Clear curves after building
		updateBridgeStatus()
		updateBridgePreview()
	end

	-- Config Panel Visibility Logic
	local configLayout = Instance.new("UIListLayout")
	configLayout.SortOrder = Enum.SortOrder.LayoutOrder
	configLayout.Padding = UDim.new(0, 8)
	configLayout.Parent = configContainer

	local panelOrder = { "bridgeInfo", "brushShape", "strength", "pivot", "hollow", "planeLock", "flattenMode", "material" }
	for i, panelName in ipairs(panelOrder) do
		if configPanels[panelName] then
			configPanels[panelName].LayoutOrder = i
		end
	end

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
		local toolConfig = BrushData.ToolConfigs[S.currentTool]
		for _, panel in pairs(configPanels) do
			panel.Visible = false
		end
		if S.currentTool == ToolId.None or not toolConfig then
			noToolMessage.Visible = true
		else
			noToolMessage.Visible = false
			for _, panelName in ipairs(toolConfig) do
				if configPanels[panelName] then
					configPanels[panelName].Visible = true
				end
			end
		end
		task.defer(function()
			local totalHeight = CONFIG_START_Y + configLayout.AbsoluteContentSize.Y + 20
			mainFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(totalHeight, 400))
		end)
	end

	if updateConfigPanelVisibility then
		updateConfigPanelVisibility()
	end
	updateToolButtonVisuals()
	pluginInstance:Activate(true)

	-- ============================================================================
	-- Mouse & Input Handling
	-- ============================================================================

	local allConnections: { RBXScriptConnection } = {}

	local function addConnection(conn: RBXScriptConnection)
		table.insert(allConnections, conn)
	end

	addConnection(mouse.Button1Down:Connect(function()
		if S.currentTool ~= ToolId.None then
			if S.currentTool == ToolId.Bridge then
				local hitPosition = getTerrainHit()
				if hitPosition then
					if not S.bridgeStartPoint then
						S.bridgeStartPoint = hitPosition
						S.bridgeCurves = {} -- Clear curves when setting new start point
						updateBridgeStatus()
						updateBridgePreview()
					elseif not S.bridgeEndPoint then
						S.bridgeEndPoint = hitPosition
						-- Initialize curves for MegaMeander when end point is set
						if S.bridgeVariant == "MegaMeander" and #S.bridgeCurves == 0 then
							S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
						end
						updateBridgeStatus()
						updateBridgePreview()
					else
						buildBridge()
					end
				end
				return
			end

			-- Clone tool: Alt+Click to sample source
			if S.currentTool == ToolId.Clone then
				local altHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
				if altHeld then
					local hitPosition = getTerrainHit()
					if hitPosition then
						-- Sample terrain in brush region
						local regionSize = Vector3.new(S.brushSizeX, S.brushSizeY, S.brushSizeZ) * Constants.VOXEL_RESOLUTION
						local region = Region3.new(hitPosition - regionSize * 0.5, hitPosition + regionSize * 0.5)
						local materials: { { { Enum.Material } } }
						local occupancies: { { { number } } }
						materials, occupancies = S.terrain:ReadVoxels(region, Constants.VOXEL_RESOLUTION)

						-- Store in buffer
						S.cloneSourceBuffer = {}
						local sizeX = #materials
						local sizeY = #materials[1]
						local sizeZ = #materials[1][1]
						local centerX = math.floor(sizeX / 2) + 1
						local centerY = math.floor(sizeY / 2) + 1
						local centerZ = math.floor(sizeZ / 2) + 1

						local buffer =
							S.cloneSourceBuffer :: { [number]: { [number]: { [number]: { occupancy: number, material: Enum.Material } } } }
						for x = 1, sizeX do
							buffer[x] = {}
							for y = 1, sizeY do
								buffer[x][y] = {}
								for z = 1, sizeZ do
									buffer[x][y][z] = {
										occupancy = occupancies[x][y][z],
										material = materials[x][y][z],
									}
								end
							end
						end

						S.cloneSourceCenter = Vector3.new(centerX, centerY, centerZ)

						-- Update status label
						local cloneInfoPanel = configPanels["cloneInfo"]
						if cloneInfoPanel then
							local cloneStatusLabel = cloneInfoPanel:FindFirstChild("Status") :: TextLabel?
							if cloneStatusLabel then
								cloneStatusLabel.Text = "Status: Source sampled! Click to stamp."
							end
						end
					end
					return
				end
			end
			if S.planeLockMode == PlaneLockType.Auto then
				local hitPosition = getTerrainHitRaw()
				if hitPosition then
					S.planePositionY = math.floor(hitPosition.Y + 0.5)
					S.autoPlaneActive = true
				end
			end
			S.isMouseDown = true
			startBrushing()
		end
	end))

	addConnection(mouse.Button1Up:Connect(function()
		S.isMouseDown = false
		stopBrushing()
		if S.planeLockMode == PlaneLockType.Auto then
			S.autoPlaneActive = false
		end
	end))

	addConnection(pluginInstance.Deactivation:Connect(function()
		if S.currentTool ~= ToolId.None then
			S.currentTool = ToolId.None
			updateToolButtonVisuals()
			if updateConfigPanelVisibility then
				updateConfigPanelVisibility()
			end
			hideBrushVisualization()
			hidePlaneVisualization()
			stopBrushing()
			S.autoPlaneActive = false
		end
	end))

	addConnection(UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		if S.currentTool == ToolId.None then
			return
		end
		local scrollUp = input.Position.Z > 0
		local ctrlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		if shiftHeld then
			local increment = S.brushSizeX < 10 and 1 or (S.brushSizeX < 30 and 2 or 4)
			local delta = scrollUp and increment or -increment
			local newSize = math.clamp(S.brushSizeX + delta, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
			S.brushSizeX = newSize
			local sizingMode = BrushData.ShapeSizingMode[S.brushShape] or "uniform"
			if sizingMode == "uniform" then
				S.brushSizeY = newSize
				S.brushSizeZ = newSize
			end
			-- For "box" mode, only X is changed (Y and Z remain independent)
		elseif ctrlHeld then
			local delta = scrollUp and 10 or -10
			local newStrength = math.clamp(math.floor(S.brushStrength * 100) + delta, 1, 100)
			setStrengthValue(newStrength)
		end
	end))

	addConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			if S.currentTool == ToolId.None then
				return
			end
			S.brushLocked = not S.brushLocked
			if S.brushLocked then
				print("[TerrainEditor] Brush LOCKED - drag handles to rotate/resize, press R to unlock")
			else
				print("[TerrainEditor] Brush UNLOCKED - brush follows mouse")
			end
			if S.lockedBrushPosition then
				updateBrushVisualization(S.lockedBrushPosition)
			end
		end
	end))

	S.renderConnection = RunService.RenderStepped:Connect(function()
		local gui = parentGui :: GuiObject
		local isVisible = if gui:IsA("ScreenGui") then (gui :: ScreenGui).Enabled else true
		if S.currentTool ~= ToolId.None and isVisible then
			local hitPosition = getTerrainHit()
			local brushPosition = hitPosition
			if S.brushLocked and S.lockedBrushPosition then
				brushPosition = S.lockedBrushPosition
			elseif hitPosition then
				S.lockedBrushPosition = hitPosition
			end
			if brushPosition then
				updateBrushVisualization(brushPosition)
				local showPlane = (S.planeLockMode == PlaneLockType.Manual) or (S.planeLockMode == PlaneLockType.Auto and S.autoPlaneActive)
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
	if S.renderConnection then
		addConnection(S.renderConnection)
	end

	parentGui.AncestryChanged:Connect(function()
		if not parentGui:IsDescendantOf(game) then
			for _, conn in ipairs(allConnections) do
				if conn.Connected then
					conn:Disconnect()
				end
			end
			if S.brushConnection then
				S.brushConnection:Disconnect()
			end
			hideBrushVisualization()
			hidePlaneVisualization()
		end
	end)

	print("========================================")
	print("[TerrainEditorFork] Version: " .. VERSION)
	print("========================================")

	return function()
		for _, conn in ipairs(allConnections) do
			if conn.Connected then
				conn:Disconnect()
			end
		end
		if S.brushConnection then
			S.brushConnection:Disconnect()
		end
		if S.renderConnection then
			S.renderConnection:Disconnect()
		end
		hideBrushVisualization()
		hidePlaneVisualization()
		destroyHandles()
		for _, part in ipairs(S.bridgePreviewParts) do
			part:Destroy()
		end
		S.bridgePreviewParts = {}
		pluginInstance:Deactivate()
	end
end

	return TerrainEditorModule
