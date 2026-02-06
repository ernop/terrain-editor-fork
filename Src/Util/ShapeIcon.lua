--!strict
--[[
	ShapeIcon.lua - Visual GUI-based icons for brush shapes

	Creates Frame-based icons representing each of the 15 brush shapes.
	Used in the shape selector buttons in CorePanels.
]]

local Theme = require(script.Parent.Theme)
local TerrainEnums = require(script.Parent.TerrainEnums)
local BrushShape = TerrainEnums.BrushShape

local ShapeIcon = {}

-- Shape icon size constants
local SHAPE_ICON_SIZE = 24
local SHAPE_ICON_COLOR = Theme.Colors.ShapeIconLight
local SHAPE_ICON_COLOR_DIM = Theme.Colors.ShapeIconDim

-- Helper: Create a simple colored frame element
local function createIconElement(parent: Frame, props: {
	position: UDim2?,
	size: UDim2,
	color: Color3?,
	cornerRadius: number?,
	rotation: number?,
}): Frame
	local element = Instance.new("Frame")
	element.BackgroundColor3 = props.color or SHAPE_ICON_COLOR
	element.BorderSizePixel = 0
	element.Position = props.position or UDim2.new(0, 0, 0, 0)
	element.Size = props.size
	element.AnchorPoint = Vector2.new(0.5, 0.5)
	element.Rotation = props.rotation or 0
	element.Parent = parent

	if props.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, props.cornerRadius)
		corner.Parent = element
	end

	return element
end

--[[
	Creates a visual icon for a brush shape using GUI elements.
	Returns a Frame containing the shape icon.
]]
function ShapeIcon.create(shapeId: string, size: number?): Frame
	local iconSize = size or SHAPE_ICON_SIZE
	local container = Instance.new("Frame")
	container.Name = "ShapeIcon"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(0, iconSize, 0, iconSize)

	local s = iconSize -- shorthand

	if shapeId == BrushShape.Sphere then
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.85),
			cornerRadius = s,
		})

	elseif shapeId == BrushShape.Cube then
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.75, 0, s * 0.75),
			cornerRadius = 2,
		})

	elseif shapeId == BrushShape.Cylinder then
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.55, 0, s * 0.85),
			cornerRadius = s * 0.27,
		})

	elseif shapeId == BrushShape.Wedge then
		local triangleContainer = Instance.new("Frame")
		triangleContainer.BackgroundTransparency = 1
		triangleContainer.Size = UDim2.new(1, 0, 1, 0)
		triangleContainer.ClipsDescendants = true
		triangleContainer.Parent = container

		createIconElement(triangleContainer, {
			position = UDim2.new(0.7, 0, 0.7, 0),
			size = UDim2.new(0, s * 0.9, 0, s * 0.9),
			rotation = 45,
			cornerRadius = 2,
		})

	elseif shapeId == BrushShape.CornerWedge then
		local triangleContainer = Instance.new("Frame")
		triangleContainer.BackgroundTransparency = 1
		triangleContainer.Size = UDim2.new(1, 0, 1, 0)
		triangleContainer.ClipsDescendants = true
		triangleContainer.Parent = container

		createIconElement(triangleContainer, {
			position = UDim2.new(0.75, 0, 0.75, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.85),
			rotation = 45,
			cornerRadius = 2,
		})

	elseif shapeId == BrushShape.Dome then
		local domeClip = Instance.new("Frame")
		domeClip.BackgroundTransparency = 1
		domeClip.Position = UDim2.new(0, 0, 0, 0)
		domeClip.Size = UDim2.new(1, 0, 0.55, 0)
		domeClip.ClipsDescendants = true
		domeClip.Parent = container

		createIconElement(domeClip, {
			position = UDim2.new(0.5, 0, 1, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.85),
			cornerRadius = s,
		})

	elseif shapeId == BrushShape.RotatedDome then
		local archOuter = createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.42, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.85),
			cornerRadius = s,
		})

		local innerCut = Instance.new("Frame")
		innerCut.BackgroundColor3 = Theme.Colors.ShapeIconHole
		innerCut.BorderSizePixel = 0
		innerCut.Position = UDim2.new(0.5, 0, 0.6, 0)
		innerCut.Size = UDim2.new(0, s * 0.5, 0, s * 0.5)
		innerCut.AnchorPoint = Vector2.new(0.5, 0.5)
		innerCut.Parent = archOuter

		local innerCorner = Instance.new("UICorner")
		innerCorner.CornerRadius = UDim.new(1, 0)
		innerCorner.Parent = innerCut

		createIconElement(container, {
			position = UDim2.new(0.22, 0, 0.75, 0),
			size = UDim2.new(0, s * 0.17, 0, s * 0.4),
		})
		createIconElement(container, {
			position = UDim2.new(0.78, 0, 0.75, 0),
			size = UDim2.new(0, s * 0.17, 0, s * 0.4),
		})

	elseif shapeId == BrushShape.Torus then
		local outerRing = createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.85),
			cornerRadius = s,
		})

		local innerHole = Instance.new("Frame")
		innerHole.BackgroundColor3 = Theme.Colors.ShapeIconHole
		innerHole.BorderSizePixel = 0
		innerHole.Position = UDim2.new(0.5, 0, 0.5, 0)
		innerHole.Size = UDim2.new(0, s * 0.4, 0, s * 0.4)
		innerHole.AnchorPoint = Vector2.new(0.5, 0.5)
		innerHole.Parent = outerRing

		local holeCorner = Instance.new("UICorner")
		holeCorner.CornerRadius = UDim.new(1, 0)
		holeCorner.Parent = innerHole

	elseif shapeId == BrushShape.Ring then
		local outerRing = createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.9, 0, s * 0.45),
			cornerRadius = s,
		})

		local innerHole = Instance.new("Frame")
		innerHole.BackgroundColor3 = Theme.Colors.ShapeIconHole
		innerHole.BorderSizePixel = 0
		innerHole.Position = UDim2.new(0.5, 0, 0.5, 0)
		innerHole.Size = UDim2.new(0, s * 0.45, 0, s * 0.22)
		innerHole.AnchorPoint = Vector2.new(0.5, 0.5)
		innerHole.Parent = outerRing

		local holeCorner = Instance.new("UICorner")
		holeCorner.CornerRadius = UDim.new(1, 0)
		holeCorner.Parent = innerHole

	elseif shapeId == BrushShape.ZigZag then
		local barW = s * 0.65
		local barH = s * 0.18
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.22, 0),
			size = UDim2.new(0, barW, 0, barH),
			cornerRadius = 2,
		})
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, barW * 0.8, 0, barH),
			rotation = -55,
			cornerRadius = 2,
		})
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.78, 0),
			size = UDim2.new(0, barW, 0, barH),
			cornerRadius = 2,
		})

	elseif shapeId == BrushShape.Sheet then
		local arcRadius = s * 0.35
		local dotSize = s * 0.12
		for i = 0, 6 do
			local angle = math.rad(180 + i * 25)
			local x = 0.5 + math.cos(angle) * (arcRadius / s)
			local y = 0.55 + math.sin(angle) * (arcRadius / s)
			createIconElement(container, {
				position = UDim2.new(x, 0, y, 0),
				size = UDim2.new(0, dotSize, 0, dotSize),
				cornerRadius = dotSize,
			})
		end

	elseif shapeId == BrushShape.Grid then
		local cellSize = s * 0.35
		local gap = s * 0.08
		local offset = (s - 2 * cellSize - gap) / 2

		createIconElement(container, {
			position = UDim2.new(0, offset + cellSize/2, 0, offset + cellSize/2),
			size = UDim2.new(0, cellSize, 0, cellSize),
			cornerRadius = 2,
		})
		createIconElement(container, {
			position = UDim2.new(0, offset + cellSize + gap + cellSize/2, 0, offset + cellSize/2),
			size = UDim2.new(0, cellSize, 0, cellSize),
			color = SHAPE_ICON_COLOR_DIM,
			cornerRadius = 2,
		})
		createIconElement(container, {
			position = UDim2.new(0, offset + cellSize/2, 0, offset + cellSize + gap + cellSize/2),
			size = UDim2.new(0, cellSize, 0, cellSize),
			color = SHAPE_ICON_COLOR_DIM,
			cornerRadius = 2,
		})
		createIconElement(container, {
			position = UDim2.new(0, offset + cellSize + gap + cellSize/2, 0, offset + cellSize + gap + cellSize/2),
			size = UDim2.new(0, cellSize, 0, cellSize),
			cornerRadius = 2,
		})

	elseif shapeId == BrushShape.Stick then
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.22, 0, s * 0.9),
			cornerRadius = s * 0.1,
		})

	elseif shapeId == BrushShape.Spinner then
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.6, 0, s * 0.6),
			rotation = 15,
			cornerRadius = 2,
		})
		local arcDots = 3
		for i = 1, arcDots do
			local angle = math.rad(100 + i * 30)
			local radius = s * 0.42
			createIconElement(container, {
				position = UDim2.new(0.5 + math.cos(angle) * radius / s, 0, 0.5 + math.sin(angle) * radius / s, 0),
				size = UDim2.new(0, s * 0.08, 0, s * 0.08),
				color = SHAPE_ICON_COLOR_DIM,
				cornerRadius = s,
			})
		end

	elseif shapeId == BrushShape.Spikepad then
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.72, 0),
			size = UDim2.new(0, s * 0.85, 0, s * 0.35),
			cornerRadius = 2,
		})
		local spikeClip = Instance.new("Frame")
		spikeClip.BackgroundTransparency = 1
		spikeClip.Position = UDim2.new(0, 0, 0, 0)
		spikeClip.Size = UDim2.new(1, 0, 0.6, 0)
		spikeClip.ClipsDescendants = true
		spikeClip.Parent = container

		local spikePositions = {0.25, 0.5, 0.75}
		for _, xPos in ipairs(spikePositions) do
			createIconElement(spikeClip, {
				position = UDim2.new(xPos, 0, 0.85, 0),
				size = UDim2.new(0, s * 0.22, 0, s * 0.22),
				rotation = 45,
				cornerRadius = 1,
			})
		end

	else
		-- Fallback: simple square
		createIconElement(container, {
			position = UDim2.new(0.5, 0, 0.5, 0),
			size = UDim2.new(0, s * 0.7, 0, s * 0.7),
			cornerRadius = 2,
		})
	end

	return container
end

return ShapeIcon
