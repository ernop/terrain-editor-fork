--!strict
-- Theme.lua - Single source of truth for all visual styling
-- All colors, fonts, and sizes used throughout the Terrain Editor UI

local Theme = {}

-- ============================================================================
-- Colors
-- ============================================================================
Theme.Colors = {
	-- Backgrounds
	Background = Color3.fromRGB(35, 35, 35),
	Panel = Color3.fromRGB(45, 45, 45),
	SliderTrack = Color3.fromRGB(40, 40, 40),
	Hashmark = Color3.fromRGB(80, 80, 80),

	-- Buttons
	ButtonDefault = Color3.fromRGB(50, 50, 50),
	ButtonSelected = Color3.fromRGB(0, 120, 200),
	ButtonHover = Color3.fromRGB(70, 70, 70),
	ButtonSecondary = Color3.fromRGB(80, 80, 80),
	ButtonToggleOn = Color3.fromRGB(100, 50, 150),

	-- Text (always white/bright - no gray garbage!)
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(240, 240, 240),  -- Still readable white
	TextDim = Color3.fromRGB(220, 220, 220),    -- Slightly softer white
	TextNote = Color3.fromRGB(200, 210, 220),   -- Hint of blue-white for tips

	-- Accents
	Accent = Color3.fromRGB(0, 162, 255),
	AccentLight = Color3.fromRGB(0, 200, 255),
	Border = Color3.fromRGB(0, 180, 255),
	SliderFill = Color3.fromRGB(0, 162, 255),
	SliderThumb = Color3.fromRGB(255, 255, 255),
	SliderThumbStroke = Color3.fromRGB(0, 120, 200),

	-- Status
	Success = Color3.fromRGB(0, 255, 100),
	Warning = Color3.fromRGB(255, 200, 0),
	Error = Color3.fromRGB(255, 80, 80),
	Ready = Color3.fromRGB(0, 200, 255),

	-- Brush visualization
	BrushNormal = Color3.fromRGB(0, 162, 255),
	BrushLocked = Color3.fromRGB(255, 170, 0),
	BrushEdge = Color3.fromRGB(0, 100, 160),           -- Darker edge lines for depth
	BrushEdgeLocked = Color3.fromRGB(180, 100, 0),     -- Darker orange for locked edges
	PlaneViz = Color3.fromRGB(0, 200, 100),
	HandleRotation = Color3.fromRGB(255, 170, 0),
	HandleSize = Color3.fromRGB(0, 200, 255),

	-- Bridge preview
	BridgeStart = Color3.fromRGB(0, 255, 0),
	BridgeEnd = Color3.fromRGB(255, 100, 0),
	BridgePath = Color3.fromRGB(100, 200, 255),
}

-- ============================================================================
-- Fonts
-- ============================================================================
Theme.Fonts = {
	Default = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
}

-- ============================================================================
-- Sizes
-- ============================================================================
Theme.Sizes = {
	-- Text sizes (larger for better readability)
	TextSmall = 11,
	TextDescription = 12,
	TextNormal = 13,
	TextMedium = 14,
	TextLarge = 16,

	-- Button dimensions
	ButtonHeight = 26,
	ButtonWidth = 70,
	ButtonWidthWide = 80,
	ActionButtonWidth = 120,     -- Natural width for action buttons
	ToolButtonWidth = 70,
	ToolButtonHeight = 32,

	-- Slider dimensions
	SliderHeight = 50,           -- Reduced from 70, more compact
	SliderTrackHeight = 14,      -- Reduced from 18
	SliderTrackWidth = 200,      -- Not full width!
	SliderThumbSize = 18,        -- Slightly smaller
	SliderThumbStroke = 2,

	-- Material tile dimensions
	MaterialTileSize = 72,
	MaterialTileLabelHeight = 18,
	MaterialGridCellHeight = 94,

	-- Layout
	CornerRadius = 4,
	CornerRadiusLarge = 6,
	CornerRadiusRound = 9,
	PaddingSmall = 6,
	PaddingMedium = 8,
	PaddingLarge = 10,

	-- Panel layout
	PanelPadding = 8,
	ConfigStartY = 420,  -- Adjusted for analysis tools section
}

-- ============================================================================
-- Transparency values
-- ============================================================================
Theme.Transparency = {
	BrushNormal = 0.7,
	BrushExtra = 0.6,
	PlaneViz = 0.85,
	PreviewMarker = 0.5,
	PathMarker = 0.7,
}

return Theme

