--!strict

-- TerrainEditorFork - Module Version for Live Development
-- This module is loaded by the loader plugin for hot-reloading

local VERSION = "0.0.00000044"
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
	local UIHelpers = require(Src.Util.UIHelpers)
	local BrushData = require(Src.Util.BrushData)
	local ToolId = TerrainEnums.ToolId
	local BrushShape = TerrainEnums.BrushShape
	local PivotType = TerrainEnums.PivotType
	local FlattenMode = TerrainEnums.FlattenMode
	local PlaneLockType = TerrainEnums.PlaneLockType

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
		spinEnabled = false,
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
	}
	local BRUSH_COOLDOWN = 0.05
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
			if S.brushShape == BrushShape.Sphere or S.brushShape == BrushShape.Dome then
				S.brushPart.Shape = Enum.PartType.Ball
			elseif
				S.brushShape == BrushShape.Cube
				or S.brushShape == BrushShape.Grid
				or S.brushShape == BrushShape.ZigZag
				or S.brushShape == BrushShape.Spinner
			then
				S.brushPart.Shape = Enum.PartType.Block
			elseif
				S.brushShape == BrushShape.Cylinder
				or S.brushShape == BrushShape.Stick
				or S.brushShape == BrushShape.Torus
				or S.brushShape == BrushShape.Ring
				or S.brushShape == BrushShape.Sheet
			then
				S.brushPart.Shape = Enum.PartType.Cylinder
			end
		end

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

			if S.spinEnabled and not S.brushLocked then
				S.spinAngle = S.spinAngle + 0.05
			end

			local finalCFrame = baseCFrame
			if BrushData.ShapeSupportsRotation[S.brushShape] then
				finalCFrame = baseCFrame * S.brushRotation
			end
			if S.spinEnabled then
				local spinCFrame = CFrame.Angles(S.spinAngle * 0.7, S.spinAngle, S.spinAngle * 0.3)
				finalCFrame = finalCFrame * spinCFrame
			end

			if S.brushShape == BrushShape.Sphere then
				S.brushPart.Size = Vector3.new(sizeX, sizeX, sizeX)
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Cube then
				S.brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Cylinder then
				S.brushPart.Size = Vector3.new(sizeY, sizeX, sizeX)
				finalCFrame = baseCFrame * S.brushRotation * CFrame.Angles(0, 0, math.rad(90))
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
		S.rotationHandles.Name = "BrushRotationHandles"
		S.rotationHandles.Color3 = Color3.fromRGB(255, 170, 0)
		S.rotationHandles.Visible = false
		S.rotationHandles.Parent = CoreGui
		S.rotationHandles.MouseButton1Down:Connect(function()
			S.isHandleDragging = true
			dragStartRotation = S.brushRotation
		end)
		S.rotationHandles.MouseButton1Up:Connect(function()
			S.isHandleDragging = false
		end)
		S.rotationHandles.MouseDrag:Connect(function(axis, relativeAngle, deltaRadius)
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
		S.sizeHandles.Name = "BrushSizeHandles"
		S.sizeHandles.Color3 = Color3.fromRGB(0, 200, 255)
		S.sizeHandles.Style = Enum.HandlesStyle.Resize
		S.sizeHandles.Visible = false
		S.sizeHandles.Parent = CoreGui
		local dragStartSizeX = S.brushSizeX
		local dragStartSizeY = S.brushSizeY
		local dragStartSizeZ = S.brushSizeZ
		S.sizeHandles.MouseButton1Down:Connect(function()
			S.isHandleDragging = true
			dragStartSizeX = S.brushSizeX
			dragStartSizeY = S.brushSizeY
			dragStartSizeZ = S.brushSizeZ
		end)
		S.sizeHandles.MouseButton1Up:Connect(function()
			S.isHandleDragging = false
		end)
		S.sizeHandles.MouseDrag:Connect(function(face, distance)
			local deltaVoxels = distance / Constants.VOXEL_RESOLUTION
			local sizingMode = BrushData.ShapeSizingMode[S.brushShape] or "uniform"
			if sizingMode == "uniform" then
				local newSize = math.clamp(dragStartSizeX + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				S.brushSizeX = newSize
				S.brushSizeY = newSize
				S.brushSizeZ = newSize
			elseif sizingMode == "cylinder" then
				if face == Enum.NormalId.Right or face == Enum.NormalId.Left then
					S.brushSizeY = math.clamp(dragStartSizeY + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				else
					local newRadius = math.clamp(dragStartSizeX + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
					S.brushSizeX = newRadius
					S.brushSizeZ = newRadius
				end
			elseif sizingMode == "torus" then
				if face == Enum.NormalId.Right or face == Enum.NormalId.Left then
					S.brushSizeY = math.clamp(dragStartSizeY + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
				else
					local newRadius = math.clamp(dragStartSizeX + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
					S.brushSizeX = newRadius
					S.brushSizeZ = newRadius
				end
			else
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
		S.planePart.Name = "TerrainPlaneLockVisualization"
		S.planePart.Anchored = true
		S.planePart.CanCollide = false
		S.planePart.CanQuery = false
		S.planePart.CanTouch = false
		S.planePart.CastShadow = false
		S.planePart.Shape = Enum.PartType.Cylinder
		S.planePart.Size = Vector3.new(0.5, PLANE_SIZE, PLANE_SIZE)
		S.planePart.Transparency = 0.85
		S.planePart.Material = Enum.Material.Neon
		S.planePart.Color = Color3.fromRGB(0, 200, 100)
		S.planePart.Parent = workspace
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
		raycastParams.FilterDescendantsInstances = { S.brushPart, S.planePart }
		local usePlaneLock = (S.planeLockMode == PlaneLockType.Manual) or (S.planeLockMode == PlaneLockType.Auto and S.autoPlaneActive)
		if usePlaneLock then
			local planeHit = intersectPlane(ray)
			if planeHit then
				return planeHit
			end
		end
		local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
		if result and result.Instance == S.terrain then
			return result.Position
		end
		if result then
			return result.Position
		end
		if ray.Direction.Y ~= 0 then
			local t = -ray.Origin.Y / ray.Direction.Y
			if t > 0 and t < 1000 then
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
		raycastParams.FilterDescendantsInstances = { S.brushPart, S.planePart }
		local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
		if result then
			return result.Position
		end
		if ray.Direction.Y ~= 0 then
			local t = -ray.Origin.Y / ray.Direction.Y
			if t > 0 and t < 1000 then
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
		elseif sizingMode == "cylinder" then
			actualSizeZ = S.brushSizeX
		elseif sizingMode == "torus" then
			actualSizeZ = S.brushSizeX
		end
		local effectiveRotation = S.brushRotation
		if not BrushData.ShapeSupportsRotation[S.brushShape] then
			effectiveRotation = CFrame.new()
		end
		if S.spinEnabled then
			S.spinAngle = S.spinAngle + 0.1
			local spinCFrame = CFrame.Angles(S.spinAngle * 0.7, S.spinAngle, S.spinAngle * 0.3)
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
			local now = tick()
			if now - S.lastBrushTime < BRUSH_COOLDOWN then
				return
			end
			S.lastBrushTime = now
			local hitPosition = getTerrainHit()
			if hitPosition then
				if S.currentTool == ToolId.Cliff and S.lastMouseWorldPos then
					local delta = hitPosition - S.lastMouseWorldPos
					local horizDelta = Vector3.new(delta.X, 0, delta.Z)
					if horizDelta.Magnitude > 0.5 then
						local dir = horizDelta.Unit
						S.cliffDirectionX = dir.X
						S.cliffDirectionZ = dir.Z
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
	padding.PaddingTop = UDim.new(0, 10)
	padding.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 0, 0, 0)
	title.Size = UDim2.new(1, 0, 0, 24)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "🌋 Terrain Editor Fork v" .. VERSION
	title.Parent = mainFrame

	UIHelpers.createHeader(mainFrame, "Sculpt Tools", UDim2.new(0, 0, 0, 40))

	local sculptTools = {
		{ id = ToolId.Add, name = "Add", row = 0, col = 0 },
		{ id = ToolId.Subtract, name = "Subtract", row = 0, col = 1 },
		{ id = ToolId.Grow, name = "Grow", row = 0, col = 2 },
		{ id = ToolId.Erode, name = "Erode", row = 1, col = 0 },
		{ id = ToolId.Smooth, name = "Smooth", row = 1, col = 1 },
		{ id = ToolId.Flatten, name = "Flatten", row = 1, col = 2 },
		{ id = ToolId.Noise, name = "Noise", row = 2, col = 0 },
		{ id = ToolId.Terrace, name = "Terrace", row = 2, col = 1 },
	}

	for _, toolInfo in ipairs(sculptTools) do
		local pos = UDim2.new(0, toolInfo.col * 78, 0, 65 + toolInfo.row * 40)
		local btn = UIHelpers.createToolButton(mainFrame, toolInfo.id, toolInfo.name, pos)
		toolButtons[toolInfo.id] = btn
		btn.MouseButton1Click:Connect(function()
			selectTool(toolInfo.id)
		end)
	end

	UIHelpers.createHeader(mainFrame, "Other Tools", UDim2.new(0, 0, 0, 195))
	local paintBtn = UIHelpers.createToolButton(mainFrame, ToolId.Paint, "Paint", UDim2.new(0, 0, 0, 220))
	toolButtons[ToolId.Paint] = paintBtn
	paintBtn.MouseButton1Click:Connect(function()
		selectTool(ToolId.Paint)
	end)

	local bridgeBtn = UIHelpers.createToolButton(mainFrame, ToolId.Bridge, "Bridge", UDim2.new(0, 78, 0, 220))
	toolButtons[ToolId.Bridge] = bridgeBtn
	bridgeBtn.MouseButton1Click:Connect(function()
		selectTool(ToolId.Bridge)
	end)

	local CONFIG_START_Y = 270

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
		function(value)
			S.brushStrength = value / 100
		end
	)
	strengthSliderContainer.LayoutOrder = 2
	configPanels["strength"] = strengthPanel

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
	hollowToggleBtn.LayoutOrder = 2
	local _, thicknessSliderContainer, _ = UIHelpers.createSlider(
		hollowPanel,
		"Thickness",
		10,
		50,
		math.floor(S.wallThickness * 100),
		function(val)
			S.wallThickness = val / 100
		end
	)
	thicknessSliderContainer.LayoutOrder = 3
	hollowThicknessContainer = thicknessSliderContainer
	hollowThicknessContainer.Visible = false
	updateHollowButton()
	configPanels["hollow"] = hollowPanel

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
	materialGridContainer.Size = UDim2.new(1, 0, 0, 630)
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
	for i, matInfo in ipairs(BrushData.Materials) do
		local row = math.floor((i - 1) / 4)
		local col = (i - 1) % 4
		local container = Instance.new("Frame")
		container.Name = matInfo.key
		container.BackgroundTransparency = 1
		container.Position = UDim2.new(0, col * 78, 0, row * 102)
		container.Size = UDim2.new(0, 72, 0, 94)
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
			bridgeStatusLabel.Text = "Status: Click to set START"
			for _, part in ipairs(S.bridgePreviewParts) do
				part:Destroy()
			end
			S.bridgePreviewParts = {}
		end
	)
	clearBridgeBtn.LayoutOrder = 10
	configPanels["bridgeInfo"] = bridgeInfoPanel

	local function updateBridgeStatus()
		if S.bridgeStartPoint and S.bridgeEndPoint then
			bridgeStatusLabel.Text = "Status: READY - Click to build!"
			bridgeStatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
		elseif S.bridgeStartPoint then
			bridgeStatusLabel.Text = "Status: Click to set END"
			bridgeStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
		else
			bridgeStatusLabel.Text = "Status: Click to set START"
			bridgeStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
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

	local function buildBridge()
		if not S.bridgeStartPoint or not S.bridgeEndPoint then
			return
		end
		ChangeHistoryService:SetWaypoint("TerrainBridge_Start")
		local distance = (S.bridgeEndPoint - S.bridgeStartPoint).Magnitude
		local steps = math.max(3, math.floor(distance / Constants.VOXEL_RESOLUTION))
		local radius = S.bridgeWidth * Constants.VOXEL_RESOLUTION / 2
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
		ChangeHistoryService:SetWaypoint("TerrainBridge_End")
		S.bridgeStartPoint = nil
		S.bridgeEndPoint = nil
		updateBridgeStatus()
		updateBridgePreview()
	end

	-- Config Panel Visibility Logic
	local configLayout = Instance.new("UIListLayout")
	configLayout.SortOrder = Enum.SortOrder.LayoutOrder
	configLayout.Padding = UDim.new(0, 10)
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
			local totalHeight = CONFIG_START_Y + configLayout.AbsoluteContentSize.Y + 50
			mainFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(totalHeight, 400))
		end)
	end

	updateConfigPanelVisibility()
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
						updateBridgeStatus()
						updateBridgePreview()
					elseif not S.bridgeEndPoint then
						S.bridgeEndPoint = hitPosition
						updateBridgeStatus()
						updateBridgePreview()
					else
						buildBridge()
					end
				end
				return
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
			elseif sizingMode == "cylinder" then
				S.brushSizeZ = newSize
			end
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
		if S.currentTool ~= ToolId.None and parentGui.Enabled then
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
	addConnection(S.renderConnection)

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

	print("[TerrainEditorFork] v" .. VERSION .. " loaded!")

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
