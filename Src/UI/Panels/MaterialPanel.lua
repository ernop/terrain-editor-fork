--!strict
-- MaterialPanel.lua - Material selection panel with 22-tile grid
-- Used by: Paint, Add, Bridge, and other tools that need material selection

local Theme = require(script.Parent.Parent.Parent.Util.Theme)
local UIHelpers = require(script.Parent.Parent.Parent.Util.UIHelpers)
local UIComponents = require(script.Parent.Parent.Parent.Util.UIComponents)

local MaterialPanel = {}

-- Consistent label width for alignment across all panels
local LABEL_WIDTH = 80

export type MaterialPanelDeps = {
	configContainer: Frame,
	S: any, -- State table with brushMaterial, autoMaterial
}

export type MaterialPanelResult = {
	panels: { [string]: Frame },
	updateMaterial: (material: Enum.Material) -> (),
}

function MaterialPanel.create(deps: MaterialPanelDeps): MaterialPanelResult
	local panels: { [string]: Frame } = {}
	local S = deps.S

	-- ========================================================================
	-- Auto Material Panel - toggle to sample from existing terrain
	-- ========================================================================
	local autoMatPanel = UIHelpers.createConfigPanel(deps.configContainer, "autoMaterial")

	local materialPickerRef: any = nil -- Forward reference for enabling/disabling

	local autoMatToggle = UIComponents.createLabeledToggle({
		parent = autoMatPanel,
		labelText = "Auto",
		initialState = S.autoMaterial,
		textOn = "Match Terrain",
		textOff = "Use Selected",
		onToggle = function(isAuto)
			S.autoMaterial = isAuto
			-- Dim the material picker when auto is enabled
			if materialPickerRef and materialPickerRef.container then
				materialPickerRef.container.GroupTransparency = isAuto and 0.5 or 0
			end
		end,
		labelWidth = LABEL_WIDTH,
	})
	autoMatToggle.container.LayoutOrder = 1

	panels["autoMaterial"] = autoMatPanel

	-- ========================================================================
	-- Material Panel - grid of 22 terrain materials
	-- ========================================================================
	local materialPanel = UIHelpers.createConfigPanel(deps.configContainer, "material")

	local header = UIHelpers.createHeader(materialPanel, "Material", UDim2.new(0, 0, 0, 0))
	header.LayoutOrder = 1

	local picker = UIComponents.createMaterialPicker({
		parent = materialPanel,
		initialMaterial = S.brushMaterial,
		onSelect = function(mat)
			S.brushMaterial = mat
		end,
	})
	picker.container.LayoutOrder = 2
	materialPickerRef = picker

	-- Apply initial dim state if auto material is already enabled
	if S.autoMaterial then
		picker.container.GroupTransparency = 0.5
	end

	panels["material"] = materialPanel

	return {
		panels = panels,
		updateMaterial = picker.update,
	}
end

return MaterialPanel

