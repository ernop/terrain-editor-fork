--!strict
--[[
	ToolRegistry.lua - Central registry for all terrain tools
	
	Discovers, validates, and provides access to tool definitions.
	Each tool is a self-contained module with documentation.
]]

local ToolDocFormat = require(script.Parent.ToolDocFormat)

local ToolRegistry = {}

-- Storage
local tools: { [string]: ToolDocFormat.Tool } = {}
local toolsByCategory: { [string]: { ToolDocFormat.Tool } } = {}
local initialized = false

-- Load all tools from category folders
function ToolRegistry.init(toolsFolder: Folder)
	if initialized then
		return
	end

	-- Clear existing data
	tools = {}
	toolsByCategory = {}

	-- Scan category folders
	for _, categoryFolder in ipairs(toolsFolder:GetChildren()) do
		if categoryFolder:IsA("Folder") then
			local categoryName = categoryFolder.Name
			toolsByCategory[categoryName] = {}

			-- Load each tool module in this category
			for _, toolModule in ipairs(categoryFolder:GetChildren()) do
				if toolModule:IsA("ModuleScript") then
					local success, toolDef = pcall(function()
						return require(toolModule)
					end)

					if success and toolDef then
						-- Validate the tool
						local isValid, errMsg = ToolDocFormat.validate(toolDef)
						if isValid then
							tools[toolDef.id] = toolDef
							table.insert(toolsByCategory[categoryName], toolDef)
							-- print("[ToolRegistry] Loaded tool:", toolDef.id)
						else
							warn("[ToolRegistry] Invalid tool in", toolModule:GetFullName(), "-", errMsg)
						end
					else
						warn("[ToolRegistry] Failed to load tool module:", toolModule:GetFullName())
					end
				end
			end
		end
	end

	initialized = true
	print("[ToolRegistry] Loaded", ToolRegistry.getToolCount(), "tools")
end

-- Get a tool by ID
function ToolRegistry.getTool(toolId: string): ToolDocFormat.Tool?
	return tools[toolId]
end

-- Get documentation for a tool
function ToolRegistry.getDocs(toolId: string): ToolDocFormat.ToolDocs?
	local tool = tools[toolId]
	return tool and tool.docs or nil
end

-- Get config panels for a tool
function ToolRegistry.getConfigPanels(toolId: string): { string }?
	local tool = tools[toolId]
	return tool and tool.configPanels or nil
end

-- Get the execute function for a tool
function ToolRegistry.getExecute(toolId: string): ((ToolDocFormat.SculptSettings) -> ())?
	local tool = tools[toolId]
	return tool and tool.execute or nil
end

-- Get all tools as a dictionary
function ToolRegistry.getAllTools(): { [string]: ToolDocFormat.Tool }
	return tools
end

-- Get tools organized by category
function ToolRegistry.getToolsByCategory(): { [string]: { ToolDocFormat.Tool } }
	return toolsByCategory
end

-- Get tool count
function ToolRegistry.getToolCount(): number
	local count = 0
	for _ in pairs(tools) do
		count = count + 1
	end
	return count
end

-- Check if a tool exists
function ToolRegistry.hasTool(toolId: string): boolean
	return tools[toolId] ~= nil
end

-- Get all tool IDs
function ToolRegistry.getToolIds(): { string }
	local ids = {}
	for id in pairs(tools) do
		table.insert(ids, id)
	end
	return ids
end

return ToolRegistry
