--!strict
--[[
	ToolDocsPanel.lua - Displays rich documentation for the selected tool
	
	Shows title, description, sections, tips, and related tools.
	Updates when tool selection changes.
]]

local Theme = require(script.Parent.Parent.Parent.Util.Theme)
local UIHelpers = require(script.Parent.Parent.Parent.Util.UIHelpers)

local ToolDocsPanel = {}

export type ToolDocsPanelDeps = {
	parent: Frame,
	getToolDocs: (toolId: string) -> any?,  -- Returns ToolDocs or nil
}

export type ToolDocsPanelResult = {
	container: Frame,
	update: (toolId: string) -> (),
	setVisible: (visible: boolean) -> (),
}

function ToolDocsPanel.create(deps: ToolDocsPanelDeps): ToolDocsPanelResult
	-- Main container (transparent - parent handles background styling)
	local container = Instance.new("Frame")
	container.Name = "ToolDocsPanel"
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Size = UDim2.new(1, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.Visible = false
	container.Parent = deps.parent
	
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = container
	
	-- Content container (will be cleared and rebuilt on update)
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.BackgroundTransparency = 1
	contentFrame.Size = UDim2.new(1, 0, 0, 0)
	contentFrame.AutomaticSize = Enum.AutomaticSize.Y
	contentFrame.Parent = container
	
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 10)
	contentLayout.Parent = contentFrame
	
	-- Helper: Create a section heading
	local function createHeading(text: string, order: number): TextLabel
		local heading = Instance.new("TextLabel")
		heading.Name = "Heading"
		heading.BackgroundTransparency = 1
		heading.Size = UDim2.new(1, 0, 0, 20)
		heading.Font = Theme.Fonts.Bold
		heading.TextSize = 14
		heading.TextColor3 = Theme.Colors.Accent
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.Text = text
		heading.LayoutOrder = order
		heading.Parent = contentFrame
		return heading
	end
	
	-- Helper: Create paragraph text
	local function createParagraph(text: string, order: number): TextLabel
		local para = Instance.new("TextLabel")
		para.Name = "Paragraph"
		para.BackgroundTransparency = 1
		para.Size = UDim2.new(1, 0, 0, 0)
		para.AutomaticSize = Enum.AutomaticSize.Y
		para.Font = Theme.Fonts.Default
		para.TextSize = 13
		para.TextColor3 = Theme.Colors.Text
		para.TextXAlignment = Enum.TextXAlignment.Left
		para.TextWrapped = true
		para.Text = text
		para.LayoutOrder = order
		para.Parent = contentFrame
		return para
	end
	
	-- Helper: Create bullet list
	local function createBulletList(bullets: { string }, order: number): Frame
		local listFrame = Instance.new("Frame")
		listFrame.Name = "BulletList"
		listFrame.BackgroundTransparency = 1
		listFrame.Size = UDim2.new(1, 0, 0, 0)
		listFrame.AutomaticSize = Enum.AutomaticSize.Y
		listFrame.LayoutOrder = order
		listFrame.Parent = contentFrame
		
		local listLayout = Instance.new("UIListLayout")
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 3)
		listLayout.Parent = listFrame
		
		for i, bullet in ipairs(bullets) do
			local bulletFrame = Instance.new("Frame")
			bulletFrame.Name = "Bullet" .. i
			bulletFrame.BackgroundTransparency = 1
			bulletFrame.Size = UDim2.new(1, 0, 0, 0)
			bulletFrame.AutomaticSize = Enum.AutomaticSize.Y
			bulletFrame.LayoutOrder = i
			bulletFrame.Parent = listFrame
			
			local dot = Instance.new("TextLabel")
			dot.Name = "Dot"
			dot.BackgroundTransparency = 1
			dot.Position = UDim2.new(0, 0, 0, 0)
			dot.Size = UDim2.new(0, 14, 0, 16)
			dot.Font = Theme.Fonts.Default
			dot.TextSize = 13
			dot.TextColor3 = Theme.Colors.Accent
			dot.Text = "•"
			dot.Parent = bulletFrame
			
			-- Parse **bold** markers
			local displayText = bullet
			local textLabel = Instance.new("TextLabel")
			textLabel.Name = "Text"
			textLabel.BackgroundTransparency = 1
			textLabel.Position = UDim2.new(0, 14, 0, 0)
			textLabel.Size = UDim2.new(1, -14, 0, 0)
			textLabel.AutomaticSize = Enum.AutomaticSize.Y
			textLabel.Font = Theme.Fonts.Default
			textLabel.TextSize = 13
			textLabel.TextColor3 = Theme.Colors.Text
			textLabel.TextXAlignment = Enum.TextXAlignment.Left
			textLabel.TextWrapped = true
			textLabel.RichText = true
			
			-- Convert **text** to <b>text</b>
			displayText = displayText:gsub("%*%*(.-)%*%*", "<b>%1</b>")
			textLabel.Text = displayText
			textLabel.Parent = bulletFrame
		end
		
		return listFrame
	end
	
	-- Helper: Create quick tips box
	local function createQuickTips(tips: { string }, order: number): Frame
		local tipsFrame = Instance.new("Frame")
		tipsFrame.Name = "QuickTips"
		tipsFrame.BackgroundColor3 = Color3.fromRGB(50, 60, 70)
		tipsFrame.Size = UDim2.new(1, 0, 0, 0)
		tipsFrame.AutomaticSize = Enum.AutomaticSize.Y
		tipsFrame.LayoutOrder = order
		tipsFrame.Parent = contentFrame
		
		local tipCorner = Instance.new("UICorner")
		tipCorner.CornerRadius = UDim.new(0, 4)
		tipCorner.Parent = tipsFrame
		
		local tipPadding = Instance.new("UIPadding")
		tipPadding.PaddingLeft = UDim.new(0, 10)
		tipPadding.PaddingRight = UDim.new(0, 10)
		tipPadding.PaddingTop = UDim.new(0, 8)
		tipPadding.PaddingBottom = UDim.new(0, 8)
		tipPadding.Parent = tipsFrame
		
		local tipLayout = Instance.new("UIListLayout")
		tipLayout.SortOrder = Enum.SortOrder.LayoutOrder
		tipLayout.Padding = UDim.new(0, 4)
		tipLayout.Parent = tipsFrame
		
		local tipHeader = Instance.new("TextLabel")
		tipHeader.BackgroundTransparency = 1
		tipHeader.Size = UDim2.new(1, 0, 0, 16)
		tipHeader.Font = Theme.Fonts.Bold
		tipHeader.TextSize = 12
		tipHeader.TextColor3 = Theme.Colors.Warning
		tipHeader.TextXAlignment = Enum.TextXAlignment.Left
		tipHeader.Text = "⚡ SHORTCUTS"
		tipHeader.LayoutOrder = 0
		tipHeader.Parent = tipsFrame
		
		for i, tip in ipairs(tips) do
			local tipLabel = Instance.new("TextLabel")
			tipLabel.BackgroundTransparency = 1
			tipLabel.Size = UDim2.new(1, 0, 0, 0)
			tipLabel.AutomaticSize = Enum.AutomaticSize.Y
			tipLabel.Font = Theme.Fonts.Default
			tipLabel.TextSize = 13
			tipLabel.TextColor3 = Theme.Colors.Text
			tipLabel.TextXAlignment = Enum.TextXAlignment.Left
			tipLabel.TextWrapped = true
			tipLabel.Text = tip
			tipLabel.LayoutOrder = i
			tipLabel.Parent = tipsFrame
		end
		
		return tipsFrame
	end
	
	-- Helper: Create related tools
	local function createRelatedTools(related: { string }, order: number): Frame
		local relatedFrame = Instance.new("Frame")
		relatedFrame.Name = "RelatedTools"
		relatedFrame.BackgroundTransparency = 1
		relatedFrame.Size = UDim2.new(1, 0, 0, 26)
		relatedFrame.LayoutOrder = order
		relatedFrame.Parent = contentFrame
		
		local relatedLabel = Instance.new("TextLabel")
		relatedLabel.BackgroundTransparency = 1
		relatedLabel.Size = UDim2.new(0, 60, 1, 0)
		relatedLabel.Font = Theme.Fonts.Default
		relatedLabel.TextSize = 10
		relatedLabel.TextColor3 = Theme.Colors.TextDim
		relatedLabel.TextXAlignment = Enum.TextXAlignment.Left
		relatedLabel.Text = "Related:"
		relatedLabel.Parent = relatedFrame
		
		local tagsFrame = Instance.new("Frame")
		tagsFrame.BackgroundTransparency = 1
		tagsFrame.Position = UDim2.new(0, 55, 0, 0)
		tagsFrame.Size = UDim2.new(1, -55, 1, 0)
		tagsFrame.Parent = relatedFrame
		
		local tagsLayout = Instance.new("UIListLayout")
		tagsLayout.FillDirection = Enum.FillDirection.Horizontal
		tagsLayout.Padding = UDim.new(0, 4)
		tagsLayout.Parent = tagsFrame
		
		for i, toolName in ipairs(related) do
			local tag = Instance.new("TextLabel")
			tag.BackgroundColor3 = Theme.Colors.ButtonDefault
			tag.Size = UDim2.new(0, 0, 0, 18)
			tag.AutomaticSize = Enum.AutomaticSize.X
			tag.Font = Theme.Fonts.Medium
			tag.TextSize = 10
			tag.TextColor3 = Theme.Colors.Text
			tag.Text = "  " .. toolName .. "  "
			tag.LayoutOrder = i
			tag.Parent = tagsFrame
			
			local tagCorner = Instance.new("UICorner")
			tagCorner.CornerRadius = UDim.new(0, 3)
			tagCorner.Parent = tag
		end
		
		return relatedFrame
	end
	
	-- Clear all content
	local function clearContent()
		for _, child in ipairs(contentFrame:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end
	
	-- Update the panel with tool documentation
	local function update(toolId: string)
		clearContent()
		
		local docs = deps.getToolDocs(toolId)
		if not docs then
			-- No tool selected or no docs
			container.Visible = false
			return
		end
		
		container.Visible = true
		local order = 0
		
		-- Title
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 22)
		title.Font = Theme.Fonts.Bold
		title.TextSize = 16
		title.TextColor3 = Theme.Colors.Text
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = docs.title
		title.LayoutOrder = order
		title.Parent = contentFrame
		order = order + 1
		
		-- Subtitle
		if docs.subtitle then
			local subtitle = Instance.new("TextLabel")
			subtitle.Name = "Subtitle"
			subtitle.BackgroundTransparency = 1
			subtitle.Size = UDim2.new(1, 0, 0, 16)
			subtitle.Font = Theme.Fonts.Medium
			subtitle.TextSize = 13
			subtitle.TextColor3 = Theme.Colors.Accent
			subtitle.TextXAlignment = Enum.TextXAlignment.Left
			subtitle.Text = docs.subtitle
			subtitle.LayoutOrder = order
			subtitle.Parent = contentFrame
			order = order + 1
		end
		
		-- Description
		if docs.description then
			-- Trim whitespace from multiline strings
			local desc = docs.description:gsub("^%s+", ""):gsub("%s+$", "")
			createParagraph(desc, order)
			order = order + 1
		end
		
		-- Sections
		if docs.sections then
			for _, section in ipairs(docs.sections) do
				createHeading(section.heading, order)
				order = order + 1
				
				if section.content then
					createParagraph(section.content, order)
					order = order + 1
				end
				
				if section.bullets then
					createBulletList(section.bullets, order)
					order = order + 1
				end
			end
		end
		
		-- Quick tips
		if docs.quickTips and #docs.quickTips > 0 then
			createQuickTips(docs.quickTips, order)
			order = order + 1
		end
		
		-- Related tools
		if docs.related and #docs.related > 0 then
			createRelatedTools(docs.related, order)
			order = order + 1
		end
	end
	
	local function setVisible(visible: boolean)
		container.Visible = visible
	end
	
	return {
		container = container,
		update = update,
		setVisible = setVisible,
	}
end

return ToolDocsPanel

