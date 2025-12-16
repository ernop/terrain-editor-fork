--!strict

-- TerrainEditorFork - Module Version for Live Development
-- This module is loaded by the loader plugin for hot-reloading
-- Refactored to use modular panel system

local VERSION = "0.0.000094"

local TerrainEditorModule = {}

function TerrainEditorModule.init(pluginInstance: Plugin, parentGui: GuiObject)
	local Src = script.Src

	-- Services
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local ChangeHistoryService = game:GetService("ChangeHistoryService")
	local CoreGui = game:GetService("CoreGui")

	-- Load utilities
	local TerrainEnums = require(Src.Util.TerrainEnums)
	local Constants = require(Src.Util.Constants)
	local Theme = require(Src.Util.Theme)
	local UIHelpers = require(Src.Util.UIHelpers) :: any
	local BrushData = require(Src.Util.BrushData) :: any
	local BridgePathGenerator = require(Src.Util.BridgePathGenerator) :: any
	local TorusMeshGenerator = require(Src.Util.TorusMeshGenerator) :: any
	local DomeMeshGenerator = require(Src.Util.DomeMeshGenerator) :: any
	local applyPivot = require(Src.Util.applyPivot)
	local ConfigPanels = require(Src.UI.ConfigPanels) :: any
	local ToolDocsPanel = require(Src.UI.Panels.ToolDocsPanel) :: any
	local ToolRegistry = require(Src.Tools.ToolRegistry) :: any

	local ToolId = TerrainEnums.ToolId
	local BrushShape = TerrainEnums.BrushShape
	local PivotType = TerrainEnums.PivotType
	local FlattenMode = TerrainEnums.FlattenMode
	local PlaneLockType = TerrainEnums.PlaneLockType
	local SpinMode = TerrainEnums.SpinMode
	local FalloffType = TerrainEnums.FalloffType

	-- Load terrain operations
	local performTerrainBrushOperation = require(Src.TerrainOperations.performTerrainBrushOperation)

	-- ============================================================================
	-- State Table
	-- ============================================================================
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
		pivotType = PivotType.Bottom,
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
		slopeFlatMaterial = Enum.Material.Grass,
		slopeSteepMaterial = Enum.Material.Rock,
		slopeCliffMaterial = Enum.Material.Slate,
		slopeThreshold1 = 30,
		slopeThreshold2 = 60,
		megarandomizeMaterials = {
			{ material = Enum.Material.Grass, weight = 0.6 },
			{ material = Enum.Material.Rock, weight = 0.25 },
			{ material = Enum.Material.Ground, weight = 0.15 },
		},
		megarandomizeClusterSize = 4,
		megarandomizeSeed = 0,
		cavitySensitivity = 0.3,
		meltViscosity = 0.5,
		gradientMaterial1 = Enum.Material.Grass,
		gradientMaterial2 = Enum.Material.Rock,
		gradientStartPoint = nil :: Vector3?,
		gradientEndPoint = nil :: Vector3?,
		gradientNoiseAmount = 0.1,
		gradientSeed = 0,
		floodTargetMaterial = Enum.Material.Grass,
		floodSourceMaterial = nil :: Enum.Material?,
		floodReplaceAll = true,
		stalactiteDirection = -1,
		stalactiteDensity = 0.3,
		stalactiteLength = 10,
		stalactiteTaper = 0.8,
		stalactiteSeed = 0,
		tendrilRadius = 1.5,
		tendrilBranches = 5,
		tendrilLength = 15,
		tendrilCurl = 0.5,
		tendrilSeed = 0,
		symmetryType = "Radial4",
		symmetrySegments = 4,
		symmetryCenter = nil :: Vector3?, -- Center point for symmetry (nil = use first click)
		gridCellSize = 8,
		gridVariation = 0.3,
		gridSeed = 0,
		growthRate = 0.3,
		growthBias = 0,
		growthPattern = "organic",
		growthSeed = 0,
		-- Grow tool: emphasize brush center (depth-based falloff along view direction)
		emphasizeBrushCenter = false,
		-- Brush falloff curve (affects how brush strength fades from center to edge)
		falloffType = "Cosine", -- Default: original behavior
		falloffExtent = 0, -- How far falloff extends beyond brush edge (0 = none, 1 = 100% of brush radius)
		-- Voxel Inspector state
		voxelInspectLocked = false,
		voxelInspectPosition = nil :: Vector3?,
		voxelInspectGridPos = nil :: Vector3?,
		voxelInspectOccupancy = 0,
		voxelInspectMaterial = Enum.Material.Air,
		voxelInspectHighlight = nil :: Part?,
		brushRate = "normal",
		lastMouseWorldPos = nil :: Vector3?,
		lastBrushTime = 0,
		lastBrushPosition = nil :: Vector3?,
		isMouseDown = false,
		brushPart = nil :: BasePart?,
		brushExtraParts = {} :: { BasePart },
		brushSelectionBox = nil :: SelectionBox?,
		extraSelectionBoxes = {} :: { SelectionBox },
		torusWireframeParts = {} :: { Part }, -- Torus mesh wireframe parts
		torusLastMajorRadius = 0, -- Cache for detecting size changes
		torusLastMinorRadius = 0,
		domeWireframeParts = {} :: { Part }, -- Dome mesh wireframe parts
		domeLastRadiusX = 0, -- Cache for detecting size changes
		domeLastRadiusY = 0,
		domeLastRadiusZ = 0,
		domeLastIsRotated = false,
		handleAdorneePart = nil :: Part?, -- Invisible part for handles on composite shapes
		planePart = nil :: Part?,
		rotationHandles = {} :: { ArcHandles }, -- One per axis (X, Y, Z) with axis colors
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
		bridgeHoverPoint = nil :: Vector3?,
		bridgeLastPreviewParams = nil :: any?,
		updateGradientStatus = nil :: (() -> ())?,
		showDocsPanel = true, -- Toggle for tool documentation panel visibility
	}
	local mouse = pluginInstance:GetMouse()

	-- Forward declarations
	local updateHandlesAdornee: () -> ()
	local hideHandles: () -> ()
	local destroyHandles: () -> ()
	local updateConfigPanelVisibility: (() -> ())?
	local setDocsPanelVisible: ((visible: boolean) -> ())?
	local updateDocsToggleButton: (() -> ())?
	local toolButtons: { [string]: TextButton } = {}

	-- ============================================================================
	-- Tool Selection
	-- ============================================================================
	local function updateToolButtonVisuals()
		for toolId, button in pairs(toolButtons) do
			if toolId == S.currentTool then
				button.BackgroundColor3 = Theme.Colors.ButtonSelected
			else
				button.BackgroundColor3 = Theme.Colors.ButtonDefault
			end
			button.TextColor3 = Theme.Colors.Text
		end
	end

	-- Forward declaration for updateToolDocs (defined after tool docs panel is created)
	local updateToolDocs: (() -> ())?

	local function selectTool(toolId: string)
		if S.currentTool == ToolId.Bridge and toolId ~= ToolId.Bridge then
			S.bridgeStartPoint = nil
			S.bridgeEndPoint = nil
			S.bridgeHoverPoint = nil
			S.bridgeLastPreviewParams = nil
			for _, part in ipairs(S.bridgePreviewParts) do
				part:Destroy()
			end
			S.bridgePreviewParts = {}
		end

		-- Clean up voxel inspector when switching away
		if S.currentTool == ToolId.VoxelInspect and toolId ~= ToolId.VoxelInspect then
			S.voxelInspectLocked = false
			S.voxelInspectPosition = nil
			S.voxelInspectGridPos = nil
			S.voxelInspectOccupancy = 0
			S.voxelInspectMaterial = Enum.Material.Air
			if S.voxelInspectHighlight then
				S.voxelInspectHighlight.Transparency = 1
			end
			if S.updateVoxelInspectDisplay then
				S.updateVoxelInspectDisplay()
			end
		end

		-- Reset symmetry center when switching to Symmetry tool (first click sets new center)
		if toolId == ToolId.Symmetry then
			S.symmetryCenter = nil
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
		if updateToolDocs then
			updateToolDocs()
		end
	end

	-- ============================================================================
	-- Brush Visualization
	-- ============================================================================
	local function createSelectionBox(adornee: BasePart): SelectionBox
		local box = Instance.new("SelectionBox")
		box.Name = "BrushEdgeBox"
		box.Adornee = adornee
		box.Color3 = S.brushLocked and Theme.Colors.BrushEdgeLocked or Theme.Colors.BrushEdge
		box.LineThickness = 0.02
		box.SurfaceColor3 = Color3.new(0, 0, 0)
		box.SurfaceTransparency = 1 -- No surface fill, just edges
		box.Parent = CoreGui
		return box
	end

	local function createPreviewPart(shape: Enum.PartType?): Part
		local part = Instance.new("Part")
		part.Name = "TerrainBrushExtra"
		part.Archivable = false -- Exclude from undo history
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = S.brushLocked and Theme.Colors.BrushLocked or Theme.Colors.BrushNormal
		part.Transparency = Theme.Transparency.BrushExtra
		if shape then
			part.Shape = shape
		end
		part.Parent = workspace
		-- Add edge highlighting
		local selBox = createSelectionBox(part)
		table.insert(S.extraSelectionBoxes, selBox)
		return part
	end

	local function clearExtraParts()
		for _, part in ipairs(S.brushExtraParts) do
			part:Destroy()
		end
		S.brushExtraParts = {}
		for _, box in ipairs(S.extraSelectionBoxes) do
			box:Destroy()
		end
		S.extraSelectionBoxes = {}
		-- Clear torus wireframe
		TorusMeshGenerator.destroyWireframe(S.torusWireframeParts)
		S.torusWireframeParts = {}
		S.torusLastMajorRadius = 0
		S.torusLastMinorRadius = 0
		-- Clear dome wireframe
		DomeMeshGenerator.destroyWireframe(S.domeWireframeParts)
		S.domeWireframeParts = {}
		S.domeLastRadiusX = 0
		S.domeLastRadiusY = 0
		S.domeLastRadiusZ = 0
		S.domeLastIsRotated = false
	end

	local function createBrushVisualization()
		if S.brushPart then
			S.brushPart:Destroy()
		end
		if S.brushSelectionBox then
			S.brushSelectionBox:Destroy()
			S.brushSelectionBox = nil
		end
		if S.handleAdorneePart then
			S.handleAdorneePart:Destroy()
			S.handleAdorneePart = nil
		end
		clearExtraParts()

		-- Check if this is a composite shape (main brushPart is hidden, uses extra parts)
		-- Note: Spikepad has a visible base, so it's not fully composite
		local isCompositeShape = S.brushShape == BrushShape.Torus
			or S.brushShape == BrushShape.Ring
			or S.brushShape == BrushShape.Grid
			or S.brushShape == BrushShape.RotatedDome
		-- Cylinder: brushPart has 90° Z rotation for visual alignment, but handles need unrotated adornee
		-- Spikepad: needs handle adornee but base is visible so gets SelectionBox
		local needsHandleAdornee = isCompositeShape or S.brushShape == BrushShape.Spikepad or S.brushShape == BrushShape.Cylinder

		if S.brushShape == BrushShape.Wedge then
			S.brushPart = Instance.new("WedgePart")
		elseif S.brushShape == BrushShape.CornerWedge then
			S.brushPart = Instance.new("CornerWedgePart")
		else
			S.brushPart = Instance.new("Part")
			local part = S.brushPart :: Part
			if S.brushShape == BrushShape.Sphere or S.brushShape == BrushShape.Dome or S.brushShape == BrushShape.RotatedDome then
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
			S.brushPart.Archivable = false -- Exclude from undo history
			S.brushPart.Anchored = true
			S.brushPart.CanCollide = false
			S.brushPart.CanQuery = false
			S.brushPart.CanTouch = false
			S.brushPart.CastShadow = false
			S.brushPart.Transparency = Theme.Transparency.BrushNormal
			S.brushPart.Material = Enum.Material.Neon
			S.brushPart.Color = Theme.Colors.BrushNormal
			S.brushPart.Parent = workspace
			-- Add edge highlighting (only for non-composite shapes where main part is visible)
			if not isCompositeShape then
				S.brushSelectionBox = createSelectionBox(S.brushPart)
			end
		end

		-- Create invisible handle adornee part for shapes that need it
		if needsHandleAdornee then
			S.handleAdorneePart = Instance.new("Part")
			S.handleAdorneePart.Name = "BrushHandleAdornee"
			S.handleAdorneePart.Archivable = false -- Exclude from undo history
			S.handleAdorneePart.Anchored = true
			S.handleAdorneePart.CanCollide = false
			S.handleAdorneePart.CanQuery = false
			S.handleAdorneePart.CanTouch = false
			S.handleAdorneePart.CastShadow = false
			S.handleAdorneePart.Transparency = 1 -- Invisible
			S.handleAdorneePart.Parent = workspace
		end
	end

	-- Returns whether spin mode is world-relative (applied before brush rotation)
	-- vs shape-relative (applied after brush rotation)
	local function isWorldRelativeSpin(spinMode: string): boolean
		return spinMode == SpinMode.WorldY
			or spinMode == SpinMode.WorldYFast
			or spinMode == SpinMode.World3D
			or spinMode == SpinMode.World3DFast
	end

	local function calculateSpinRotation(spinMode: string, spinAngle: number): CFrame
		if spinMode == SpinMode.Off then
			return CFrame.new()

		-- World-relative modes (rotate around world axes)
		elseif spinMode == SpinMode.WorldY then
			return CFrame.Angles(0, spinAngle, 0)
		elseif spinMode == SpinMode.WorldYFast then
			return CFrame.Angles(0, spinAngle * 2, 0)
		elseif spinMode == SpinMode.World3D then
			return CFrame.Angles(spinAngle * 0.7, spinAngle, spinAngle * 0.3)
		elseif spinMode == SpinMode.World3DFast then
			return CFrame.Angles(spinAngle * 1.4, spinAngle * 2, spinAngle * 0.6)

		-- Shape-relative modes (rotate around shape's local axes)
		elseif spinMode == SpinMode.ShapeY then
			return CFrame.Angles(0, spinAngle, 0)
		elseif spinMode == SpinMode.Shape3D then
			return CFrame.Angles(spinAngle * 0.7, spinAngle, spinAngle * 0.3)

		-- Special effect modes
		elseif spinMode == SpinMode.Roll then
			-- Roll around X axis (barrel roll effect)
			return CFrame.Angles(spinAngle, 0, 0)
		elseif spinMode == SpinMode.Wobble then
			-- Oscillating tilt using sine wave (pendulum-like)
			local wobbleX = math.sin(spinAngle * 2) * 0.4
			local wobbleZ = math.cos(spinAngle * 2.3) * 0.3
			return CFrame.Angles(wobbleX, 0, wobbleZ)
		elseif spinMode == SpinMode.Spiral then
			-- Corkscrew: continuous Y spin + gradually increasing tilt
			local spiralTilt = math.sin(spinAngle * 0.3) * 0.5
			return CFrame.Angles(spiralTilt, spinAngle * 1.5, 0)
		end

		return CFrame.new()
	end

	local function updateSpinAngle(spinMode: string, currentAngle: number): number
		if spinMode == SpinMode.Off then
			return currentAngle
		elseif spinMode == SpinMode.WorldYFast or spinMode == SpinMode.World3DFast then
			return currentAngle + 0.1
		else
			return currentAngle + 0.05
		end
	end

	-- Find the highest terrain surface within the brush footprint
	-- Returns the Y position to place the brush bottom at, or nil if no terrain found
	local function findSurfaceHeight(centerX: number, centerZ: number, radiusX: number, radiusZ: number, searchDepth: number?): number?
		local depth = searchDepth or 100
		local samplePoints = {
			Vector3.new(centerX, 0, centerZ), -- Center
			Vector3.new(centerX + radiusX * 0.7, 0, centerZ), -- Right
			Vector3.new(centerX - radiusX * 0.7, 0, centerZ), -- Left
			Vector3.new(centerX, 0, centerZ + radiusZ * 0.7), -- Front
			Vector3.new(centerX, 0, centerZ - radiusZ * 0.7), -- Back
		}

		local maxHeight: number? = nil
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = { S.terrain }

		for _, point in ipairs(samplePoints) do
			-- Cast ray downward from above to find terrain surface
			local rayOrigin = Vector3.new(point.X, 10000, point.Z)
			local rayDirection = Vector3.new(0, -20000, 0)
			local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

			if result and result.Instance == S.terrain then
				local hitY = result.Position.Y
				if maxHeight == nil or hitY > maxHeight then
					maxHeight = hitY
				end
			end
		end

		return maxHeight
	end

	local function updateBrushVisualization(position: Vector3)
		if not S.brushPart then
			createBrushVisualization()
		end

		if S.brushPart then
			local sizeX = S.brushSizeX * Constants.VOXEL_RESOLUTION
			local sizeY = S.brushSizeY * Constants.VOXEL_RESOLUTION
			local sizeZ = S.brushSizeZ * Constants.VOXEL_RESOLUTION

			-- Apply pivot offset so visualization matches actual operation
			local pivotedPosition
			if S.pivotType == PivotType.Surface then
				-- Surface pivot: find highest terrain in footprint and rest brush on top
				local surfaceY = findSurfaceHeight(position.X, position.Z, sizeX * 0.5, sizeZ * 0.5)
				if surfaceY then
					-- Position brush so bottom is at surface height
					pivotedPosition = Vector3.new(position.X, surfaceY + sizeY * 0.5, position.Z)
				else
					-- No terrain found, fall back to bottom pivot behavior
					pivotedPosition = Vector3.new(position.X, position.Y + sizeY * 0.5, position.Z)
				end
			else
				pivotedPosition = applyPivot(S.pivotType, position, sizeY)
			end

			S.brushPart.Transparency = 0.8 - (S.brushStrength * 0.3)
			S.brushPart.Color = S.brushLocked and Theme.Colors.BrushLocked or Theme.Colors.BrushNormal

			local baseCFrame = CFrame.new(pivotedPosition)

			if S.spinMode ~= SpinMode.Off and not S.brushLocked then
				S.spinAngle = updateSpinAngle(S.spinMode, S.spinAngle)
			end

			local finalCFrame = baseCFrame
			local spinRotation = calculateSpinRotation(S.spinMode, S.spinAngle)
			local brushRotation = BrushData.ShapeSupportsRotation[S.brushShape] and S.brushRotation or CFrame.new()

			if S.spinMode ~= SpinMode.Off and isWorldRelativeSpin(S.spinMode) then
				-- World-relative: spin first (around world axes), then apply brush rotation
				finalCFrame = baseCFrame * spinRotation * brushRotation
			else
				-- Shape-relative (or no spin): brush rotation first, then spin in local space
				finalCFrame = baseCFrame * brushRotation * spinRotation
			end

			-- Set size and CFrame based on shape
			if S.brushShape == BrushShape.Sphere then
				S.brushPart.Size = Vector3.new(sizeX, sizeX, sizeX)
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Cube then
				S.brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Cylinder then
				-- Roblox Cylinder parts have height along local X, but our operation code uses Y for height.
				-- Apply a 90° rotation around Z to align the visual with the operation.
				S.brushPart.Size = Vector3.new(sizeY, sizeX, sizeX)
				S.brushPart.CFrame = finalCFrame * CFrame.Angles(0, 0, math.rad(90))
				-- Handle adornee part uses unrotated CFrame so rotation handles appear correctly
				if S.handleAdorneePart then
					S.handleAdorneePart.Size = Vector3.new(sizeX, sizeY, sizeX)
					S.handleAdorneePart.CFrame = finalCFrame
				end
			elseif S.brushShape == BrushShape.Wedge or S.brushShape == BrushShape.CornerWedge then
				S.brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Dome then
				-- Dome only affects top half, so visualize as half-sphere
				-- Use a squashed sphere positioned to show only top half
				S.brushPart.Size = Vector3.new(sizeX, sizeY, sizeX)
				-- Offset down by half the Y size so the flat bottom is at the center point
				S.brushPart.CFrame = finalCFrame * CFrame.new(0, sizeY * 0.25, 0)
			elseif S.brushShape == BrushShape.RotatedDome then
				-- RotatedDome faces forward (Z+), good for tunnel/arch entrances
				-- Hide the basic ball part, use wireframe instead
				S.brushPart.Transparency = 1
				S.brushPart.Size = Vector3.new(1, 1, 1)
				S.brushPart.CFrame = finalCFrame

				-- Dome radii: X=Y for circular face, Z for depth
				local domeRadiusX = sizeX * 0.5
				local domeRadiusY = sizeX * 0.5 -- Match X for circular face
				local domeRadiusZ = sizeZ * 0.5
				local domeColor = S.brushLocked and Theme.Colors.BrushLocked or Theme.Colors.BrushNormal

				-- Check if we need to regenerate the wireframe (size changed or first time)
				local sizeChanged = math.abs(domeRadiusX - S.domeLastRadiusX) > 0.1
					or math.abs(domeRadiusY - S.domeLastRadiusY) > 0.1
					or math.abs(domeRadiusZ - S.domeLastRadiusZ) > 0.1
					or S.domeLastIsRotated ~= true
				local needsRegenerate = #S.domeWireframeParts == 0 or sizeChanged

				if needsRegenerate then
					-- Clear old wireframe
					DomeMeshGenerator.destroyWireframe(S.domeWireframeParts)
					-- Generate new wireframe (light version for performance)
					S.domeWireframeParts = DomeMeshGenerator.createLightWireframe(
						domeRadiusX,
						domeRadiusY,
						domeRadiusZ,
						true, -- isRotated = true for forward-facing dome
						domeColor,
						Theme.Transparency.BrushExtra
					)
					DomeMeshGenerator.parentWireframe(S.domeWireframeParts, workspace)
					-- Cache the size
					S.domeLastRadiusX = domeRadiusX
					S.domeLastRadiusY = domeRadiusY
					S.domeLastRadiusZ = domeRadiusZ
					S.domeLastIsRotated = true
				else
					-- Just update position (much faster)
					DomeMeshGenerator.updateWireframeCFrame(S.domeWireframeParts, finalCFrame, domeRadiusX, domeRadiusY, domeRadiusZ, true)
				end

				-- Always update color (for locked/unlocked state)
				DomeMeshGenerator.updateWireframeColor(S.domeWireframeParts, domeColor)

				-- Update handle adornee part for proper handle sizing
				if S.handleAdorneePart then
					S.handleAdorneePart.Size = Vector3.new(sizeX, sizeX, sizeZ)
					S.handleAdorneePart.CFrame = finalCFrame
				end
			elseif S.brushShape == BrushShape.Torus then
				S.brushPart.Transparency = 1
				S.brushPart.Size = Vector3.new(1, 1, 1)
				S.brushPart.CFrame = finalCFrame

				local majorRadius = sizeX * 0.5
				local tubeRadius = sizeY * 0.5
				local torusColor = S.brushLocked and Theme.Colors.BrushLocked or Theme.Colors.BrushNormal

				-- Check if we need to regenerate the wireframe (size changed or first time)
				local sizeChanged = math.abs(majorRadius - S.torusLastMajorRadius) > 0.1
					or math.abs(tubeRadius - S.torusLastMinorRadius) > 0.1
				local needsRegenerate = #S.torusWireframeParts == 0 or sizeChanged

				if needsRegenerate then
					-- Clear old wireframe
					TorusMeshGenerator.destroyWireframe(S.torusWireframeParts)
					-- Generate new wireframe (light version for performance)
					S.torusWireframeParts =
						TorusMeshGenerator.createLightWireframe(majorRadius, tubeRadius, torusColor, Theme.Transparency.BrushExtra)
					TorusMeshGenerator.parentWireframe(S.torusWireframeParts, workspace)
					-- Cache the size
					S.torusLastMajorRadius = majorRadius
					S.torusLastMinorRadius = tubeRadius
				else
					-- Just update position and color (much faster)
					TorusMeshGenerator.updateWireframeCFrame(S.torusWireframeParts, finalCFrame, majorRadius, tubeRadius)
				end

				-- Always update color (for locked/unlocked state)
				TorusMeshGenerator.updateWireframeColor(S.torusWireframeParts, torusColor)

				-- Update handle adornee part for proper handle sizing
				if S.handleAdorneePart then
					local totalDiameter = sizeX + sizeY -- Major radius + tube diameter
					S.handleAdorneePart.Size = Vector3.new(totalDiameter, sizeY, totalDiameter)
					S.handleAdorneePart.CFrame = finalCFrame
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
				-- Update handle adornee part for proper handle sizing
				if S.handleAdorneePart then
					S.handleAdorneePart.Size = Vector3.new(sizeX, sizeY, sizeX)
					S.handleAdorneePart.CFrame = finalCFrame
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
				-- Update handle adornee part for proper handle sizing
				if S.handleAdorneePart then
					S.handleAdorneePart.Size = Vector3.new(sizeX, sizeX, sizeX) -- Grid is uniform
					S.handleAdorneePart.CFrame = finalCFrame
				end
			elseif S.brushShape == BrushShape.Stick then
				S.brushPart.Size = Vector3.new(sizeY, sizeX * 0.3, sizeX * 0.3)
				finalCFrame = baseCFrame * S.brushRotation * CFrame.Angles(0, 0, math.rad(90))
				S.brushPart.CFrame = finalCFrame
			elseif S.brushShape == BrushShape.Sheet then
				-- Sheet is a curved surface - uses Cylinder part
				-- Operation code has curve around Y axis, Roblox Cylinder has axis along X
				-- Apply 90° rotation to align, and scale to show thin curved surface
				S.brushPart.Size = Vector3.new(sizeY, sizeX * 2, sizeX * 2)
				S.brushPart.CFrame = finalCFrame * CFrame.Angles(0, 0, math.rad(90))
			elseif S.brushShape == BrushShape.ZigZag then
				-- ZigZag is a Z-shaped profile - just use box for visualization
				-- The actual operation creates a Z-shape inside this bounding box
				S.brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
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
							wedge.Archivable = false -- Exclude from undo history
							wedge.Anchored = true
							wedge.CanCollide = false
							wedge.CanQuery = false
							wedge.CastShadow = false
							wedge.Material = Enum.Material.Neon
							wedge.Color = Theme.Colors.BrushNormal
							wedge.Transparency = Theme.Transparency.BrushExtra
							wedge.Size = Vector3.new(spikeRadius, spikeHeight, spikeRadius)
							wedge.CFrame = spikeBase * CFrame.new(0, spikeHeight * 0.5, 0) * CFrame.Angles(0, math.rad(90 * wedgeIdx), 0)
							wedge.Parent = workspace
							table.insert(S.brushExtraParts, wedge)
							-- Add edge highlighting to wedge
							local selBox = createSelectionBox(wedge)
							table.insert(S.extraSelectionBoxes, selBox)
						end
					end
				end
				-- Update handle adornee part for proper handle sizing (full bounds including spikes)
				if S.handleAdorneePart then
					S.handleAdorneePart.Size = Vector3.new(sizeX, sizeY, sizeZ)
					S.handleAdorneePart.CFrame = finalCFrame
				end
			else
				-- Default fallback
				S.brushPart.Size = Vector3.new(sizeX, sizeY, sizeZ)
				S.brushPart.CFrame = finalCFrame
			end

			if S.hollowEnabled then
				S.brushPart.Transparency = math.max(S.brushPart.Transparency, 0.7)
			end

			-- Update main SelectionBox color
			if S.brushSelectionBox then
				S.brushSelectionBox.Color3 = S.brushLocked and Theme.Colors.BrushEdgeLocked or Theme.Colors.BrushEdge
			end

			local extraColor = S.brushLocked and Theme.Colors.BrushLocked or Theme.Colors.BrushNormal
			local extraEdgeColor = S.brushLocked and Theme.Colors.BrushEdgeLocked or Theme.Colors.BrushEdge
			for _, extraPart in ipairs(S.brushExtraParts) do
				extraPart.Color = extraColor
				if S.hollowEnabled then
					extraPart.Transparency = math.max(extraPart.Transparency, 0.7)
				end
			end
			-- Update extra SelectionBox colors
			for _, box in ipairs(S.extraSelectionBoxes) do
				box.Color3 = extraEdgeColor
			end

			updateHandlesAdornee()
		end
	end

	local function hideBrushVisualization()
		if S.brushPart then
			S.brushPart:Destroy()
			S.brushPart = nil
		end
		if S.brushSelectionBox then
			S.brushSelectionBox:Destroy()
			S.brushSelectionBox = nil
		end
		if S.handleAdorneePart then
			S.handleAdorneePart:Destroy()
			S.handleAdorneePart = nil
		end
		for _, part in ipairs(S.brushExtraParts) do
			part:Destroy()
		end
		S.brushExtraParts = {}
		for _, box in ipairs(S.extraSelectionBoxes) do
			box:Destroy()
		end
		S.extraSelectionBoxes = {}
		-- Clean up torus wireframe
		TorusMeshGenerator.destroyWireframe(S.torusWireframeParts)
		S.torusWireframeParts = {}
		S.torusLastMajorRadius = 0
		S.torusLastMinorRadius = 0
		-- Clean up dome wireframe
		DomeMeshGenerator.destroyWireframe(S.domeWireframeParts)
		S.domeWireframeParts = {}
		S.domeLastRadiusX = 0
		S.domeLastRadiusY = 0
		S.domeLastRadiusZ = 0
		S.domeLastIsRotated = false
		hideHandles()
	end

	-- ============================================================================
	-- 3D Handles
	-- ============================================================================
	local dragStartRotation = CFrame.new()

	local function createRotationHandles()
		-- Clean up existing handles
		for _, handle in ipairs(S.rotationHandles) do
			handle:Destroy()
		end
		S.rotationHandles = {}

		-- Create 3 separate ArcHandles, one per axis with axis-specific colors
		local axisConfig = {
			{ axis = Enum.Axis.X, color = Theme.Colors.HandleRotationX, vector = Vector3.new(1, 0, 0) },
			{ axis = Enum.Axis.Y, color = Theme.Colors.HandleRotationY, vector = Vector3.new(0, 1, 0) },
			{ axis = Enum.Axis.Z, color = Theme.Colors.HandleRotationZ, vector = Vector3.new(0, 0, 1) },
		}

		for i, config in ipairs(axisConfig) do
			local handles = Instance.new("ArcHandles")
			handles.Name = "BrushRotationHandles_" .. tostring(config.axis)
			handles.Color3 = config.color
			handles.Axes = Axes.new(config.axis) -- Show only this axis
			handles.Visible = false
			handles.Parent = CoreGui

			handles.MouseButton1Down:Connect(function()
				S.isHandleDragging = true
				dragStartRotation = S.brushRotation
			end)
			handles.MouseButton1Up:Connect(function()
				S.isHandleDragging = false
			end)
			handles.MouseDrag:Connect(function(axis, relativeAngle)
				S.brushRotation = dragStartRotation * CFrame.fromAxisAngle(config.vector, relativeAngle)
			end)

			table.insert(S.rotationHandles, handles)
		end
	end

	local function createSizeHandles()
		if S.sizeHandles then
			S.sizeHandles:Destroy()
		end
		S.sizeHandles = Instance.new("Handles")
		local handles = S.sizeHandles :: Handles
		handles.Name = "BrushSizeHandles"
		handles.Color3 = Theme.Colors.HandleSize
		handles.Style = Enum.HandlesStyle.Resize
		handles.Visible = false
		handles.Parent = CoreGui
		local dragStartSizeX, dragStartSizeY, dragStartSizeZ = S.brushSizeX, S.brushSizeY, S.brushSizeZ
		handles.MouseButton1Down:Connect(function()
			S.isHandleDragging = true
			dragStartSizeX, dragStartSizeY, dragStartSizeZ = S.brushSizeX, S.brushSizeY, S.brushSizeZ
		end)
		handles.MouseButton1Up:Connect(function()
			S.isHandleDragging = false
		end)
		handles.MouseDrag:Connect(function(face, distance)
			if not S.isHandleDragging then
				return
			end
			local deltaVoxels = distance / Constants.VOXEL_RESOLUTION

			-- Determine which axis the user is dragging
			local draggedAxis = "x"
			local dragStartVal = dragStartSizeX
			if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
				draggedAxis = "y"
				dragStartVal = dragStartSizeY
			elseif face == Enum.NormalId.Front or face == Enum.NormalId.Back then
				draggedAxis = "z"
				dragStartVal = dragStartSizeZ
			end

			local newSize = math.clamp(dragStartVal + deltaVoxels, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)

			-- Use ShapeDimensions to determine which axes to update
			local shapeDims = BrushData.ShapeDimensions[S.brushShape]
			if not shapeDims then
				-- Fallback: update just the dragged axis
				if draggedAxis == "x" then
					S.brushSizeX = newSize
				elseif draggedAxis == "y" then
					S.brushSizeY = newSize
				else
					S.brushSizeZ = newSize
				end
				return
			end

			-- Find which dimension the dragged axis belongs to, and update all linked axes
			for _, axisDef in ipairs(shapeDims.axes) do
				local containsDraggedAxis = false
				for _, axisName in ipairs(axisDef.maps) do
					if axisName == draggedAxis then
						containsDraggedAxis = true
						break
					end
				end
				if containsDraggedAxis then
					-- Update all axes in this dimension
					for _, axisName in ipairs(axisDef.maps) do
						if axisName == "x" then
							S.brushSizeX = newSize
						elseif axisName == "y" then
							S.brushSizeY = newSize
						elseif axisName == "z" then
							S.brushSizeZ = newSize
						end
					end
					break
				end
			end
		end)
	end

	updateHandlesAdornee = function()
		-- Use handleAdorneePart for composite shapes, brushPart for simple shapes
		local adorneePart = S.handleAdorneePart or S.brushPart
		-- Only show handles when brush is LOCKED - otherwise they steal mouse clicks
		local showRotation = S.brushLocked and adorneePart ~= nil and BrushData.ShapeSupportsRotation[S.brushShape] == true
		local showSize = S.brushLocked and adorneePart ~= nil
		for _, handle in ipairs(S.rotationHandles) do
			handle.Adornee = adorneePart
			handle.Visible = showRotation
		end
		if S.sizeHandles then
			S.sizeHandles.Adornee = adorneePart
			S.sizeHandles.Visible = showSize
		end
	end

	hideHandles = function()
		for _, handle in ipairs(S.rotationHandles) do
			handle.Visible = false
			handle.Adornee = nil
		end
		if S.sizeHandles then
			S.sizeHandles.Visible = false
			S.sizeHandles.Adornee = nil
		end
		S.isHandleDragging = false
	end

	destroyHandles = function()
		for _, handle in ipairs(S.rotationHandles) do
			handle:Destroy()
		end
		S.rotationHandles = {}
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
		part.Archivable = false -- Exclude from undo history
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.5, PLANE_SIZE, PLANE_SIZE)
		part.Transparency = Theme.Transparency.PlaneViz
		part.Material = Enum.Material.Neon
		part.Color = Theme.Colors.PlaneViz
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
		-- Filter bridge preview parts so they don't interfere with terrain hits
		for _, part in ipairs(S.bridgePreviewParts) do
			table.insert(filterInstances, part)
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
		-- Filter bridge preview parts so they don't interfere with terrain hits
		for _, part in ipairs(S.bridgePreviewParts) do
			table.insert(filterInstances, part)
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

		local actualSizeX, actualSizeY, actualSizeZ = S.brushSizeX, S.brushSizeY, S.brushSizeZ
		-- For uniform shapes (Sphere, Grid, Spinner), force all axes equal
		if BrushData.isUniformShape(S.brushShape) then
			actualSizeY, actualSizeZ = S.brushSizeX, S.brushSizeX
		end

		local brushRotation = BrushData.ShapeSupportsRotation[S.brushShape] and S.brushRotation or CFrame.new()
		local effectiveRotation = brushRotation
		if S.spinMode ~= SpinMode.Off then
			local operationSpeed = (S.spinMode == SpinMode.WorldYFast or S.spinMode == SpinMode.World3DFast) and 2 or 1
			S.spinAngle = S.spinAngle + (0.1 * operationSpeed)
			local spinRotation = calculateSpinRotation(S.spinMode, S.spinAngle)
			if isWorldRelativeSpin(S.spinMode) then
				-- World-relative: spin applied before brush rotation
				effectiveRotation = spinRotation * brushRotation
			else
				-- Shape-relative: spin applied after brush rotation (in local space)
				effectiveRotation = brushRotation * spinRotation
			end
		end

		-- Handle Surface pivot: pre-calculate position and use Center pivot for operation
		local operationPosition = position
		local operationPivot = S.pivotType
		if S.pivotType == PivotType.Surface then
			local sizeY = actualSizeY * Constants.VOXEL_RESOLUTION
			local sizeX = actualSizeX * Constants.VOXEL_RESOLUTION
			local sizeZ = actualSizeZ * Constants.VOXEL_RESOLUTION
			local surfaceY = findSurfaceHeight(position.X, position.Z, sizeX * 0.5, sizeZ * 0.5)
			if surfaceY then
				-- Position brush center so bottom is at surface height
				operationPosition = Vector3.new(position.X, surfaceY + sizeY * 0.5, position.Z)
			else
				-- No terrain found, fall back to bottom pivot behavior
				operationPosition = Vector3.new(position.X, position.Y + sizeY * 0.5, position.Z)
			end
			-- Use Center pivot since we've already positioned correctly
			operationPivot = PivotType.Center
		end

		local opSet = {
			currentTool = S.currentTool,
			brushShape = S.brushShape,
			flattenMode = S.flattenMode,
			pivot = operationPivot,
			centerPoint = operationPosition,
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
			pathDepth = S.pathDepth,
			pathProfile = S.pathProfile,
			pathDirectionX = S.pathDirectionX,
			pathDirectionZ = S.pathDirectionZ,
			cloneSourceBuffer = S.cloneSourceBuffer,
			cloneSourceCenter = S.cloneSourceCenter,
			blobIntensity = S.blobIntensity,
			blobSmoothness = S.blobSmoothness,
			slopeFlatMaterial = S.slopeFlatMaterial,
			slopeSteepMaterial = S.slopeSteepMaterial,
			slopeCliffMaterial = S.slopeCliffMaterial,
			slopeThreshold1 = S.slopeThreshold1,
			slopeThreshold2 = S.slopeThreshold2,
			materialPalette = S.megarandomizeMaterials,
			clusterSize = S.megarandomizeClusterSize,
			megarandomizeSeed = S.megarandomizeSeed,
			cavitySensitivity = S.cavitySensitivity,
			meltViscosity = S.meltViscosity,
			gradientMaterial1 = S.gradientMaterial1,
			gradientMaterial2 = S.gradientMaterial2,
			gradientStartX = S.gradientStartPoint and S.gradientStartPoint.X or 0,
			gradientStartZ = S.gradientStartPoint and S.gradientStartPoint.Z or 0,
			gradientEndX = S.gradientEndPoint and S.gradientEndPoint.X or 100,
			gradientEndZ = S.gradientEndPoint and S.gradientEndPoint.Z or 0,
			gradientNoiseAmount = S.gradientNoiseAmount,
			floodTargetMaterial = S.floodTargetMaterial,
			floodSourceMaterial = S.floodReplaceAll and nil or S.floodSourceMaterial,
			stalactiteDirection = S.stalactiteDirection,
			stalactiteDensity = S.stalactiteDensity,
			stalactiteLength = S.stalactiteLength,
			stalactiteTaper = S.stalactiteTaper,
			tendrilRadius = S.tendrilRadius,
			tendrilBranches = S.tendrilBranches,
			tendrilLength = S.tendrilLength,
			tendrilCurl = S.tendrilCurl,
			symmetryType = S.symmetryType,
			symmetrySegments = S.symmetrySegments,
			gridCellSize = S.gridCellSize,
			gridVariation = S.gridVariation,
			gridSeed = S.gridSeed,
			growthRate = S.growthRate,
			growthBias = S.growthBias,
			growthPattern = S.growthPattern,
			growthSeed = S.growthSeed,
			falloffType = S.falloffType,
			falloffExtent = S.falloffExtent,
			-- Grow tool: emphasize brush center (depth falloff along view direction)
			emphasizeBrushCenter = S.emphasizeBrushCenter,
			cameraPosition = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.zero,
		}

		-- Handle Symmetry tool: duplicate operation at rotated positions
		if S.currentTool == ToolId.Symmetry and S.symmetrySegments > 1 then
			-- Set symmetry center on first stroke if not set
			if not S.symmetryCenter then
				S.symmetryCenter = position
			end

			local center = S.symmetryCenter
			local segments = S.symmetrySegments

			for i = 0, segments - 1 do
				local angle = (i / segments) * math.pi * 2

				-- Calculate rotated position around center (Y axis rotation)
				local offset = position - center
				local rotatedX = offset.X * math.cos(angle) - offset.Z * math.sin(angle)
				local rotatedZ = offset.X * math.sin(angle) + offset.Z * math.cos(angle)
				local rotatedPosition = center + Vector3.new(rotatedX, offset.Y, rotatedZ)

				-- Update the operation's center point
				local symmetricOpSet = {}
				for k, v in pairs(opSet) do
					symmetricOpSet[k] = v
				end
				symmetricOpSet.centerPoint = rotatedPosition

				-- Also rotate the brush if it supports rotation
				if BrushData.ShapeSupportsRotation[S.brushShape] then
					symmetricOpSet.brushRotation = opSet.brushRotation * CFrame.Angles(0, angle, 0)
				end

				local success, err = pcall(function()
					performTerrainBrushOperation(S.terrain, symmetricOpSet)
				end)
				if not success then
					warn("[TerrainEditorFork] Symmetry brush operation failed:", err)
				end
			end
		else
			-- Normal single operation
			local success, err = pcall(function()
				performTerrainBrushOperation(S.terrain, opSet)
			end)
			if not success then
				warn("[TerrainEditorFork] Brush operation failed:", err)
			end
		end
	end

	local function startBrushing()
		if S.brushConnection then
			return
		end
		-- Note: We only set a waypoint in stopBrushing() AFTER the edit completes.
		-- Setting one here would create duplicate waypoints (the end of one stroke
		-- and start of the next are at the same terrain state), causing extra undo steps.

		S.brushConnection = RunService.Heartbeat:Connect(function()
			-- Don't run during play test
			if not RunService:IsEdit() then
				return
			end

			if not S.isMouseDown or S.currentTool == ToolId.None or S.isHandleDragging or S.brushLocked then
				return
			end

			local hitPosition = getTerrainHit()
			if not hitPosition then
				return
			end

			local shouldActivate = false
			local mouseMoved = false
			local MOVEMENT_THRESHOLD = 4

			if S.lastBrushPosition then
				local moveDistance = (hitPosition - S.lastBrushPosition).Magnitude
				if moveDistance > MOVEMENT_THRESHOLD then
					mouseMoved = true
				end
			end

			local now = tick()
			local timeSinceLastActivation = now - S.lastBrushTime

			if S.brushRate == "no_repeat" then
				if S.lastBrushTime == 0 then
					shouldActivate = true
					S.lastBrushTime = now
				end
			elseif S.brushRate == "on_move_only" then
				if S.lastBrushTime == 0 then
					shouldActivate = true
					S.lastBrushTime = now
				elseif mouseMoved then
					shouldActivate = true
					S.lastBrushTime = now
				end
			else
				local rateMap = { very_slow = 1, slow = 0.5, normal = 0.2, fast = 0.1 }
				local brushCooldown = rateMap[S.brushRate] or 0.1
				local minCooldown = 0.05

				if mouseMoved and timeSinceLastActivation >= minCooldown then
					shouldActivate = true
					S.lastBrushTime = now
				elseif timeSinceLastActivation >= brushCooldown then
					shouldActivate = true
					S.lastBrushTime = now
				end
			end

			if shouldActivate then
				if (S.currentTool == ToolId.Cliff or S.currentTool == ToolId.Path) and S.lastMouseWorldPos then
					local delta = hitPosition - S.lastMouseWorldPos
					local horizDelta = Vector3.new(delta.X, 0, delta.Z)
					if horizDelta.Magnitude > 0.5 then
						local dir = horizDelta.Unit
						if S.currentTool == ToolId.Cliff then
							S.cliffDirectionX, S.cliffDirectionZ = dir.X, dir.Z
						elseif S.currentTool == ToolId.Path then
							S.pathDirectionX, S.pathDirectionZ = dir.X, dir.Z
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
		S.lastBrushTime = 0
	end

	-- ============================================================================
	-- Build UI
	-- ============================================================================
	local mainFrame = Instance.new("ScrollingFrame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromScale(1, 1)
	mainFrame.BackgroundColor3 = Theme.Colors.Background
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
	versionLabel.Font = Theme.Fonts.Default
	versionLabel.TextSize = Theme.Sizes.TextSmall
	versionLabel.TextColor3 = Theme.Colors.TextDim
	versionLabel.TextXAlignment = Enum.TextXAlignment.Right
	versionLabel.TextScaled = true
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
	title.Font = Theme.Fonts.Bold
	title.TextSize = Theme.Sizes.TextLarge
	title.TextColor3 = Theme.Colors.Text
	title.TextScaled = true
	title.Text = "🌋 Terrain Editor Fork v" .. VERSION
	title.Parent = mainFrame

	UIHelpers.createHeader(mainFrame, "Tools", UDim2.new(0, 0, 0, 35))

	-- Tools section: buttons on left, documentation on right
	local toolsSection = Instance.new("Frame")
	toolsSection.Name = "ToolsSection"
	toolsSection.BackgroundTransparency = 1
	toolsSection.Position = UDim2.new(0, 0, 0, 55)
	toolsSection.Size = UDim2.new(1, 0, 0, 560) -- 6 categories with 3-col layout
	toolsSection.Parent = mainFrame

	-- Tool buttons container (left side)
	local toolButtonsContainer = Instance.new("Frame")
	toolButtonsContainer.Name = "ToolButtonsContainer"
	toolButtonsContainer.BackgroundTransparency = 1
	toolButtonsContainer.Position = UDim2.new(0, 0, 0, 0)
	toolButtonsContainer.Size = UDim2.new(0, 230, 1, 0) -- 3 columns × 74px + padding
	toolButtonsContainer.Parent = toolsSection

	-- Tool documentation container (right side, toggleable)
	local toolDocsContainer = Instance.new("ScrollingFrame")
	toolDocsContainer.Name = "ToolDocsContainer"
	toolDocsContainer.BackgroundColor3 = Theme.Colors.Panel
	toolDocsContainer.BorderSizePixel = 0
	toolDocsContainer.Position = UDim2.new(0, 232, 0, 0) -- Right after buttons
	toolDocsContainer.Size = UDim2.new(1, -242, 1, 0)
	toolDocsContainer.ScrollBarThickness = 4
	toolDocsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	toolDocsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	toolDocsContainer.Visible = S.showDocsPanel
	toolDocsContainer.Parent = toolsSection

	local docsCorner = Instance.new("UICorner")
	docsCorner.CornerRadius = UDim.new(0, 6)
	docsCorner.Parent = toolDocsContainer

	local docsPadding = Instance.new("UIPadding")
	docsPadding.PaddingLeft = UDim.new(0, 10)
	docsPadding.PaddingRight = UDim.new(0, 10)
	docsPadding.PaddingTop = UDim.new(0, 8)
	docsPadding.PaddingBottom = UDim.new(0, 8)
	docsPadding.Parent = toolDocsContainer

	-- Close button for docs panel (top-right)
	local docsCloseBtn = Instance.new("TextButton")
	docsCloseBtn.Name = "CloseButton"
	docsCloseBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	docsCloseBtn.BorderSizePixel = 0
	docsCloseBtn.Position = UDim2.new(1, -24, 0, 4)
	docsCloseBtn.Size = UDim2.new(0, 20, 0, 20)
	docsCloseBtn.Font = Enum.Font.GothamBold
	docsCloseBtn.TextSize = 14
	docsCloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	docsCloseBtn.TextScaled = true
	docsCloseBtn.Text = "×"
	docsCloseBtn.ZIndex = 10
	docsCloseBtn.Parent = toolDocsContainer

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 4)
	closeCorner.Parent = docsCloseBtn

	-- Placeholder message when no tool selected
	local docsPlaceholder = Instance.new("TextLabel")
	docsPlaceholder.Name = "Placeholder"
	docsPlaceholder.BackgroundTransparency = 1
	docsPlaceholder.Size = UDim2.new(1, 0, 1, 0)
	docsPlaceholder.Font = Theme.Fonts.Default
	docsPlaceholder.TextSize = 12
	docsPlaceholder.TextColor3 = Theme.Colors.TextDim
	docsPlaceholder.TextWrapped = true
	docsPlaceholder.TextScaled = true
	docsPlaceholder.Text = "← Select a tool to see documentation"
	docsPlaceholder.Parent = toolDocsContainer

	-- Function to toggle docs panel visibility
	setDocsPanelVisible = function(visible: boolean)
		S.showDocsPanel = visible
		toolDocsContainer.Visible = visible
		if updateDocsToggleButton then
			updateDocsToggleButton()
		end
	end

	docsCloseBtn.MouseButton1Click:Connect(function()
		setDocsPanelVisible(false)
	end)

	-- Tool categories with visual sections
	-- Each category: { label, emoji, color, tools[] }
	local toolCategories = {
		{
			label = "SHAPE",
			emoji = "🔷",
			color = Color3.fromRGB(100, 180, 255),
			tools = {
				{ id = ToolId.Add, name = "Add" },
				{ id = ToolId.Subtract, name = "Subtract" },
				{ id = ToolId.Grow, name = "Grow" },
				{ id = ToolId.Erode, name = "Erode" },
				{ id = ToolId.Smooth, name = "Smooth" },
				{ id = ToolId.Flatten, name = "Flatten" },
			},
		},
		{
			label = "SURFACE",
			emoji = "🌊",
			color = Color3.fromRGB(120, 200, 160),
			tools = {
				{ id = ToolId.Noise, name = "Noise" },
				{ id = ToolId.Terrace, name = "Terrace" },
				{ id = ToolId.Cliff, name = "Cliff" },
				{ id = ToolId.Path, name = "Path" },
				{ id = ToolId.Blobify, name = "Blobify" },
			},
		},
		{
			label = "MATERIAL",
			emoji = "🎨",
			color = Color3.fromRGB(255, 180, 100),
			tools = {
				{ id = ToolId.Paint, name = "Paint" },
				{ id = ToolId.SlopePaint, name = "Slope" },
				{ id = ToolId.Megarandomize, name = "Random" },
				{ id = ToolId.GradientPaint, name = "Gradient" },
				{ id = ToolId.CavityFill, name = "Cavity" },
				{ id = ToolId.FloodPaint, name = "Flood" },
			},
		},
		{
			label = "GENERATE",
			emoji = "✨",
			color = Color3.fromRGB(200, 150, 255),
			tools = {
				{ id = ToolId.Stalactite, name = "Stalactite" },
				{ id = ToolId.Tendril, name = "Tendril" },
				{ id = ToolId.VariationGrid, name = "Grid" },
				{ id = ToolId.GrowthSim, name = "Growth" },
			},
		},
		{
			label = "UTILITY",
			emoji = "🔧",
			color = Color3.fromRGB(180, 180, 180),
			tools = {
				{ id = ToolId.Clone, name = "Clone" },
				{ id = ToolId.Melt, name = "Melt" },
				{ id = ToolId.Symmetry, name = "Symmetry" },
				{ id = ToolId.Bridge, name = "Bridge" },
			},
		},
		{
			label = "ANALYSIS",
			emoji = "🔍",
			color = Color3.fromRGB(150, 200, 255),
			btnColor = Color3.fromRGB(40, 60, 80),
			tools = {
				{ id = ToolId.VoxelInspect, name = "Inspect" },
				{ id = ToolId.ComponentAnalyzer, name = "Islands" },
				{ id = ToolId.OccupancyOverlay, name = "Overlay" },
			},
		},
	}

	-- Layout constants (button width + gap should match Theme.Sizes.ToolButtonWidth)
	local BUTTON_WIDTH = 74 -- 70px button + 4px gap
	local BUTTON_HEIGHT = 32
	local BUTTON_SPACING = 4
	local HEADER_HEIGHT = 16
	local SECTION_GAP = 6
	local COLS = 3

	local currentY = 0

	for _, category in ipairs(toolCategories) do
		-- Section header
		local header = Instance.new("TextLabel")
		header.Name = category.label .. "Header"
		header.BackgroundTransparency = 1
		header.Position = UDim2.new(0, 0, 0, currentY)
		header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
		header.Font = Enum.Font.GothamBold
		header.TextSize = 10
		header.TextColor3 = category.color
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextScaled = true
		header.Text = category.emoji .. " " .. category.label
		header.Parent = toolButtonsContainer

		currentY = currentY + HEADER_HEIGHT + 2

		-- Tool buttons for this category
		for i, toolInfo in ipairs(category.tools) do
			local col = (i - 1) % COLS
			local row = math.floor((i - 1) / COLS)
			local pos = UDim2.new(0, col * BUTTON_WIDTH, 0, currentY + row * (BUTTON_HEIGHT + BUTTON_SPACING))
			local btn = UIHelpers.createToolButton(toolButtonsContainer, toolInfo.id, toolInfo.name, pos)
			if category.btnColor then
				btn.BackgroundColor3 = category.btnColor
			end
			toolButtons[toolInfo.id] = btn
			btn.MouseButton1Click:Connect(function()
				selectTool(toolInfo.id)
			end)
		end

		-- Calculate rows used by this category
		local rowsUsed = math.ceil(#category.tools / COLS)
		currentY = currentY + rowsUsed * (BUTTON_HEIGHT + BUTTON_SPACING) + SECTION_GAP
	end

	-- Initialize tool documentation registry
	local toolsFolder = Src.Tools
	if toolsFolder then
		ToolRegistry.init(toolsFolder)
	end

	-- Create tool documentation panel (in the right side container)
	local toolDocsResult = ToolDocsPanel.create({
		parent = toolDocsContainer,
		getToolDocs = function(toolId: string)
			return ToolRegistry.getDocs(toolId)
		end,
	})

	-- Assign the updateToolDocs function (forward declared earlier)
	updateToolDocs = function()
		if S.currentTool == ToolId.None then
			toolDocsResult.setVisible(false)
			docsPlaceholder.Visible = true
		else
			docsPlaceholder.Visible = false
			toolDocsResult.update(S.currentTool)
		end
	end

	-- Config container
	local configContainer = Instance.new("Frame")
	configContainer.Name = "ConfigContainer"
	configContainer.BackgroundTransparency = 1
	configContainer.Position = UDim2.new(0, 0, 0, Theme.Sizes.ConfigStartY)
	configContainer.Size = UDim2.new(1, 0, 0, 800)
	configContainer.Parent = mainFrame

	local configLayout = Instance.new("UIListLayout")
	configLayout.SortOrder = Enum.SortOrder.LayoutOrder
	configLayout.Padding = UDim.new(0, Theme.Sizes.PanelPadding)
	configLayout.Parent = configContainer

	-- Create all panels using ConfigPanels module
	local configResult = ConfigPanels.create({
		configContainer = configContainer,
		S = S,
		ToolId = ToolId,
		createBrushVisualization = createBrushVisualization,
		hidePlaneVisualization = hidePlaneVisualization,
		getTerrainHitRaw = getTerrainHitRaw,
		ChangeHistoryService = ChangeHistoryService,
		toggleBrushLock = function()
			S.brushLocked = not S.brushLocked
			if S.brushLocked then
				print("[TerrainEditor] Brush LOCKED - drag handles to rotate/resize, press L to unlock")
			else
				print("[TerrainEditor] Brush UNLOCKED - brush follows mouse")
			end
			-- Update handles visibility immediately (only shown when locked)
			updateHandlesAdornee()
			if S.lockedBrushPosition then
				updateBrushVisualization(S.lockedBrushPosition)
			end
		end,
	})

	local setStrengthValue = configResult.setStrengthValue
	local updateLockButton = configResult.updateLockButton
	updateConfigPanelVisibility = configResult.updateVisibility
	local updateBridgeStatus = configResult.updateBridgeStatus
	local updateBridgePreview = configResult.updateBridgePreview
	local buildBridge = configResult.buildBridge

	updateConfigPanelVisibility()
	updateToolButtonVisuals()
	updateToolDocs()
	pluginInstance:Activate(true)

	-- ============================================================================
	-- Footer Panel (Reset + Docs Toggle) - inside configContainer for proper flow
	-- ============================================================================
	local footerPanel = Instance.new("Frame")
	footerPanel.Name = "FooterPanel"
	footerPanel.BackgroundTransparency = 1
	footerPanel.Size = UDim2.new(1, 0, 0, 70)
	footerPanel.LayoutOrder = 999 -- Always at the bottom
	footerPanel.Parent = configContainer

	-- Reset button - stands out with accent color
	local resetBtn = Instance.new("TextButton")
	resetBtn.Name = "ResetButton"
	resetBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70) -- Red-ish to stand out
	resetBtn.BorderSizePixel = 0
	resetBtn.Position = UDim2.new(0, 0, 0, 0)
	resetBtn.Size = UDim2.new(0, 100, 0, 28)
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextSize = 12
	resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	resetBtn.TextScaled = true
	resetBtn.Text = "⟲ Reset"
	resetBtn.Parent = footerPanel

	local resetCorner = Instance.new("UICorner")
	resetCorner.CornerRadius = UDim.new(0, 5)
	resetCorner.Parent = resetBtn

	-- Subtle glow effect on hover
	resetBtn.MouseEnter:Connect(function()
		resetBtn.BackgroundColor3 = Color3.fromRGB(200, 90, 90)
	end)
	resetBtn.MouseLeave:Connect(function()
		resetBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	end)

	-- Reset function - restores all settings to defaults
	local function resetAllSettings()
		-- Size
		S.brushSizeX = Constants.INITIAL_BRUSH_SIZE
		S.brushSizeY = Constants.INITIAL_BRUSH_SIZE
		S.brushSizeZ = Constants.INITIAL_BRUSH_SIZE

		-- Strength
		S.brushStrength = Constants.INITIAL_BRUSH_STRENGTH
		setStrengthValue(100) -- 100% = 1.0

		-- Shape
		S.brushShape = BrushShape.Sphere
		S.brushRotation = CFrame.new()

		-- Material
		S.brushMaterial = Enum.Material.Grass

		-- Pivot and modes
		S.pivotType = PivotType.Bottom
		S.flattenMode = FlattenMode.Both
		S.autoMaterial = false
		S.ignoreWater = false
		S.planeLockMode = PlaneLockType.Off
		S.planePositionY = Constants.INITIAL_PLANE_POSITION_Y
		S.autoPlaneActive = false
		S.spinMode = SpinMode.Off
		S.spinAngle = 0
		S.hollowEnabled = false
		S.wallThickness = 0.2
		S.brushRate = "normal"

		-- Falloff
		S.falloffType = "Cosine"
		S.falloffExtent = 0

		-- Noise settings
		S.noiseScale = 4
		S.noiseIntensity = 0.5
		S.noiseSeed = 0

		-- Terrace settings
		S.stepHeight = 8
		S.stepSharpness = 0.8

		-- Cliff settings
		S.cliffAngle = 90
		S.cliffDirectionX = 1
		S.cliffDirectionZ = 0

		-- Path settings
		S.pathDepth = 6
		S.pathProfile = "U"
		S.pathDirectionX = 0
		S.pathDirectionZ = 1

		-- Clone
		S.cloneSourceBuffer = nil
		S.cloneSourceCenter = nil

		-- Blobify
		S.blobIntensity = 0.5
		S.blobSmoothness = 0.7

		-- Slope paint
		S.slopeFlatMaterial = Enum.Material.Grass
		S.slopeSteepMaterial = Enum.Material.Rock
		S.slopeCliffMaterial = Enum.Material.Slate
		S.slopeThreshold1 = 30
		S.slopeThreshold2 = 60

		-- Megarandomize
		S.megarandomizeMaterials = {
			{ material = Enum.Material.Grass, weight = 0.6 },
			{ material = Enum.Material.Rock, weight = 0.25 },
			{ material = Enum.Material.Ground, weight = 0.15 },
		}
		S.megarandomizeClusterSize = 4
		S.megarandomizeSeed = 0

		-- Cavity
		S.cavitySensitivity = 0.3

		-- Melt
		S.meltViscosity = 0.5

		-- Gradient
		S.gradientMaterial1 = Enum.Material.Grass
		S.gradientMaterial2 = Enum.Material.Rock
		S.gradientStartPoint = nil
		S.gradientEndPoint = nil
		S.gradientNoiseAmount = 0.1
		S.gradientSeed = 0

		-- Flood
		S.floodTargetMaterial = Enum.Material.Grass
		S.floodSourceMaterial = nil
		S.floodReplaceAll = true

		-- Stalactite
		S.stalactiteDirection = -1
		S.stalactiteDensity = 0.3
		S.stalactiteLength = 10
		S.stalactiteTaper = 0.8
		S.stalactiteSeed = 0

		-- Tendril
		S.tendrilRadius = 1.5
		S.tendrilBranches = 5
		S.tendrilLength = 15
		S.tendrilCurl = 0.5
		S.tendrilSeed = 0

		-- Symmetry
		S.symmetryType = "Radial4"
		S.symmetrySegments = 4
		S.symmetryCenter = nil

		-- Grid
		S.gridCellSize = 8
		S.gridVariation = 0.3
		S.gridSeed = 0

		-- Growth
		S.growthRate = 0.3
		S.growthBias = 0
		S.growthPattern = "organic"
		S.growthSeed = 0

		-- Bridge
		S.bridgeStartPoint = nil
		S.bridgeEndPoint = nil
		S.bridgeWidth = 4
		S.bridgeVariant = "Arc"
		S.bridgeCurves = {}
		S.bridgeEditMode = false
		S.bridgeSelectedConnection = nil
		S.bridgeMeanderComplexity = 5
		S.bridgeHoverPoint = nil
		S.bridgeLastPreviewParams = nil

		-- Brush lock
		S.brushLocked = false
		S.lockedBrushPosition = nil

		-- Rebuild UI elements
		createBrushVisualization()
		if configResult.rebuildSizeSliders then
			configResult.rebuildSizeSliders()
		end
		updateLockButton()
		if updateConfigPanelVisibility then
			updateConfigPanelVisibility()
		end
		if updateBridgeStatus then
			updateBridgeStatus()
		end
		if S.updateGradientStatus then
			S.updateGradientStatus()
		end

		print("[TerrainEditor] All settings reset to defaults")
	end

	resetBtn.MouseButton1Click:Connect(resetAllSettings)

	-- Docs toggle button
	local docsToggleBtn = Instance.new("TextButton")
	docsToggleBtn.Name = "DocsToggle"
	docsToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	docsToggleBtn.BorderSizePixel = 0
	docsToggleBtn.Position = UDim2.new(0, 0, 0, 36) -- Below reset button
	docsToggleBtn.Size = UDim2.new(0, 160, 0, 26)
	docsToggleBtn.Font = Enum.Font.GothamMedium
	docsToggleBtn.TextSize = 11
	docsToggleBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
	docsToggleBtn.TextScaled = true
	docsToggleBtn.Text = S.showDocsPanel and "📖 Hide Tool Docs" or "📖 Show Tool Docs"
	docsToggleBtn.Parent = footerPanel

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 4)
	toggleCorner.Parent = docsToggleBtn

	-- Assign to forward-declared variable
	updateDocsToggleButton = function()
		docsToggleBtn.Text = S.showDocsPanel and "📖 Hide Tool Docs" or "📖 Show Tool Docs"
		docsToggleBtn.BackgroundColor3 = S.showDocsPanel and Color3.fromRGB(60, 80, 60) or Color3.fromRGB(50, 50, 55)
	end

	docsToggleBtn.MouseButton1Click:Connect(function()
		if setDocsPanelVisible then
			setDocsPanelVisible(not S.showDocsPanel)
		end
	end)

	-- ============================================================================
	-- Mouse & Input Handling
	-- ============================================================================
	local allConnections: { RBXScriptConnection } = {}

	local function addConnection(conn: RBXScriptConnection)
		table.insert(allConnections, conn)
	end

	addConnection(mouse.Button1Down:Connect(function()
		if S.currentTool ~= ToolId.None then
			-- Voxel Inspector: toggle lock on click
			if S.currentTool == ToolId.VoxelInspect then
				S.voxelInspectLocked = not S.voxelInspectLocked
				if S.updateVoxelInspectDisplay then
					S.updateVoxelInspectDisplay()
				end
				return
			end

			-- Component Analyzer and Occupancy Overlay don't use mouse clicks for brushing
			if S.currentTool == ToolId.ComponentAnalyzer or S.currentTool == ToolId.OccupancyOverlay then
				return
			end

			if S.currentTool == ToolId.Bridge then
				local hitPosition = getTerrainHit()
				if hitPosition then
					if not S.bridgeStartPoint then
						S.bridgeStartPoint = hitPosition
						S.bridgeCurves = {}
						updateBridgeStatus()
						updateBridgePreview(nil)
					elseif not S.bridgeEndPoint then
						S.bridgeEndPoint = hitPosition
						if S.bridgeVariant == "MegaMeander" and #S.bridgeCurves == 0 then
							S.bridgeCurves = BridgePathGenerator.generateRandomCurves(S.bridgeMeanderComplexity)
						end
						updateBridgeStatus()
						updateBridgePreview(nil)
					else
						buildBridge()
					end
				end
				return
			end

			if S.currentTool == ToolId.GradientPaint then
				local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
				local ctrlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
					or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
				if shiftHeld then
					local hitPosition = getTerrainHit()
					if hitPosition then
						S.gradientStartPoint = hitPosition
						if S.updateGradientStatus then
							S.updateGradientStatus()
						end
					end
					return
				elseif ctrlHeld then
					local hitPosition = getTerrainHit()
					if hitPosition then
						S.gradientEndPoint = hitPosition
						if S.updateGradientStatus then
							S.updateGradientStatus()
						end
					end
					return
				end
			end

			if S.currentTool == ToolId.Clone then
				local altHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
				if altHeld then
					local hitPosition = getTerrainHit()
					if hitPosition then
						local regionSize = Vector3.new(S.brushSizeX, S.brushSizeY, S.brushSizeZ) * Constants.VOXEL_RESOLUTION
						local region = Region3.new(hitPosition - regionSize * 0.5, hitPosition + regionSize * 0.5)
						local materials, occupancies = S.terrain:ReadVoxels(region, Constants.VOXEL_RESOLUTION)
						S.cloneSourceBuffer = {}
						local sizeX, sizeY, sizeZ = #materials, #materials[1], #materials[1][1]
						local centerX, centerY, centerZ = math.floor(sizeX / 2) + 1, math.floor(sizeY / 2) + 1, math.floor(sizeZ / 2) + 1
						local buffer = S.cloneSourceBuffer :: any
						for x = 1, sizeX do
							buffer[x] = {}
							for y = 1, sizeY do
								buffer[x][y] = {}
								for z = 1, sizeZ do
									buffer[x][y][z] = { occupancy = occupancies[x][y][z], material = materials[x][y][z] }
								end
							end
						end
						S.cloneSourceCenter = Vector3.new(centerX, centerY, centerZ)
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

	addConnection(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		if S.currentTool == ToolId.None then
			return
		end

		local scrollUp = input.Position.Z > 0
		local ctrlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local altHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)

		if shiftHeld and not ctrlHeld then
			-- Shift + Scroll = primary axis (or uniform for multi-axis shapes)
			-- Shift + Alt + Scroll = secondary axis
			local referenceSize = S.brushSizeX
			local increment = referenceSize < 10 and 1 or (referenceSize < 30 and 2 or 4)
			local delta = scrollUp and increment or -increment

			if altHeld then
				-- Secondary axis
				local secondaryAxis = BrushData.getSecondaryAxis(S.brushShape)
				if secondaryAxis then
					local currentVal = S.brushSizeY -- Get current value from first mapped axis
					if secondaryAxis.maps[1] == "x" then
						currentVal = S.brushSizeX
					elseif secondaryAxis.maps[1] == "z" then
						currentVal = S.brushSizeZ
					end
					local newSize = math.clamp(currentVal + delta, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
					-- Apply to all mapped axes
					for _, axis in ipairs(secondaryAxis.maps) do
						if axis == "x" then
							S.brushSizeX = newSize
						elseif axis == "y" then
							S.brushSizeY = newSize
						elseif axis == "z" then
							S.brushSizeZ = newSize
						end
					end
				end
			else
				-- Primary axis (or uniform for scrollUniform shapes)
				if BrushData.usesUniformScroll(S.brushShape) then
					-- Scale all axes uniformly
					local newSize = math.clamp(S.brushSizeX + delta, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
					S.brushSizeX, S.brushSizeY, S.brushSizeZ = newSize, newSize, newSize
				else
					-- Use primary axis
					local primaryAxis = BrushData.getPrimaryAxis(S.brushShape)
					if primaryAxis then
						local currentVal = S.brushSizeX
						if primaryAxis.maps[1] == "y" then
							currentVal = S.brushSizeY
						elseif primaryAxis.maps[1] == "z" then
							currentVal = S.brushSizeZ
						end
						local newSize = math.clamp(currentVal + delta, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
						-- Apply to all mapped axes
						for _, axis in ipairs(primaryAxis.maps) do
							if axis == "x" then
								S.brushSizeX = newSize
							elseif axis == "y" then
								S.brushSizeY = newSize
							elseif axis == "z" then
								S.brushSizeZ = newSize
							end
						end
					else
						-- Fallback: adjust X only
						S.brushSizeX = math.clamp(S.brushSizeX + delta, Constants.MIN_BRUSH_SIZE, Constants.MAX_BRUSH_SIZE)
					end
				end
			end
		elseif ctrlHeld and not shiftHeld then
			local delta = scrollUp and 10 or -10
			local newStrength = math.clamp(math.floor(S.brushStrength * 100) + delta, 1, 100)
			setStrengthValue(newStrength)
		end
	end))

	addConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.L then
			if S.currentTool == ToolId.None then
				return
			end
			S.brushLocked = not S.brushLocked
			if S.brushLocked then
				print("[TerrainEditor] Brush LOCKED - drag handles to rotate/resize, press L to unlock")
			else
				print("[TerrainEditor] Brush UNLOCKED - brush follows mouse")
			end
			-- Update handles visibility immediately (only shown when locked)
			updateHandlesAdornee()
			if S.lockedBrushPosition then
				updateBrushVisualization(S.lockedBrushPosition)
			end
			updateLockButton()
		end
	end))

	S.renderConnection = RunService.RenderStepped:Connect(function()
		-- Don't run plugin logic during play test
		if not RunService:IsEdit() then
			hideBrushVisualization()
			hidePlaneVisualization()
			return
		end

		local gui = parentGui :: GuiObject
		local isVisible = if gui:IsA("ScreenGui") then (gui :: ScreenGui).Enabled else true

		if S.currentTool ~= ToolId.None and isVisible then
			local hitPosition = getTerrainHit()
			local brushPosition = hitPosition

			-- Analysis tools don't use brush visualization
			local isAnalysisTool = S.currentTool == ToolId.VoxelInspect
				or S.currentTool == ToolId.ComponentAnalyzer
				or S.currentTool == ToolId.OccupancyOverlay

			if S.brushLocked and S.lockedBrushPosition then
				brushPosition = S.lockedBrushPosition
			elseif hitPosition then
				S.lockedBrushPosition = hitPosition
			end

			if brushPosition and not isAnalysisTool then
				updateBrushVisualization(brushPosition)
				local showPlane = (S.planeLockMode == PlaneLockType.Manual) or (S.planeLockMode == PlaneLockType.Auto and S.autoPlaneActive)
				if showPlane then
					updatePlaneVisualization(brushPosition.X, brushPosition.Z)
				else
					hidePlaneVisualization()
				end
			elseif isAnalysisTool then
				hideBrushVisualization()
				hidePlaneVisualization()
			end

			if S.currentTool == ToolId.Bridge and S.bridgeStartPoint and not S.bridgeEndPoint then
				if hitPosition then
					S.bridgeHoverPoint = hitPosition
					updateBridgePreview(hitPosition)
				end
			elseif S.currentTool ~= ToolId.Bridge then
				S.bridgeHoverPoint = nil
			end

			-- Voxel Inspector: update live display on hover
			if S.currentTool == ToolId.VoxelInspect and not S.voxelInspectLocked and hitPosition then
				-- Convert world position to voxel grid coordinates
				local VOXEL_SIZE = 4
				local gridX = math.floor(hitPosition.X / VOXEL_SIZE)
				local gridY = math.floor(hitPosition.Y / VOXEL_SIZE)
				local gridZ = math.floor(hitPosition.Z / VOXEL_SIZE)

				-- Read the voxel at this position
				local voxelMin = Vector3.new(gridX * VOXEL_SIZE, gridY * VOXEL_SIZE, gridZ * VOXEL_SIZE)
				local voxelMax = voxelMin + Vector3.new(VOXEL_SIZE, VOXEL_SIZE, VOXEL_SIZE)

				local region = Region3.new(voxelMin, voxelMax)
				local materials, occupancies = S.terrain:ReadVoxels(region, VOXEL_SIZE)

				if materials and occupancies then
					local mat = materials[1] and materials[1][1] and materials[1][1][1] or Enum.Material.Air
					local occ = occupancies[1] and occupancies[1][1] and occupancies[1][1][1] or 0

					S.voxelInspectPosition = hitPosition
					S.voxelInspectGridPos = Vector3.new(gridX, gridY, gridZ)
					S.voxelInspectMaterial = mat
					S.voxelInspectOccupancy = occ

					-- Update the highlight box
					if not S.voxelInspectHighlight then
						local highlight = Instance.new("Part")
						highlight.Name = "VoxelInspectHighlight"
						highlight.Archivable = false -- Exclude from undo history
						highlight.Anchored = true
						highlight.CanCollide = false
						highlight.Transparency = 0.7
						highlight.Color = Color3.fromRGB(100, 200, 255)
						highlight.Material = Enum.Material.Neon
						highlight.Size = Vector3.new(VOXEL_SIZE, VOXEL_SIZE, VOXEL_SIZE)
						highlight.Parent = workspace
						S.voxelInspectHighlight = highlight
					end

					S.voxelInspectHighlight.Position = voxelMin + Vector3.new(VOXEL_SIZE / 2, VOXEL_SIZE / 2, VOXEL_SIZE / 2)
					S.voxelInspectHighlight.Transparency = 0.7

					if S.updateVoxelInspectDisplay then
						S.updateVoxelInspectDisplay()
					end
				end
			elseif S.currentTool == ToolId.VoxelInspect and S.voxelInspectLocked and S.voxelInspectHighlight then
				-- When locked, make the highlight more visible
				S.voxelInspectHighlight.Transparency = 0.3
				S.voxelInspectHighlight.Color = Color3.fromRGB(255, 200, 100)
			elseif S.currentTool ~= ToolId.VoxelInspect and S.voxelInspectHighlight then
				-- Hide highlight when not using inspect tool
				S.voxelInspectHighlight.Transparency = 1
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

	-- Cleanup function
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
		-- Cleanup voxel inspect highlight
		if S.voxelInspectHighlight then
			S.voxelInspectHighlight:Destroy()
			S.voxelInspectHighlight = nil
		end
		pluginInstance:Deactivate()
	end
end

return TerrainEditorModule
