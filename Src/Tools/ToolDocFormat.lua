--!strict
--[[
	ToolDocFormat.lua - Type definitions for tool documentation and traits
	
	Every tool MUST have:
	- docs table (documentation)
	- traits table (behavior classification)
	- execute function (per-voxel operation)
	- configPanels array (UI panels)
	
	This ensures consistent, well-documented tools across the system.
]]

local ToolDocFormat = {}

-- ============================================================================
-- TOOL CATEGORIES
-- ============================================================================
-- Primary function of the tool
ToolDocFormat.Category = {
	Shape = "Shape",         -- Modify terrain volume (Add, Subtract, Grow, Erode, Smooth, Flatten)
	Surface = "Surface",     -- Reshape surface (Noise, Terrace, Cliff, Path, Blobify)
	Material = "Material",   -- Change material only (Paint, SlopePaint, Gradient, Flood, etc.)
	Generator = "Generator", -- Create procedural shapes (Stalactite, Tendril, Growth, Grid)
	Utility = "Utility",     -- Special operations (Clone, Bridge, Symmetry, Melt)
	Analysis = "Analysis",   -- Read-only inspection (VoxelInspect, ComponentAnalyzer, Overlay)
}

-- ============================================================================
-- EXECUTION TYPES
-- ============================================================================
-- How the tool processes terrain
ToolDocFormat.ExecutionType = {
	PerVoxel = "perVoxel",       -- Iterates over each voxel in brush region
	ColumnBased = "columnBased", -- Processes columns (Flatten)
	PointToPoint = "pointToPoint", -- Connects two points (Bridge)
	UIOnly = "uiOnly",           -- No terrain modification (Analysis tools)
}

-- ============================================================================
-- TOOL TRAITS TYPE
-- ============================================================================
--[[
	ToolTraits: Behavioral classification for routing and UI decisions
	
	Example:
	{
		category = "Shape",
		executionType = "perVoxel",
		modifiesOccupancy = true,
		modifiesMaterial = true,
		hasFastPath = true,
		hasLargeBrushPath = false,
		requiresGlobalState = false,
		usesBrush = true,
		usesStrength = true,
		needsMaterial = true,
	}
]]
export type ToolTraits = {
	-- Classification
	category: string,       -- Category.Shape | Surface | Material | Generator | Utility | Analysis
	executionType: string,  -- ExecutionType.PerVoxel | ColumnBased | PointToPoint | UIOnly
	
	-- Modification flags
	modifiesOccupancy: boolean,  -- Changes terrain volume
	modifiesMaterial: boolean,   -- Changes terrain material
	
	-- Execution paths
	hasFastPath: boolean?,       -- Can use native Terrain API shortcuts
	hasLargeBrushPath: boolean?, -- Has optimized path for large brushes
	
	-- State requirements
	requiresGlobalState: boolean?, -- Needs persistent state (buffer, points)
	globalStateKeys: { string }?,  -- Which state keys it uses
	
	-- UI requirements
	usesBrush: boolean?,      -- Shows brush visualization
	usesStrength: boolean?,   -- Strength slider affects operation
	needsMaterial: boolean?,  -- Requires material selection
}

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
	
	-- Traits (required) - behavioral classification
	traits: ToolTraits,
	
	-- Documentation (required)
	docs: ToolDocs,
	
	-- Configuration (required)
	configPanels: { string },
	
	-- Operation (required for non-UIOnly tools) - called for each voxel
	execute: ((settings: SculptSettings) -> ())?,
	
	-- Optional hooks
	setup: ((opSet: OperationSet) -> OperationSet)?,
	canUseFastPath: ((opSet: OperationSet) -> boolean)?,
	fastPath: ((terrain: Terrain, opSet: OperationSet) -> ())?,
	
	-- Optional UI customization
	icon: string?,
	buttonLabel: string?,
}

-- Validation function to check if a tool has proper documentation and traits
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
	
	-- Validate traits (required)
	if not tool.traits then
		return false, "Tool must have 'traits' (behavioral classification)"
	end
	
	if not tool.traits.category or type(tool.traits.category) ~= "string" then
		return false, "Tool traits must have a 'category'"
	end
	
	if not tool.traits.executionType or type(tool.traits.executionType) ~= "string" then
		return false, "Tool traits must have an 'executionType'"
	end
	
	-- Execute function required for non-UIOnly tools
	local isUIOnly = tool.traits.executionType == ToolDocFormat.ExecutionType.UIOnly
	if not isUIOnly and (not tool.execute or type(tool.execute) ~= "function") then
		return false, "Non-UIOnly tool must have an 'execute' function"
	end
	
	return true, nil
end

-- Helper to create default traits for a tool category
function ToolDocFormat.createTraits(category: string, overrides: ToolTraits?): ToolTraits
	local defaults = {
		Shape = {
			category = "Shape",
			executionType = "perVoxel",
			modifiesOccupancy = true,
			modifiesMaterial = true,
			usesBrush = true,
			usesStrength = true,
			needsMaterial = true,
		},
		Surface = {
			category = "Surface",
			executionType = "perVoxel",
			modifiesOccupancy = true,
			modifiesMaterial = false,
			usesBrush = true,
			usesStrength = true,
			needsMaterial = false,
		},
		Material = {
			category = "Material",
			executionType = "perVoxel",
			modifiesOccupancy = false,
			modifiesMaterial = true,
			usesBrush = true,
			usesStrength = true,
			needsMaterial = true,
		},
		Generator = {
			category = "Generator",
			executionType = "perVoxel",
			modifiesOccupancy = true,
			modifiesMaterial = true,
			usesBrush = true,
			usesStrength = true,
			needsMaterial = true,
		},
		Utility = {
			category = "Utility",
			executionType = "perVoxel",
			modifiesOccupancy = true,
			modifiesMaterial = true,
			usesBrush = true,
			usesStrength = true,
			needsMaterial = false,
		},
		Analysis = {
			category = "Analysis",
			executionType = "uiOnly",
			modifiesOccupancy = false,
			modifiesMaterial = false,
			usesBrush = false,
			usesStrength = false,
			needsMaterial = false,
		},
	}
	
	local base = defaults[category] or defaults.Utility
	
	if overrides then
		for key, value in pairs(overrides) do
			base[key] = value
		end
	end
	
	return base
end

return ToolDocFormat

