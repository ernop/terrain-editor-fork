--!strict

-- Tool Registry
-- Centralized tool definitions for declarative tool registration
-- Makes adding new tools easier by defining metadata in one place

local TerrainEnums = require(script.Parent.TerrainEnums)
local ToolId = TerrainEnums.ToolId
local BrushData = require(script.Parent.BrushData)

local ToolRegistry = {}

export type ToolDefinition = {
	id: string,
	name: string,
	row: number,
	col: number,
	configPanels: { string },
	description: string?,
}

-- Tool definitions with their UI positions and configuration panels
local TOOL_DEFINITIONS: { ToolDefinition } = {
	{
		id = ToolId.Add,
		name = "Add",
		row = 0,
		col = 0,
		configPanels = BrushData.ToolConfigs[ToolId.Add] or {},
		description = "Adds terrain material",
	},
	{
		id = ToolId.Subtract,
		name = "Subtract",
		row = 0,
		col = 1,
		configPanels = BrushData.ToolConfigs[ToolId.Subtract] or {},
		description = "Removes terrain",
	},
	{
		id = ToolId.Grow,
		name = "Grow",
		row = 0,
		col = 2,
		configPanels = BrushData.ToolConfigs[ToolId.Grow] or {},
		description = "Grows existing terrain",
	},
	{
		id = ToolId.Erode,
		name = "Erode",
		row = 1,
		col = 0,
		configPanels = BrushData.ToolConfigs[ToolId.Erode] or {},
		description = "Erodes terrain",
	},
	{
		id = ToolId.Smooth,
		name = "Smooth",
		row = 1,
		col = 1,
		configPanels = BrushData.ToolConfigs[ToolId.Smooth] or {},
		description = "Smooths terrain surface",
	},
	{
		id = ToolId.Flatten,
		name = "Flatten",
		row = 1,
		col = 2,
		configPanels = BrushData.ToolConfigs[ToolId.Flatten] or {},
		description = "Flattens terrain to a plane",
	},
	{
		id = ToolId.Noise,
		name = "Noise",
		row = 2,
		col = 0,
		configPanels = BrushData.ToolConfigs[ToolId.Noise] or {},
		description = "Adds procedural noise",
	},
	{
		id = ToolId.Terrace,
		name = "Terrace",
		row = 2,
		col = 1,
		configPanels = BrushData.ToolConfigs[ToolId.Terrace] or {},
		description = "Creates stepped terraces",
	},
	{
		id = ToolId.Cliff,
		name = "Cliff",
		row = 2,
		col = 2,
		configPanels = BrushData.ToolConfigs[ToolId.Cliff] or {},
		description = "Creates cliff faces",
	},
	{
		id = ToolId.Path,
		name = "Path",
		row = 3,
		col = 0,
		configPanels = BrushData.ToolConfigs[ToolId.Path] or {},
		description = "Carves a path/channel",
	},
	{
		id = ToolId.Clone,
		name = "Clone",
		row = 3,
		col = 1,
		configPanels = BrushData.ToolConfigs[ToolId.Clone] or {},
		description = "Copies terrain from one location to another",
	},
	{
		id = ToolId.Blobify,
		name = "Blobify",
		row = 3,
		col = 2,
		configPanels = BrushData.ToolConfigs[ToolId.Blobify] or {},
		description = "Creates organic blob shapes",
	},
	{
		id = ToolId.Paint,
		name = "Paint",
		row = 3,
		col = 3,
		configPanels = BrushData.ToolConfigs[ToolId.Paint] or {},
		description = "Changes terrain material",
	},
	{
		id = ToolId.Bridge,
		name = "Bridge",
		row = 4,
		col = 0,
		configPanels = BrushData.ToolConfigs[ToolId.Bridge] or {},
		description = "Creates bridge terrain between two points",
	},
}

function ToolRegistry.getAllTools(): { ToolDefinition }
	return TOOL_DEFINITIONS
end

function ToolRegistry.getTool(toolId: string): ToolDefinition?
	for _, tool in ipairs(TOOL_DEFINITIONS) do
		if tool.id == toolId then
			return tool
		end
	end
	return nil
end

function ToolRegistry.getToolConfigPanels(toolId: string): { string }
	local tool = ToolRegistry.getTool(toolId)
	if tool then
		return tool.configPanels
	end
	return {}
end

return ToolRegistry

