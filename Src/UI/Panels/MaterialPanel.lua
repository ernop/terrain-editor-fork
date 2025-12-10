--!strict
-- MaterialPanel.lua - Material selection panel with 22-tile grid
-- Used by: Paint, Add, Bridge, and other tools that need material selection

local Theme = require(script.Parent.Parent.Parent.Util.Theme)
local UIHelpers = require(script.Parent.Parent.Parent.Util.UIHelpers)
local UIComponents = require(script.Parent.Parent.Parent.Util.UIComponents)

local MaterialPanel = {}

export type MaterialPanelDeps = {
	configContainer: Frame,
	S: any, -- State table with brushMaterial
}

export type MaterialPanelResult = {
	panels: { [string]: Frame },
	updateMaterial: (material: Enum.Material) -> (),
}

function MaterialPanel.create(deps: MaterialPanelDeps): MaterialPanelResult
	local panels: { [string]: Frame } = {}
	local S = deps.S

	-- Material Panel
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

	panels["material"] = materialPanel

	return {
		panels = panels,
		updateMaterial = picker.update,
	}
end

return MaterialPanel

