--!strict

-- Config Panels UI Component
-- Creates and manages configuration panels for tools
-- Note: This is a placeholder structure. Full extraction would require significant refactoring
-- due to tight coupling with state and other functions in the main module.

local UIHelpers = require(script.Parent.Parent.Util.UIHelpers)
local BrushData = require(script.Parent.Parent.Util.BrushData)

local ConfigPanels = {}

export type ConfigPanels = {
	updateVisibility: (currentTool: string) -> (),
	getPanels: () -> { [string]: Frame },
}

function ConfigPanels.create(
	parent: Frame,
	-- This would need access to state and callbacks, which is why full extraction is complex
	onUpdate: ((panelName: string) -> ())?
): ConfigPanels
	local configPanels: { [string]: Frame } = {}

	-- This is a placeholder - the actual implementation would need to create all panels
	-- and manage their visibility based on tool selection

	local function updateVisibility(currentTool: string)
		local toolConfig = BrushData.ToolConfigs[currentTool]
		for _, panel in pairs(configPanels) do
			panel.Visible = false
		end
		if toolConfig then
			for _, panelName in ipairs(toolConfig) do
				if configPanels[panelName] then
					configPanels[panelName].Visible = true
				end
			end
		end
	end

	return {
		updateVisibility = updateVisibility,
		getPanels = function()
			return configPanels
		end,
	}
end

return ConfigPanels

