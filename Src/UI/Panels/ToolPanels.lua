--!strict
-- ToolPanels.lua - Tool-specific settings panels
-- Panels: Path (depth, profile, direction), Clone, Blob (intensity, smoothness),
--         SlopePaint, Megarandomize, CavityFill, Melt

local Theme = require(script.Parent.Parent.Parent.Util.Theme)
local UIHelpers = require(script.Parent.Parent.Parent.Util.UIHelpers)
local UIComponents = require(script.Parent.Parent.Parent.Util.UIComponents)
local BrushData = require(script.Parent.Parent.Parent.Util.BrushData)

local ToolPanels = {}

export type ToolPanelsDeps = {
	configContainer: Frame,
	S: any, -- State table
}

export type ToolPanelsResult = {
	panels: { [string]: Frame },
}

function ToolPanels.create(deps: ToolPanelsDeps): ToolPanelsResult
	local panels: { [string]: Frame } = {}
	local S = deps.S

	-- ========================================================================
	-- Path Tool Panels
	-- ========================================================================

	-- Path Depth Panel
	local pathDepthPanel = UIHelpers.createConfigPanel(deps.configContainer, "pathDepth")

	local pathDepthHeader = UIHelpers.createHeader(pathDepthPanel, "Path Depth", UDim2.new(0, 0, 0, 0))
	pathDepthHeader.LayoutOrder = 1

	local pathDepthDesc = UIHelpers.createDescription(pathDepthPanel, "How deep the channel is in studs", 16)
	pathDepthDesc.LayoutOrder = 2

	local _, pathDepthContainer, _ = UIHelpers.createSlider(pathDepthPanel, "Depth", 2, 20, S.pathDepth, function(value)
		S.pathDepth = value
	end)
	pathDepthContainer.LayoutOrder = 3

	panels["pathDepth"] = pathDepthPanel

	-- Path Profile Panel
	local pathProfilePanel = UIHelpers.createConfigPanel(deps.configContainer, "pathProfile")

	local pathProfileHeader = UIHelpers.createHeader(pathProfilePanel, "Path Profile", UDim2.new(0, 0, 0, 0))
	pathProfileHeader.LayoutOrder = 1

	local pathProfileGroup = UIComponents.createButtonGroup({
		parent = pathProfilePanel,
		options = {
			{ id = "V", name = "V" },
			{ id = "U", name = "U" },
			{ id = "Flat", name = "Flat" },
		},
		initialValue = S.pathProfile,
		onChange = function(newProfile)
			S.pathProfile = newProfile
		end,
		layout = "horizontal",
	})
	pathProfileGroup.container.LayoutOrder = 2

	panels["pathProfile"] = pathProfilePanel

	-- Path Direction Info Panel
	local pathDirectionInfoPanel = UIHelpers.createConfigPanel(deps.configContainer, "pathDirectionInfo")

	local pathDirHeader = UIHelpers.createHeader(pathDirectionInfoPanel, "Path Direction", UDim2.new(0, 0, 0, 0))
	pathDirHeader.LayoutOrder = 1

	local pathDirDesc = UIHelpers.createDescription(pathDirectionInfoPanel, "Drag mouse to set channel direction", 32)
	pathDirDesc.LayoutOrder = 2

	panels["pathDirectionInfo"] = pathDirectionInfoPanel

	-- ========================================================================
	-- Clone Tool Panel
	-- ========================================================================
	local cloneInfoPanel = UIHelpers.createConfigPanel(deps.configContainer, "cloneInfo")

	local cloneHeader = UIHelpers.createHeader(cloneInfoPanel, "Clone Tool", UDim2.new(0, 0, 0, 0))
	cloneHeader.LayoutOrder = 1

	local cloneInstructions = UIHelpers.createInstructions(cloneInfoPanel, "Alt+Click to sample source, then click to stamp", 48)
	cloneInstructions.LayoutOrder = 2

	local cloneStatusLabel = UIHelpers.createStatusLabel(cloneInfoPanel, "Status: No source sampled", Theme.Colors.TextMuted)
	cloneStatusLabel.LayoutOrder = 3

	panels["cloneInfo"] = cloneInfoPanel

	-- ========================================================================
	-- Blobify Tool Panels
	-- ========================================================================

	-- Blob Intensity Panel
	local blobIntensityPanel = UIHelpers.createConfigPanel(deps.configContainer, "blobIntensity")

	local blobIntHeader = UIHelpers.createHeader(blobIntensityPanel, "Blob Intensity", UDim2.new(0, 0, 0, 0))
	blobIntHeader.LayoutOrder = 1

	local blobIntDesc = UIHelpers.createDescription(blobIntensityPanel, "How much the blob protrudes", 16)
	blobIntDesc.LayoutOrder = 2

	local _, blobIntContainer, _ = UIHelpers.createSlider(blobIntensityPanel, "Intensity", 10, 100, math.floor(S.blobIntensity * 100), function(value)
		S.blobIntensity = value / 100
	end)
	blobIntContainer.LayoutOrder = 3

	panels["blobIntensity"] = blobIntensityPanel

	-- Blob Smoothness Panel
	local blobSmoothnessPanel = UIHelpers.createConfigPanel(deps.configContainer, "blobSmoothness")

	local blobSmoothHeader = UIHelpers.createHeader(blobSmoothnessPanel, "Blob Smoothness", UDim2.new(0, 0, 0, 0))
	blobSmoothHeader.LayoutOrder = 1

	local blobSmoothDesc = UIHelpers.createDescription(blobSmoothnessPanel, "How smooth/organic the blob shape is", 16)
	blobSmoothDesc.LayoutOrder = 2

	local _, blobSmoothContainer, _ = UIHelpers.createSlider(blobSmoothnessPanel, "Smoothness", 10, 100, math.floor(S.blobSmoothness * 100), function(value)
		S.blobSmoothness = value / 100
	end)
	blobSmoothContainer.LayoutOrder = 3

	panels["blobSmoothness"] = blobSmoothnessPanel

	-- ========================================================================
	-- Slope Paint Panel
	-- ========================================================================
	local slopeMaterialsPanel = UIHelpers.createConfigPanel(deps.configContainer, "slopeMaterials")

	local slopeHeader = UIHelpers.createHeader(slopeMaterialsPanel, "Slope Paint", UDim2.new(0, 0, 0, 0))
	slopeHeader.LayoutOrder = 1

	local slopeDesc = UIHelpers.createDescription(slopeMaterialsPanel, "Auto-paints based on slope. Click buttons to change materials.", 32)
	slopeDesc.LayoutOrder = 2

	-- Flat row
	local slopeFlatRow = UIHelpers.createLabeledRow(slopeMaterialsPanel, "Flat (0-30°):", 80)
	slopeFlatRow.row.LayoutOrder = 3

	local slopeFlatBtn = UIComponents.createMaterialCycleButton({
		parent = slopeFlatRow.row,
		initialMaterial = S.slopeFlatMaterial,
		onChange = function(newMat)
			S.slopeFlatMaterial = newMat
		end,
		position = UDim2.new(0, 85, 0, 0),
	})

	-- Steep row
	local slopeSteepRow = UIHelpers.createLabeledRow(slopeMaterialsPanel, "Steep:", 80)
	slopeSteepRow.row.LayoutOrder = 4

	local slopeSteepBtn = UIComponents.createMaterialCycleButton({
		parent = slopeSteepRow.row,
		initialMaterial = S.slopeSteepMaterial,
		onChange = function(newMat)
			S.slopeSteepMaterial = newMat
		end,
		position = UDim2.new(0, 85, 0, 0),
	})

	-- Cliff row
	local slopeCliffRow = UIHelpers.createLabeledRow(slopeMaterialsPanel, "Cliff (60°+):", 80)
	slopeCliffRow.row.LayoutOrder = 5

	local slopeCliffBtn = UIComponents.createMaterialCycleButton({
		parent = slopeCliffRow.row,
		initialMaterial = S.slopeCliffMaterial,
		onChange = function(newMat)
			S.slopeCliffMaterial = newMat
		end,
		position = UDim2.new(0, 85, 0, 0),
	})

	panels["slopeMaterials"] = slopeMaterialsPanel

	-- ========================================================================
	-- Megarandomize Panel
	-- ========================================================================
	local megarandomizePanel = UIHelpers.createConfigPanel(deps.configContainer, "megarandomizeSettings")

	local megarandHeader = UIHelpers.createHeader(megarandomizePanel, "Megarandomize", UDim2.new(0, 0, 0, 0))
	megarandHeader.LayoutOrder = 1

	local megarandDesc = UIHelpers.createDescription(megarandomizePanel, "Random materials in clusters. Click to cycle.")
	megarandDesc.LayoutOrder = 2

	local megarand1Btn = UIComponents.createMaterialCycleButton({
		parent = megarandomizePanel,
		initialMaterial = S.megarandomizeMaterials[1].material,
		onChange = function(newMat)
			S.megarandomizeMaterials[1].material = newMat
		end,
		size = UDim2.new(0.5, -4, 0, 22),
		suffix = " 60%",
	})
	megarand1Btn.button.LayoutOrder = 3

	local megarand2Btn = UIComponents.createMaterialCycleButton({
		parent = megarandomizePanel,
		initialMaterial = S.megarandomizeMaterials[2].material,
		onChange = function(newMat)
			S.megarandomizeMaterials[2].material = newMat
		end,
		size = UDim2.new(0.5, -4, 0, 22),
		suffix = " 25%",
	})
	megarand2Btn.button.LayoutOrder = 4

	local megarand3Btn = UIComponents.createMaterialCycleButton({
		parent = megarandomizePanel,
		initialMaterial = S.megarandomizeMaterials[3].material,
		onChange = function(newMat)
			S.megarandomizeMaterials[3].material = newMat
		end,
		size = UDim2.new(0.5, -4, 0, 22),
		suffix = " 15%",
	})
	megarand3Btn.button.LayoutOrder = 5

	local _, megarandClusterContainer, _ = UIHelpers.createSlider(megarandomizePanel, "Cluster", 1, 20, S.megarandomizeClusterSize, function(v)
		S.megarandomizeClusterSize = v
	end)
	megarandClusterContainer.LayoutOrder = 6

	panels["megarandomizeSettings"] = megarandomizePanel

	-- ========================================================================
	-- Cavity Fill Panel
	-- ========================================================================
	local cavitySensitivityPanel = UIHelpers.createConfigPanel(deps.configContainer, "cavitySensitivity")

	local cavityHeader = UIHelpers.createHeader(cavitySensitivityPanel, "Cavity Fill", UDim2.new(0, 0, 0, 0))
	cavityHeader.LayoutOrder = 1

	local cavityDesc = UIHelpers.createDescription(cavitySensitivityPanel, "Fills holes and depressions. Lower = more sensitive.")
	cavityDesc.LayoutOrder = 2

	local _, cavitySensContainer, _ = UIHelpers.createSlider(cavitySensitivityPanel, "Sensitivity", 5, 80, math.floor(S.cavitySensitivity * 100), function(v)
		S.cavitySensitivity = v / 100
	end)
	cavitySensContainer.LayoutOrder = 3

	panels["cavitySensitivity"] = cavitySensitivityPanel

	-- ========================================================================
	-- Melt Panel
	-- ========================================================================
	local meltViscosityPanel = UIHelpers.createConfigPanel(deps.configContainer, "meltViscosity")

	local meltHeader = UIHelpers.createHeader(meltViscosityPanel, "Melt Tool", UDim2.new(0, 0, 0, 0))
	meltHeader.LayoutOrder = 1

	local meltDesc = UIHelpers.createDescription(meltViscosityPanel, "Terrain flows down. Lower viscosity = runnier.")
	meltDesc.LayoutOrder = 2

	local _, meltViscContainer, _ = UIHelpers.createSlider(meltViscosityPanel, "Viscosity", 0, 100, math.floor(S.meltViscosity * 100), function(v)
		S.meltViscosity = v / 100
	end)
	meltViscContainer.LayoutOrder = 3

	panels["meltViscosity"] = meltViscosityPanel

	return {
		panels = panels,
	}
end

return ToolPanels

