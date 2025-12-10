--!strict
-- CorePanels.lua - Core brush setting panels shared by most tools
-- Panels: Shape, Strength, BrushRate, Pivot, Hollow, Spin, PlaneLock, FlattenMode

local Theme = require(script.Parent.Parent.Parent.Util.Theme)
local UIHelpers = require(script.Parent.Parent.Parent.Util.UIHelpers)
local UIComponents = require(script.Parent.Parent.Parent.Util.UIComponents)
local BrushData = require(script.Parent.Parent.Parent.Util.BrushData)
local TerrainEnums = require(script.Parent.Parent.Parent.Util.TerrainEnums)

local PivotType = TerrainEnums.PivotType
local FlattenMode = TerrainEnums.FlattenMode
local PlaneLockType = TerrainEnums.PlaneLockType
local SpinMode = TerrainEnums.SpinMode

local CorePanels = {}

export type CorePanelsDeps = {
	configContainer: Frame,
	S: any, -- State table
	createBrushVisualization: () -> (),
	hidePlaneVisualization: () -> (),
	getTerrainHitRaw: () -> Vector3?,
}

export type CorePanelsResult = {
	panels: { [string]: Frame },
	setStrengthValue: (value: number) -> (),
}

function CorePanels.create(deps: CorePanelsDeps): CorePanelsResult
	local panels: { [string]: Frame } = {}
	local S = deps.S

	-- ========================================================================
	-- Shape Panel
	-- ========================================================================
	local shapePanel = UIHelpers.createConfigPanel(deps.configContainer, "brushShape")

	local shapeHeader = UIHelpers.createHeader(shapePanel, "Brush Shape", UDim2.new(0, 0, 0, 0))
	shapeHeader.LayoutOrder = 1

	local shapeGroup = UIComponents.createButtonGroup({
		parent = shapePanel,
		options = BrushData.Shapes,
		initialValue = S.brushShape,
		onChange = function(newShape)
			S.brushShape = newShape
			if S.brushPart then
				deps.createBrushVisualization()
			end
		end,
		layout = "grid",
	})
	shapeGroup.container.LayoutOrder = 2

	panels["brushShape"] = shapePanel

	-- ========================================================================
	-- Strength Panel
	-- ========================================================================
	local strengthPanel = UIHelpers.createConfigPanel(deps.configContainer, "strength")

	local strengthHeader = UIHelpers.createHeader(strengthPanel, "Strength", UDim2.new(0, 0, 0, 0))
	strengthHeader.LayoutOrder = 1

	local _, strengthSliderContainer, setStrengthValue = UIHelpers.createSlider(
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

	panels["strength"] = strengthPanel

	-- ========================================================================
	-- Brush Rate Panel
	-- ========================================================================
	local brushRatePanel = UIHelpers.createConfigPanel(deps.configContainer, "brushRate")

	local rateHeader = UIHelpers.createHeader(brushRatePanel, "Brush Rate", UDim2.new(0, 0, 0, 0))
	rateHeader.LayoutOrder = 1

	local rateGroup = UIComponents.createButtonGroup({
		parent = brushRatePanel,
		options = {
			{ id = "no_repeat", name = "No repeat" },
			{ id = "on_move_only", name = "On move" },
			{ id = "very_slow", name = "Very slow" },
			{ id = "slow", name = "Slow" },
			{ id = "normal", name = "Normal" },
			{ id = "fast", name = "Fast" },
		},
		initialValue = S.brushRate,
		onChange = function(newRate)
			S.brushRate = newRate
		end,
		layout = "grid",
		buttonSize = UDim2.new(0, 78, 0, 28),
	})
	rateGroup.container.LayoutOrder = 2

	panels["brushRate"] = brushRatePanel

	-- ========================================================================
	-- Pivot Panel
	-- ========================================================================
	local pivotPanel = UIHelpers.createConfigPanel(deps.configContainer, "pivot")

	local pivotHeader = UIHelpers.createHeader(pivotPanel, "Pivot Position", UDim2.new(0, 0, 0, 0))
	pivotHeader.LayoutOrder = 1

	local pivotGroup = UIComponents.createButtonGroup({
		parent = pivotPanel,
		options = {
			{ id = PivotType.Bottom, name = "Bottom" },
			{ id = PivotType.Center, name = "Center" },
			{ id = PivotType.Top, name = "Top" },
		},
		initialValue = S.pivotType,
		onChange = function(newPivot)
			S.pivotType = newPivot
		end,
		layout = "horizontal",
	})
	pivotGroup.container.LayoutOrder = 2

	panels["pivot"] = pivotPanel

	-- ========================================================================
	-- Hollow Mode Panel
	-- ========================================================================
	local hollowPanel = UIHelpers.createConfigPanel(deps.configContainer, "hollow")

	local hollowHeader = UIHelpers.createHeader(hollowPanel, "Hollow Mode", UDim2.new(0, 0, 0, 0))
	hollowHeader.LayoutOrder = 1

	local hollowToggle = UIComponents.createToggleButton({
		parent = hollowPanel,
		initialState = S.hollowEnabled,
		textOn = "HOLLOW",
		textOff = "Solid",
		onChange = function(isHollow)
			S.hollowEnabled = isHollow
			thicknessContainer.Visible = isHollow
		end,
	})
	hollowToggle.button.LayoutOrder = 2

	local _, thicknessContainer, _ = UIHelpers.createSlider(hollowPanel, "Thickness", 10, 50, math.floor(S.wallThickness * 100), function(val)
		S.wallThickness = val / 100
	end)
	thicknessContainer.LayoutOrder = 3
	thicknessContainer.Visible = S.hollowEnabled

	panels["hollow"] = hollowPanel

	-- ========================================================================
	-- Spin Mode Panel
	-- ========================================================================
	local spinPanel = UIHelpers.createConfigPanel(deps.configContainer, "spin")

	local spinHeader = UIHelpers.createHeader(spinPanel, "Spin Mode", UDim2.new(0, 0, 0, 0))
	spinHeader.LayoutOrder = 1

	local spinGroup = UIComponents.createButtonGroup({
		parent = spinPanel,
		options = {
			{ id = SpinMode.Off, name = "Off" },
			{ id = SpinMode.Full3D, name = "3D" },
			{ id = SpinMode.XZ, name = "XZ" },
			{ id = SpinMode.Fast3D, name = "Fast 3D" },
			{ id = SpinMode.XZFast, name = "Fast XZ" },
		},
		initialValue = S.spinMode,
		onChange = function(newMode)
			S.spinMode = newMode
		end,
		layout = "grid",
		buttonSize = UDim2.new(0, 80, 0, 28),
	})
	spinGroup.container.LayoutOrder = 2

	panels["spin"] = spinPanel

	-- ========================================================================
	-- Plane Lock Panel
	-- ========================================================================
	local planeLockPanel = UIHelpers.createConfigPanel(deps.configContainer, "planeLock")

	local planeLockHeader = UIHelpers.createHeader(planeLockPanel, "Plane Lock", UDim2.new(0, 0, 0, 0))
	planeLockHeader.LayoutOrder = 1

	local manualControlsContainer = UIHelpers.createAutoContainer(planeLockPanel, "ManualControls")
	manualControlsContainer.LayoutOrder = 3
	manualControlsContainer.Visible = (S.planeLockMode == PlaneLockType.Manual)

	local planeLockGroup = UIComponents.createButtonGroup({
		parent = planeLockPanel,
		options = {
			{ id = PlaneLockType.Off, name = "Off" },
			{ id = PlaneLockType.Auto, name = "Auto" },
			{ id = PlaneLockType.Manual, name = "Manual" },
		},
		initialValue = S.planeLockMode,
		onChange = function(newMode)
			S.planeLockMode = newMode
			S.autoPlaneActive = false
			manualControlsContainer.Visible = (newMode == PlaneLockType.Manual)
			if newMode == PlaneLockType.Off then
				deps.hidePlaneVisualization()
			end
		end,
		layout = "horizontal",
	})
	planeLockGroup.container.LayoutOrder = 2

	local _, planeHeightContainer, setPlaneHeightValue = UIHelpers.createSlider(manualControlsContainer, "Height", -100, 500, S.planePositionY, function(value)
		S.planePositionY = value
	end)
	planeHeightContainer.LayoutOrder = 1

	local setHeightBtn = UIHelpers.createActionButton(manualControlsContainer, "Set from Cursor", function()
		local hitPosition = deps.getTerrainHitRaw()
		if hitPosition then
			S.planePositionY = math.floor(hitPosition.Y + 0.5)
			setPlaneHeightValue(S.planePositionY)
		end
	end)
	setHeightBtn.LayoutOrder = 2

	panels["planeLock"] = planeLockPanel

	-- ========================================================================
	-- Flatten Mode Panel
	-- ========================================================================
	local flattenModePanel = UIHelpers.createConfigPanel(deps.configContainer, "flattenMode")

	local flattenHeader = UIHelpers.createHeader(flattenModePanel, "Flatten Mode", UDim2.new(0, 0, 0, 0))
	flattenHeader.LayoutOrder = 1

	local flattenGroup = UIComponents.createButtonGroup({
		parent = flattenModePanel,
		options = {
			{ id = FlattenMode.Erode, name = "Erode" },
			{ id = FlattenMode.Both, name = "Both" },
			{ id = FlattenMode.Grow, name = "Grow" },
		},
		initialValue = S.flattenMode,
		onChange = function(newMode)
			S.flattenMode = newMode
		end,
		layout = "horizontal",
	})
	flattenGroup.container.LayoutOrder = 2

	panels["flattenMode"] = flattenModePanel

	return {
		panels = panels,
		setStrengthValue = setStrengthValue,
	}
end

return CorePanels

