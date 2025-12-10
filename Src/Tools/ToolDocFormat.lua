--!strict
--[[
	ToolDocFormat.lua - Type definitions for tool documentation
	
	Every tool MUST have a docs table following this format.
	This ensures consistent, rich documentation across all tools.
]]

local ToolDocFormat = {}

--[[
	DocSection: A section within the documentation
	
	Example:
	{
		heading = "How to Use",
		content = "Click and drag to paint terrain...",
		image = "rbxassetid://123456",  -- optional
		bullets = { "Point 1", "Point 2" },  -- optional, use instead of content
	}
]]
export type DocSection = {
	heading: string,
	content: string?,
	image: string?,
	bullets: { string }?,
}

--[[
	Shortcut: A keyboard shortcut for the tool
	
	Example:
	{ key = "R", action = "Lock brush position" }
]]
export type Shortcut = {
	key: string,
	action: string,
}

--[[
	ToolDocs: Complete documentation for a tool
	
	Required fields:
	- title: Display name
	- description: What the tool does (1-3 sentences)
	
	Optional fields:
	- subtitle: Short tagline
	- sections: Detailed documentation sections
	- quickTips: Short tips shown in sidebar
	- shortcuts: Keyboard shortcuts
	- related: IDs of related tools
]]
export type ToolDocs = {
	-- Required
	title: string,
	description: string,
	
	-- Optional
	subtitle: string?,
	sections: { DocSection }?,
	quickTips: { string }?,
	shortcuts: { Shortcut }?,
	related: { string }?,
	docVersion: string?,
}

--[[
	SculptSettings: The settings passed to tool execute functions
	Contains voxel data, brush parameters, and operation state
]]
export type SculptSettings = {
	-- Voxel position
	x: number,
	y: number,
	z: number,
	
	-- Voxel data (read-only)
	readMaterials: {{{Enum.Material}}},
	readOccupancies: {{{number}}},
	
	-- Voxel data (write)
	writeMaterials: {{{Enum.Material}}},
	writeOccupancies: {{{number}}},
	
	-- Region dimensions
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	
	-- Brush parameters
	brushOccupancy: number,
	magnitudePercent: number,
	cellOccupancy: number,
	cellMaterial: Enum.Material,
	strength: number,
	
	-- Material settings
	desiredMaterial: Enum.Material?,
	autoMaterial: boolean?,
	airFillerMaterial: Enum.Material?,
	ignoreWater: boolean?,
	
	-- Constraint
	maxOccupancy: number?,
	filterSize: number?,
	
	-- World coordinates (for noise-based tools)
	worldX: number?,
	worldY: number?,
	worldZ: number?,
	centerX: number?,
	centerY: number?,
	centerZ: number?,
	
	-- Tool-specific parameters (added by each tool)
	[string]: any,
}

--[[
	OperationSet: The full operation configuration passed from the UI
]]
export type OperationSet = {
	currentTool: string,
	brushShape: string,
	flattenMode: string?,
	pivot: string,
	centerPoint: Vector3,
	planePoint: Vector3,
	planeNormal: Vector3,
	cursorSizeX: number,
	cursorSizeY: number,
	cursorSizeZ: number,
	cursorSize: number,
	cursorHeight: number,
	strength: number,
	autoMaterial: boolean,
	material: Enum.Material,
	ignoreWater: boolean,
	brushRotation: CFrame?,
	hollowEnabled: boolean?,
	wallThickness: number?,
	[string]: any,
}

--[[
	Tool: Complete tool definition
	
	Every tool module must export a table matching this type.
]]
export type Tool = {
	-- Identity (required)
	id: string,
	name: string,
	category: string,
	
	-- Documentation (required)
	docs: ToolDocs,
	
	-- Configuration (required)
	configPanels: { string },
	
	-- Operation (required) - called for each voxel
	execute: (settings: SculptSettings) -> (),
	
	-- Optional hooks
	setup: ((opSet: OperationSet) -> OperationSet)?,
	canUseFastPath: ((opSet: OperationSet) -> boolean)?,
	fastPath: ((terrain: Terrain, opSet: OperationSet) -> ())?,
	
	-- Optional UI customization
	icon: string?,
	buttonLabel: string?,
}

-- Validation function to check if a tool has proper documentation
function ToolDocFormat.validate(tool: any): (boolean, string?)
	if type(tool) ~= "table" then
		return false, "Tool must be a table"
	end
	
	if not tool.id or type(tool.id) ~= "string" then
		return false, "Tool must have a string 'id'"
	end
	
	if not tool.name or type(tool.name) ~= "string" then
		return false, "Tool must have a string 'name'"
	end
	
	if not tool.docs then
		return false, "Tool must have 'docs' (documentation is mandatory)"
	end
	
	if not tool.docs.title or type(tool.docs.title) ~= "string" then
		return false, "Tool docs must have a 'title'"
	end
	
	if not tool.docs.description or type(tool.docs.description) ~= "string" then
		return false, "Tool docs must have a 'description'"
	end
	
	if not tool.configPanels or type(tool.configPanels) ~= "table" then
		return false, "Tool must have 'configPanels' array"
	end
	
	if not tool.execute or type(tool.execute) ~= "function" then
		return false, "Tool must have an 'execute' function"
	end
	
	return true, nil
end

return ToolDocFormat

