--!strict

-- Tool Selector UI Component
-- Creates and manages tool selection buttons

local UIHelpers = require(script.Parent.Parent.Util.UIHelpers)
local TerrainEnums = require(script.Parent.Parent.Util.TerrainEnums)
local ToolId = TerrainEnums.ToolId

local ToolSelector = {}

export type ToolSelector = {
	updateVisuals: (currentTool: string) -> (),
	getButtons: () -> { [string]: TextButton },
}

function ToolSelector.create(
	parent: Frame,
	toolButtonData: { { id: string, name: string, row: number, col: number } },
	onToolSelected: (toolId: string) -> ()
): ToolSelector
	local toolButtons: { [string]: TextButton } = {}

	for _, toolInfo in ipairs(toolButtonData) do
		local pos = UDim2.new(0, toolInfo.col * 78, 0, 60 + toolInfo.row * 38)
		local btn = UIHelpers.createToolButton(parent, toolInfo.id, toolInfo.name, pos)
		toolButtons[toolInfo.id] = btn
		btn.MouseButton1Click:Connect(function()
			onToolSelected(toolInfo.id)
		end)
	end

	local function updateVisuals(currentTool: string)
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

	return {
		updateVisuals = updateVisuals,
		getButtons = function()
			return toolButtons
		end,
	}
end

return ToolSelector

